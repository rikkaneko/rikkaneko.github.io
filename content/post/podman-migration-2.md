---
date: '2026-11-10T11:04:37+08:00'
draft: false
title: 'Migrate Docker Compose to Podman Quadlets (Container)'
---

## Preface

After few days of exploring Podman Quadlets (Kube), which use standard [Kubernetes YAML](https://docs.podman.io/en/stable/markdown/podman-kube-play.1.html) to build and run Podman containers, I find it is too complicated for my single node deployment. If you are not managing a multi-node deployment or do not need to migrate to a full Kubernetes (k8s) or [k3s](https://k3s.io/) environment, there is no need to use the `podman kube` extension. In most cases, [podman-compose](https://github.com/containers/podman-compose) wrapper, or even better, [Podman Quadlets (Container)](https://docs.podman.io/en/stable/markdown/podman-quadlet.1.html) can do the job.

*Quotes from the **podman-kube** docs:*

> Note: The kube commands in podman focus on simplifying the process of moving containers from podman to a Kubernetes environment and from a Kubernetes environment back to podman.

Still, the findings in [my previous post](../podman-migration) helped me understand the underlying mechanisms of how rootless containers can run securely in the Linux kernel with the help of user namespaces, as well as their limitations. Some of the notable issues relate to userspace networking and lower-level system access.

## Podlet

[Podlet](https://github.com/containers/podlet) is a great tool to generate Podman Quadlets files (`*.container`, `*.network`, `*.volume`, ...) from an existing `docker-compose.yaml` or a podman command line. Note that `podman generate systemd` is already deprecated and is being replaced by Quadlets to manage container service startups with systemd.  

These commands generate a single Quadlets file as `<app>.quadlets` from the existing compose file in current working directory. Afterward, split and install the single multi-unit Quadlets file into individual systemd unit files under `~/.config/containers/systemd/<app>`.

```bash
podlet compose --install --quadlets-file <app>.quadlets
podman quadlet install --application <app> <app>.quadlets
```

## Quadlets

The systemd generator included with Podman Quadlets scans the default directory (`~/.config/containers/systemd`) and its subdirectories recursively.

### Environment Variable Injection

#### Container

Quadlets' `[Container]` section supports `Environment=` and `EnvironmentFile=` options to configure environment variable inside container runtime environment.

```ini
[Container]
# Direct assignments
Environment=APP_ENV=production
# Path can be absolute or relative to the .container file location
EnvironmentFile=./.env
```

#### Build image

Unlike `[Container]` section, the `[Build]` section does not support a native `EnvironmentFile=` option. Use `PodmanArgs=--build-arg-file=` to load build arguments from a file.

Relative paths inside `PodmanArgs=` are resolved from the Podman process’s working directory. Use `[Build] SetWorkingDirectory=` or `[Service] WorkingDirectory=` to specify the build context.

```ini
[Build]
# Store the variable into built image
Environment=BUILD_VERSION=1.2.0
# Forward the variable to `ARG COMPILER_FLAGS` statement
BuildArg=COMPILER_FLAGS="-O3"
# Import environment variable from the file relative to the location of the .build file
SetWorkingDirectory=unit
PodmanArgs=--build-arg-file=./.env.build
```

> `[Build] BuildArg` is supported from [Podman v5.7](https://docs.podman.io/en/v5.7.0/markdown/podman-systemd.unit.5.html#buildarg). Before v5.7, use `[Build] PodmanArgs=--build-arg=BUILD_VERSION=v1.2.4` instead.