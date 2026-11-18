---
date: '2026-11-17T16:57:21+08:00'
draft: false
title: 'Linux Package Repository'
---

I maintain custom Linux package repositories for software I use personally that is not yet available in the official repositories.
You may use my package repositories if you trust my prebuilt binary packages.

## Debian/APT

Make sure to read [about secure apt](https://wiki.debian.org/SecureApt) to understand how Debian APT validate downloaded packages.

| Repositories | |
|-|-|
| Server | https://files.nekoid.cc/pub/debian |
| APT Archive Keyring | Same as my GPG key or <br> https://files.nekoid.cc/pub/debian/archive-keyring.gpg |
| Fingerprint | `77857DC6BBB6429C8BE209F5D68E0BFE4115B78C` | 
| Architecture | `amd64`, `arm64` |

### Adding my repository

1. Retrieve the archive keyring file from the server.

> Validate if the GPG fingerprint is `77857DC6BBB6429C8BE209F5D68E0BFE4115B78C`.  

```bash
curl -o /tmp/archive-keyring.gpg https://files.nekoid.cc/pub/debian/archive-keyring.gpg
gpg --show-keys --with-fingerprint /tmp/archive-keyring.gpg;
```

2. Install the archive keyring file to `/etc/apt/keyrings`.  
You may pick any filename but it needs to match with `Signed-By` field in the source file.

```bash
sudo cp /tmp/archive-keyring.gpg /etc/apt/keyrings/archive-keyring-nekoid.gpg
sudo chmod 644 /etc/apt/keyrings/archive-keyring-nekoid.gpg
```

3. Create the source file for this repository at `/etc/apt/sources.list.d/nekoid.sources` with file mode `0644`.

```yaml
Types: deb
URIs: https://files.nekoid.cc/pub/debian/
Suites: trixie
Components: main
Architectures: amd64 arm64
Signed-By: /etc/apt/keyrings/archive-keyring-nekoid.gpg
```

### Package list

| Name | Version | amd64 | arm64 | Description |
|-|-|-|-|-|
|`podlet`|`0.3.2-1`| Yes | Yes | Built from [podlet](https://github.com/containers/podlet) |


## Archlinux/Pacman

Coming soon