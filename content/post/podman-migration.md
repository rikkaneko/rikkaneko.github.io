---
date: '2026-10-29T15:00:14+08:00'
draft: false
title: 'Migrate Docker Compose to Podman Quadlets Kube'
---

Docker is a convenient tool for rapid development and deployment. Before its creation, developers often needed to set up massive development environments locally or in VMs for cross-platform development. Now, they can pull pre-built images from upstream vendors and immediately start building projects, which is especially useful for deep learning and web development. Maintaining production environments is also a headache without Docker. For small-scale application services, simply including a `Dockerfile` and `docker-compose.yaml` in a repository enables rapid development by pipelining image building, service lifecycle, storage, and network management.

However, I am concerned about the security of Docker. The most critical issue is that the Docker daemon is rootful, meaning that any user with access to Docker gets full system access. Also, some pre-built images even run the application as root by default, which maps to the `root` user on the host system. Given that our lovely system libraries and popular services may contain more security vulnerabilities waiting to be discovered, I feel it is critical to run Internet-facing services in an unprivileged sandbox environment to minimize the attack surface.

After researching different alternatives using LLM, I found [Podman Quadlets](https://www.redhat.com/en/blog/quadlet-podman) to be a good approach for production deployments, especially since its configuration syntax is compatible with the Kubernetes [kubelet](https://kubernetes.io/docs/concepts/overview/components/#kubelet).  

This post summarizes the key steps to migrate `docker-compose.yml` file into Podman Quadlet Kube for my own reference.

---

# Architectural Differences & Limitations

## Default behavior changes

### The Pod Network Namespace
*   **Compose:** Each container gets a unique IP on a bridge network and resolves other containers via DNS (e.g., `http://database:5432`).
*   **Podman `.kube`:** All containers defined in a single Kubernetes YAML file are scheduled into a **Pod**. They share the exact same network namespace. 
    *   **Limitation - Port Conflicts:** You cannot have two containers in the same Pod listening on the same internal port (e.g., two web apps listening on port 80).
    *   **Behavioral Change - Routing:** Containers within the same Pod communicate via `localhost` (e.g., `http://127.0.0.1:5432`). 

### Dependency Management
*   **Compose:** Uses `depends_on` to control startup order.
*   **Podman `.kube`:** Kubernetes natively starts all containers in a Pod concurrently. To enforce order *within* a Pod, you must use `initContainers`. To enforce order *between* different Pods, you must use systemd directives (`After=`, `Requires=`) in the `.kube` wrapper.

### Variable Interpolation
*   **Compose:** Natively expands environment variables in the YAML (e.g., `user: "${UID}"` or `volumes: ["./data:/data"]`).
*   **Podman `.kube`:** Kubernetes YAML is strictly declarative. It does **not** evaluate shell variables or relative paths. You must hardcode explicit UIDs, GIDs, and absolute host paths.

---

## Equivalent Configurations

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
Injecting variables directly or via external files.  

Unlike a full Kubernetes cluster, Podman does not have a shared global registry for ConfigMaps. The `.env` ConfigMap generated by the Quadlet is ephemeral and strictly isolated to this specific Pod. Therefore, you can use the same filename `.env` across different projects on the same host.

**Docker Compose:**
```yaml
environment:
  - LOG_LEVEL=debug
env_file:
  - .env
```

**Kubernetes YAML (`.yaml`) + Quadlet (`.kube`):**
To mimic `env_file`, we use the Quadlet wrapper to dynamically generate a `ConfigMap` at boot.

*The Quadlet Wrapper (`app.kube`):*
```ini
[Kube]
Yaml=/opt/app/app.yaml
ConfigMap=/opt/app/.env
```

*The Kubernetes Manifest (`app.yaml`):*
```yaml
containers:
  - name: app
    # Explicit variables
    env:
      - name: LOG_LEVEL
        value: "debug"
    # Inject all from the generated .env ConfigMap
    envFrom:
      - configMapRef:
          name: .env
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

### 2.6. Health Checks
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

A Node.js backend relying on a Postgres database. We want to expose the backend port, persist the DB data, use an `.env` file for secrets, and ensure the DB is healthy before the backend starts.

### Kubernetes Manifest: `/opt/stack/stack.yaml`
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-stack
spec:
  # initContainers run sequentially before normal containers start.
  # This replaces Compose's `depends_on: condition: service_healthy`
  initContainers:
    - name: wait-for-db
      image: docker.io/library/postgres:15
      command: ['sh', '-c', 'until pg_isready -h 127.0.0.1 -p 5432; do echo waiting for db; sleep 2; done;']
  
  containers:
    - name: database
      image: docker.io/library/postgres:15
      envFrom:
        - configMapRef:
            name: .env
      volumeMounts:
        - name: pg-data
          mountPath: /var/lib/postgresql/data
      livenessProbe:
        exec:
          command: ["pg_isready", "-U", "postgres"]
        periodSeconds: 10

    - name: backend
      image: docker.io/myorg/backend:latest
      ports:
        - containerPort: 3000
          hostPort: 8080
      env:
        # Connect via localhost since they share the Pod network namespace
        - name: DB_HOST
          value: "127.0.0.1"
      envFrom:
        - ConfigMap:
            name: .env

  volumes:
    - name: pg-data
      persistentVolumeClaim:
        claimName: postgresql-data
```

### Quadlet: `~/.config/containers/systemd/stack.kube`
```ini
[Unit]
Description=My Full Stack Application
After=network-online.target

[Kube]
# Absolute path to the manifest
Yaml=/opt/stack/stack.yaml
# Mounts /opt/stack/.env as a ConfigMap dynamically
ConfigMap=/opt/stack/.env
# Optional: Enable auto-updates if the container image has a new tag in the registry
AutoUpdate=registry

[Install]
WantedBy=default.target
```