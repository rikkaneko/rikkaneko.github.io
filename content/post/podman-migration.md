---
date: '2026-10-29T15:00:14+08:00'
draft: false
title: 'Migrate Docker Compose to Podman Quadlets'
---

## Preface

Docker is a convenient tool for rapid development and deployment. Before its creation, developers often needed to set up massive development environments locally or in VMs for cross-platform development. Now, they can pull pre-built images from upstream vendors and immediately start building projects, which is especially useful for deep learning and web development. Maintaining production environments is also a headache without Docker. For small-scale application services, simply including a `Dockerfile` and `docker-compose.yaml` in a repository enables rapid development by pipelining image building, service lifecycle, storage, and network management.

However, I am concerned about the security of Docker. The most critical issue is that the Docker daemon is rootful, meaning that any user with access to Docker gets full system access. Also, some pre-built images even run the application as root by default, which maps to the `root` user on the host system. Given that our lovely system libraries and popular services may contain more security vulnerabilities waiting to be discovered, I feel it is critical to run Internet-facing services in an unprivileged sandbox environment to minimize the attack surface.

After researching different alternatives using LLM, I found [Podman Quadlets](https://www.redhat.com/en/blog/quadlet-podman) to be a good approach for production deployments, especially since its configuration syntax is compatible with the Kubernetes [kubelet](https://kubernetes.io/docs/concepts/overview/components/#kubelet).  

This post summarizes the key steps to migrate `docker-compose.yml` file into Podman Quadlet Kube for my own reference.

## Default behavior changes

### Network Namespace
*   **Docker Compose:** Each container gets a unique IP on a bridge network and resolves other containers via internal DNS.
*   **Podman `.kube`:** All containers defined in a single `.kube` file are scheduled into a **Pod**. They share the exact same network namespace.
    *   **Zero Network Isolation:** Every container in the Pod binds to the same loopback interface `lo`, therefore, no network policies can block traffic inside a shared network namespace.
    *   **Port Conflicts:** You cannot have two containers in the same Pod listening on the same internal port.

### User Namespace
*   **Docker Compose:** Rootful Docker uses 1:1 pass-through for user namespace. The container process runs as the same UID on both the host and container.
    *   **Root Risk:** If a container in Docker Compose does not specify a user, it runs as UID 0 (root) and be able to access file in mounted filesystem as root.
    *   **Default Behavior:** User namespace is strictly isolated per container. You must explicitly opt-in to sharing IPC namespace using `ipc: shareable` or `ipc: host`.
*   **Podman `.kube`:** A Rootless Podman instance shares a single `subuid` allocation by default. While Podman does have a `--userns=auto` feature that can generate unique, separate UID mappings per container to isolate them from each other, but this feature cannot be used when containers share a Pod.
    *   **Multiple Users In A Container:** The kernel will map container process UID/GID to the specific UID/GID in the host set by [setuidmap](https://man7.org/linux/man-pages/man1/newuidmap.1.html)/[setgidmap](https://man7.org/linux/man-pages/man1/newgidmap.1.html) on container init.
    *   **User Namespace:** The kernel will isolate the network namespace (`lo`) and IPC namespace ([shm](https://man7.org/linux/man-pages/man7/shm_overview.7.html) and [sysvipc](https://man7.org/linux/man-pages/man7/sysvipc.7.html)) between user namespaces.
    *   **Default Behavior:** Same behavior as Docker, except for implicitly sharing the same user namespace among all containers *within the same Pod*.

### Dependency Management
*   **Docker Compose:** Uses `depends_on` to control startup order.
*   **Podman `.kube`:** Kubernetes natively starts all containers in a Pod concurrently. To run one-time pre-flight task *within* a Pod, use `initContainers`. To enforce order *between* different Pods, you must use systemd directives (`After=`, `Requires=`) in the `.kube` wrapper.

### Variable Interpolation
*   **Compose:** Natively expands environment variables in the YAML (e.g., `user: "${UID}"` or `volumes: ["./data:/data"]`).
*   **Podman `.kube`:** Kubernetes YAML is strictly declarative. It does **not** evaluate shell variables or relative paths. You must hardcode explicit UIDs, GIDs, and absolute host paths.

## Host access from containers

When running on native Linux system, both Docker and Podman *do not* host access by default. Containers can access any host service bound to `0.0.0.0/0`. 

> You may find the effect of "host isolation" when using Docker Desktop on Mac/Windows, where the lightweight Linux VM physically separates the container network from your host.

For rootful Docker/Podman, the bridge interfaces (e.g. `docker0` or `podman`) for the containers exist on the host kernel. Therefore, you may use FirewallD rules to block the bridge subnet from accessing host addresses, including both the host IPs and the local LAN.

```bash
sudo firewall-cmd --permanent --new-zone=podman-isolated
# Podman bridge subnet 
sudo firewall-cmd --permanent --zone=podman-isolated --add-source=172.20.0.0/24

# Drop traffic targeting the host's physical LAN subnet
sudo firewall-cmd --permanent --zone=podman-isolated --add-rich-rule='rule family="ipv4" destination address="192.168.1.0/24" drop'
```

However, host access from rootless containers cannot be filtered since the virtual bridge is created inside the unprivileged user namespace. Podman uses `pasta` which copies the configuration from the host bridge interface, or `slirp4netns` which performs NAT, to route traffic to/from the host.  
The kernel will view the source IP as if come from the host, and therefore the traffic cannot be filtered.

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
containers:
  - name: app
    securityContext:
      runAsUser: 1000 
      runAsGroup: 1000
      supplementalGroups: [2000, 3000] 
```

### Build image from Dockerfile
Build image from Dockerfile on container start/restart. Unlike Docker Compose, Podman Quadlets does not support image building in a single Kubernetes YAML. Quadlets uses a `.build` unit to compile the image, and a `.kube` unit to execute it.

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
Secret=secret-token,type=mount,src=/path/to/secret/file
```

**Build file (`ContainerFile`)**

When used with Quadlets, you must use `ARG` to capture `BuildArg=` into the build context, and then assign it to `ENV`.

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
*Note: Paths must be absolute. Relative paths like `./data` will fail.*
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

### Environment Variable Injection (.env files)
Injecting variables directly or via external files. Quadlet's `ConfigMap=` reads Kubernetes ConfigMap YAML; it does not convert dotenv files. Put runtime values directly in `config.yaml` and inject them as ordinary environment variables.

**Docker Compose:**
```yaml
environment:
  - LOG_LEVEL=debug
env_file:
  - .env
```

**Kubernetes YAML (`.yaml`) + Quadlet (`.kube`):**
To supply the equivalent settings, write a ConfigMap and reference its metadata name.

*The ConfigMap (`config.yaml`):*
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  NODE_ENV: "production"
```

*The Quadlet Wrapper (`app.kube`):*
```ini
[Kube]
Yaml=/opt/app/app.yaml
ConfigMap=/opt/app/config.yaml
```

*The Kubernetes Manifest (`app.yaml`):*
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

### Networks
Attaching the stack to an external/shared network (e.g., a reverse proxy network).

**Docker Compose:**
```yaml
networks:
  default:
    name: proxy-net
    external: true
```

**Quadlet Wrapper (`.kube`):**
Networking configuration is completely removed from the YAML and handled by the systemd wrapper.
```ini
[Unit]
After=network-online.target proxy-net.network

[Kube]
Yaml=/opt/app/app.yaml
Network=proxy-net.network
```

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
Kubernetes splits health checks into Liveness (is it running?) and Readiness (can it accept traffic?).
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
