---
date: '2026-10-29T15:00:14+08:00'
draft: false
title: 'Migrate Docker Compose to Podman Quadlets (Kube)'
---

## Preface

Docker is a convenient tool for rapid development and deployment. Before its creation, developers often needed to set up massive development environments locally or in VMs for cross-platform development. Now, they can pull pre-built images from upstream vendors and immediately start building projects, which is especially useful for deep learning and web development. Maintaining production environments is also a headache without Docker. For small-scale application services, simply including a `Dockerfile` and `docker-compose.yaml` in a repository enables rapid development by pipelining image building, service lifecycle, storage, and network management.

However, I am concerned about the security of default rootful Docker. The most critical issue is that any user with access to its daemon gets full system access. Docker also supports [rootless mode](https://docs.docker.com/engine/security/rootless/). Some pre-built images even run the application as root by default, which maps to the `root` user on the host system when user namespace remapping is disabled. Given that our lovely system libraries and popular services may contain more security vulnerabilities waiting to be discovered, I feel it is critical to run Internet-facing services in an unprivileged sandbox environment to minimize the attack surface.

After researching different alternatives using LLM, I found [Podman Quadlets](https://www.redhat.com/en/blog/quadlet-podman) to be a good approach for production deployments, especially since its `.kube` units run supported Kubernetes YAML through [podman kube play](https://docs.podman.io/en/latest/markdown/podman-kube-play.1.html).

This post summarizes the key steps to migrate `docker-compose.yml` file into Podman Quadlet Kube for my own reference.

## Default behavior changes

### Network Namespace
*   **Docker Compose:** Each container gets a unique IP on a bridge network and resolves other containers via internal DNS.
*   **Podman `.kube`:** All containers within a **Pod** share the exact same network namespace. A single `.kube` file can deploy multiple Pods.
    *   **Zero Network Isolation:** Every container in the Pod binds to the same loopback interface `lo`, therefore, no network policies can block traffic inside a shared network namespace.
    *   **Port Conflicts:** You cannot have two containers in the same Pod listening on the same internal port.

### User Namespace
*   **Docker Compose:** Rootful Docker uses 1:1 UID mapping by default, unless user namespace remapping is configured. The container process runs as the same UID on both the host and container.
    *   **Root Risk:** If neither Compose nor the image's `USER` specifies a user, the container runs as UID 0 (root) and can access mounted files with that identity, subject to mount permissions and security controls.
    *   **Default Behavior:** The user namespace is shared with the host. IPC is configured separately: `ipc: shareable` gives a container its own IPC namespace that another container can join using `ipc: service:<name>`, while `ipc: host` uses the host's IPC namespace. See the [Compose reference](https://docs.docker.com/reference/compose-file/services/#ipc).
*   **Podman `.kube`:** A Rootless Podman instance shares a single `subuid` allocation by default. Podman's [--userns=auto](https://docs.podman.io/en/latest/markdown/podman-pod-create.1.html#userns-mode) feature can allocate separate UID mappings per Pod, but containers within the same Pod use the Pod's mapping.
    *   **Multiple Users In A Container:** The kernel maps container process UID/GID to host UID/GID using mappings configured with [newuidmap](https://man7.org/linux/man-pages/man1/newuidmap.1.html)/[newgidmap](https://man7.org/linux/man-pages/man1/newgidmap.1.html) on container init.
    *   **User Namespace:** User, network (`lo`), and IPC namespaces ([shm](https://man7.org/linux/man-pages/man7/shm_overview.7.html) and [sysvipc](https://man7.org/linux/man-pages/man7/sysvipc.7.html)) are configured separately. Sharing a user namespace does not itself share the network or IPC namespace.
    *   **Default Behavior:** Rootless container UID 0 maps to the calling host user. Containers *within the same Pod* share the Pod's user, network, and IPC namespaces by default.

### Dependency Management
*   **Docker Compose:** Uses `depends_on` to control startup order.
*   **Podman `.kube`:** Kubernetes natively starts all containers in a Pod concurrently. To run one-time pre-flight task *within* a Pod, use `initContainers`. To enforce order *between* different Pods, you must use systemd directives (`After=`, `Requires=`) in the `.kube` wrapper.

### Variable Interpolation
*   **Compose:** Natively expands environment variables in the YAML (e.g., `user: "${UID}"` or `volumes: ["./data:/data"]`).
*   **Podman `.kube`:** Kubernetes YAML does **not** provide Compose-style shell variable interpolation. Specify explicit UIDs and GIDs, and use absolute host paths to avoid depending on the service's working directory.

## Host access from containers

When running on native Linux system, both Docker and Podman *do not* provide a blanket block on host access by default. Containers may access host services bound to `0.0.0.0`, subject to routing and firewall rules.

> You may find the effect of "host isolation" when using Docker Desktop on Mac/Windows, where the lightweight Linux VM physically separates the container network from your host.

For rootful Docker/Podman, the bridge interfaces (e.g. `docker0` or `podman`) for the containers exist on the host kernel. Therefore, you may use FirewallD rules to block the bridge subnet from accessing host addresses, including both the host IPs and the local LAN.

### Workaround: Add firewall rules (rootful)

*This example targets the specified IPv4 subnet for rootful containers. It does not cover every host address or all forwarded LAN traffic. Verify the rules against your container network and firewall setup.*

```bash
sudo firewall-cmd --permanent --new-zone=podman-isolated;
# Podman bridge subnet 
sudo firewall-cmd --permanent --zone=podman-isolated --add-source=172.20.0.0/24;

# Drop traffic targeting the host's physical LAN subnet
sudo firewall-cmd --permanent --zone=podman-isolated --add-rich-rule='rule family="ipv4" destination address="192.168.1.0/24" drop';
sudo firewall-cmd --reload;
```

However, filtering rootless containers by their original source IP is more difficult. Podman uses `pasta` which copies addresses and routes from the selected host interface, or `slirp4netns` which performs NAT, to route traffic to/from the host.
With [pasta](https://passt.top/passt/about/), outgoing traffic uses host sockets, so host firewall rules cannot rely on the original container source IP to distinguish it from other host traffic.

### Workaround: Disable the host-address mapping (rootless)

*This works when using `pasta` for userspace networking in rootless Podman container. It disables the [guest-to-host address mapping](https://passt.top/builds/latest/web/passt.1.html#map-guest-addr) feature only, which Podman normally uses for `host.containers.internal`. This cannot block host access from container.*

```bash
podman run --net=pasta:--map-guest-addr=none ...
```

*Quadlet Wrapper (`*.kube`):*

```ini
[Kube]
# Disable the guest-to-host address mapping via pasta
Network=pasta:--map-guest-addr=none
```

## Equivalent Configurations

### Set User/Group Identity
Specify user/group identity for the container process.

**Docker Compose:**
```yaml
services:
  app:
    user: "1000:1000"
    group_add:
      - "2000"
      - "3000"
```

**Kubernetes YAML (`.yaml`):**
```yaml
spec:
  securityContext:
    supplementalGroups: [2000, 3000]
  containers:
    - name: app
      securityContext:
        runAsUser: 1000
        runAsGroup: 1000
```

### Build image from Dockerfile
Build image from Dockerfile using a `.build` unit, and run it using a `.kube` unit. While [podman kube play](https://docs.podman.io/en/latest/markdown/podman-kube-play.1.html#description) also supports automatic builds with a specific directory layout, a separate `.build` unit gives explicit control over building the image. Restart the build service when build inputs change.  

However, restarting the app service alone does not rebuild it.

**Docker Compose:**
```yaml
services:
  app:
    build:
      context: ./
      args:
        BUILD_VERSION: v1.2.4
```

**Quadlets build (`.build`):**
```toml
[Unit]
Description=Build app

[Build]
ImageTag=localhost/app:latest
File=/path/to/build/file

# Plain text variables directly to the build file
BuildArg=BUILD_VERSION=v1.2.4
Secret=id=secret-token,src=/path/to/secret/file
```

> `BuildArg=` in `[Build]` is supported from [Podman v5.7](https://docs.podman.io/en/v5.7.0/markdown/podman-systemd.unit.5.html#buildarg). Before v5.7, use `PodmanArgs=--build-arg=BUILD_VERSION=v1.2.4` in `[Build]` instead.

**Build file (`ContainerFile`)**

When used with Quadlets, use `ARG` to capture `BuildArg=` during the build. Assign it to `ENV` only if it is also needed at runtime. The [build secret](https://docs.podman.io/en/latest/markdown/podman-build.unit.5.html#secret-id-id-src-envorfile-env-env-type-file-env) is supplied separately and mounted by the `RUN` instruction.

Note that `ENV` will make the variable available in the final image via `podman inspect`.


```dockerfile
FROM docker.io/library/node:20-alpine
WORKDIR /app

# Capture Quadlet BuildArg= variable
ARG BUILD_VERSION=default_version_string

# Persist the environment variable to the final image
ENV BUILD_VERSION=$BUILD_VERSION

# Mount the secret file to /run/secrets/<id>
RUN --mount=type=secret,id=secret-token \
    # Dump the secret file content as a build time variable only
    export APP_TOKEN=$(cat /run/secrets/secret-token) && \
    npm run build
```

### Commands and Entrypoints
Docker overrides the default execution command using `command` and `entrypoint`. Kubernetes uses `args` and `command`.

**Docker Compose:**
```yaml
services:
  app:
    image: myapp:latest
    entrypoint: ["/bin/custom-init"]
    command: ["--debug", "--port=80"]
```

**Kubernetes YAML (`.yaml`):**
```yaml
containers:
  - name: app
    image: myapp:latest
    command: ["/bin/custom-init"] # Overrides Entrypoint
    args: ["--debug", "--port=80"] # Overrides Command
```

### Bind Mounts (Host Paths)
Mapping a specific directory from the host to the container.

**Docker Compose:**
```yaml
volumes:
  - /opt/app-data:/var/lib/data
```

**Kubernetes YAML (`.yaml`):**
*Note: Use absolute host paths to avoid depending on the service's working directory.*
```yaml
containers:
  - name: app
    volumeMounts:
      - name: data-mount
        mountPath: /var/lib/data
volumes:
  - name: data-mount
    hostPath:
      path: /opt/app-data
      type: DirectoryOrCreate # Options: Directory, File, DirectoryOrCreate
```

### Named Volumes
Persistent volumes managed by the container runtime.

**Docker Compose:**
```yaml
services:
  db:
    volumes:
      - db-data:/var/lib/postgresql/data
volumes:
  db-data:
```

**Kubernetes YAML (`.yaml`):**
Podman intercepts the `persistentVolumeClaim` directive and automatically translates it into a local Podman named volume.
```yaml
containers:
  - name: db
    volumeMounts:
      - name: db-data
        mountPath: /var/lib/postgresql/data
volumes:
  - name: db-data
    persistentVolumeClaim:
      claimName: db-data
```

### Environment Variable Injection
Injecting variables directly or via external files. 

Quadlet's `ConfigMap=` requires valid Kubernetes ConfigMap YAML files. Put runtime values directly in `config.yaml` and inject them as ordinary environment variables.

**Docker Compose:**
```yaml
environment:
  - LOG_LEVEL=debug
env_file:
  - .env
```

**Kubernetes YAML (`.yaml`) + Quadlet (`.kube`):**
To supply the equivalent settings, write a ConfigMap and reference its metadata name.

**ConfigMap (`config.yaml`):**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  NODE_ENV: "production"
```

**Quadlet Wrapper (`*.kube`):**
```ini
[Kube]
Yaml=/opt/app/app.yaml
ConfigMap=/opt/app/config.yaml
```

**Kubernetes YAML (`.yaml`):**
```yaml
containers:
  - name: app
    # Explicit variables
    env:
      - name: LOG_LEVEL
        value: "debug"
    # Inject all entries from the supplied ConfigMap
    envFrom:
      - configMapRef:
          name: app-config
```

**Image build variables (`.build`):**
For build unit, there are two approach to set environment variable ⎯ `Environment` and `BuildArg` in [[Build]](https://docs.podman.io/en/v5.7.0/markdown/podman-systemd.unit.5.html#build-units-build) section.  

- `Environment` add a value to the built image which will available in container runtime environment.  
- `BuildArg` forward a build argument to the matching `ARG` statement in `ContainerFile`.

However, build unit does not support `EnvironmentFile=`. Instead, use systemd's [EnvironmentFile](https://www.freedesktop.org/software/systemd/man/latest/systemd.exec.html#EnvironmentFile=) option in the `[Service]` section to load environment variables into the Podman process. Then, explicitly forward each variable using `Environment=` or `BuildArg=` options.

> Note that `Service.EnvironmentFile` alone does not make it available to build environment.

**Environment file (`/opt/app/.env.build`):**
```text
BUILD_VERSION=v1.2.4
```

**Quadlet build (`.build`):**
```ini
[Build]
ImageTag=localhost/app:latest
File=/opt/app/ContainerFile.app
SetWorkingDirectory=/opt/app
# Store the variable into built image
Environment=NODE_ENV=production
# Forward the variable to `ARG BUILD_VERSION` statement
BuildArg=BUILD_VERSION=${BUILD_VERSION}

[Service]
EnvironmentFile=/opt/app/.env.build
```

Restart the build service after editing the environment file.

### Networks

#### Simple custom network
Attaching the stack to an shared network.

**Docker Compose:**
```yaml
networks:
  default:
    name: proxy-net
    external: true
```

**Network Quadlet: `~/.config/containers/systemd/proxy-net.network`:**
```ini
[Network]
NetworkName=proxy-net
```

**Quadlet Wrapper (`.kube`):**
Networking configuration is handled by the systemd wrapper. [Network=proxy-net.network](https://docs.podman.io/en/latest/markdown/podman-kube.unit.5.html#network-mode) automatically adds the dependency on `proxy-net-network.service`.

```ini
[Unit]
After=network-online.target

[Kube]
Yaml=/opt/app/app.yaml
Network=proxy-net.network
```

#### Network with static IP assignment
Attaching the stack to an shared network with static IP.

**Docker Compose:**
```yaml
services:
  proxy:
    networks:
      default:
        ipv4_address: 172.20.0.254

networks:
  default:
    name: proxy-net
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/24
```

**Network Quadlet: `~/.config/containers/systemd/proxy-net.network`:**
```ini
[Network]
NetworkName=proxy-net
Subnet=172.20.0.0/24
```

**Quadlet Wrapper (`.kube`):**
Networking configuration is handled by the systemd wrapper.

```ini
[Unit]
After=network-online.target

[Kube]
Yaml=/opt/app/app.yaml
Network=proxy-net.network
PodmanArgs=--ip=172.20.0.254
```

The [--ip](https://docs.podman.io/en/latest/markdown/podman-kube-play.1.html#ip-ip-address) option assigns an address within the defined subnet to the Pod itself, and all containers inside it share that IP.

### Health Checks
Monitoring container state.

**Docker Compose:**
```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost"]
  interval: 30s
  retries: 3
```

**Kubernetes YAML (`.yaml`):**
Kubernetes splits health checks into Liveness (is it running?) and Readiness (can it accept traffic?). Podman kube play supports `livenessProbe`, but does not support `readinessProbe` or `startupProbe`.
```yaml
containers:
  - name: app
    livenessProbe:
      exec:
        command: ["curl", "-f", "http://localhost"]
      periodSeconds: 30
      failureThreshold: 3
      initialDelaySeconds: 10
```

---

## Example Case

A Node.js app and PostgreSQL database run in **separate Pods on the same network**. The app connects to the database service thought `app-db:5432`. Port `3000` from `app` is published to port `8080`.

### Build file: `/opt/app/ContainerFile.app`

```dockerfile
FROM docker.io/library/node:24-alpine
WORKDIR /app

ARG BUILD_VERSION=v1.0
ENV BUILD_VERSION=${BUILD_VERSION}

RUN npm install --global pnpm;
COPY . .

# The project's build consumes APP_TOKEN only during this RUN instruction.
RUN --mount=type=secret,id=secret-token \
    set -eu; \
    export APP_TOKEN="$(cat /run/secrets/secret-token)"; \
    pnpm install --frozen-lockfile; \
    pnpm run build; \
    pnpm prune --prod;

ENV NODE_ENV=production
USER node
EXPOSE 3000
CMD ["pnpm", "start"]
```

Assumes `/opt/app/.env.build-token` contains the raw build token.

### Build exclusions: `/opt/app/.containerignore`

```text
.git
.env*
config.yaml
*-secret.yaml
node_modules
```

### Build Quadlet: `~/.config/containers/systemd/app.build`

```ini
[Unit]
Description=Build Node.js app

[Build]
ImageTag=localhost/app:v1.0
File=/opt/app/ContainerFile.app
SetWorkingDirectory=/opt/app
BuildArg=BUILD_VERSION=v1.0
Secret=id=secret-token,src=/opt/app/.env.build-token

[Service]
TimeoutStartSec=900
```

### Network Quadlet: `~/.config/containers/systemd/app.network`

```ini
[Network]
NetworkName=app-net
```

### Runtime configuration: `/opt/app/config.yaml`

Both Quadlets load this file with `ConfigMap=`. If edited this file, the affected services need to be restarted.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  PORT: "3000"
  PGHOST: "app-db"
  PGDATABASE: "app"
  PGUSER: "app"
  POSTGRES_USER: "app"
  POSTGRES_DB: "app"
  DB_PASSWORD: "replace-with-database-password"
  API_KEY: "replace-with-runtime-api-key"
```

### Kubernetes Manifest: `/opt/app/app.yaml`

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-app
spec:
  # Verify an authenticated connection before starting the backend.
  initContainers:
    - name: wait-for-db
      image: docker.io/library/postgres:15
      command: ["sh", "-ec"]
      args:
        - |
          for attempt in $(seq 1 60); do
            if psql -w -c 'SELECT 1' >/dev/null 2>&1; then
              exit 0;
            fi;
            sleep 2;
          done;
          echo "Database did not become ready" >&2;
          exit 1;
      env:
        - name: PGPASSWORD
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: DB_PASSWORD
      envFrom:
        - configMapRef:
            name: app-config

  containers:
    - name: backend
      image: localhost/app:v1.0
      imagePullPolicy: Never
      ports:
        - containerPort: 3000
          hostPort: 8080
      envFrom:
        - configMapRef:
            name: app-config
```

### Quadlet: `~/.config/containers/systemd/app-app.kube`

```ini
[Unit]
Description=Backend App Pod
Requires=app-build.service app-db.service
After=network-online.target app-build.service app-db.service

[Kube]
Yaml=/opt/app/app.yaml
ConfigMap=/opt/app/config.yaml
Network=app.network

[Service]
TimeoutStartSec=900

[Install]
WantedBy=default.target
```

Note that a `.kube` manifest does not automatically depend on that build unit, so this manifest explicitly requires `app-build.service` using `Requires=`, while `After=` specifies the orders for service startup. 

### Kubernetes Manifest: `/opt/app/db.yaml`

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-db
spec:
  containers:
    - name: database
      image: docker.io/library/postgres:15
      # Map the shared password to the image's initialization variable.
      env:
        - name: POSTGRES_PASSWORD
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: DB_PASSWORD
      envFrom:
        - configMapRef:
            name: app-config
      volumeMounts:
        - name: pg-data
          mountPath: /var/lib/postgresql/data
      livenessProbe:
        exec:
          command: ["pg_isready", "-h", "127.0.0.1", "-U", "app", "-d", "app"]
        periodSeconds: 10
        initialDelaySeconds: 30
        failureThreshold: 6

  volumes:
    - name: pg-data
      persistentVolumeClaim:
        claimName: postgresql-data
```

### Quadlet: `~/.config/containers/systemd/app-db.kube`

```ini
[Unit]
Description=PostgreSQL Database Pod
After=network-online.target

[Kube]
Yaml=/opt/app/db.yaml
ConfigMap=/opt/app/config.yaml
Network=app.network

[Service]
TimeoutStartSec=900

[Install]
WantedBy=default.target
```

### Start and verify

After saving the files:

```bash
systemctl --user daemon-reload;
systemctl --user start app-app.service;
systemctl --user status app-build.service app-db.service app-app.service;
journalctl --user -u app-app.service -u app-db.service -n 100 --no-pager;
curl --fail http://127.0.0.1:8080/;
```

Verify if database service starts successfully:

```bash
podman run --rm -it --pod app-app docker.io/library/postgres:15 \
  psql -W -h app-db -U app -d app -c 'SELECT 1';
```

Enable [linger](https://wiki.archlinux.org/title/Systemd/User#Automatic_start-up_of_systemd_user_instances) to start user services at startup automatically. Note that you cannot "enable" the systemd service generated by Podman because they are [transient by systemd](https://docs.podman.io/en/stable/markdown/podman-systemd.unit.5.html#enabling-unit-files).  

After changing app source or build inputs, rebuild and restart explicitly:

```bash
systemctl --user restart app-build.service;
systemctl --user restart app-app.service;
```

Stop both Pods with 

```bash
systemctl --user stop app-app.service app-db.service
```
