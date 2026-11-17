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
| APT Archive Keyring | **Same as my GPG key** or <br> via https://files.nekoid.cc/pub/debian/archive-keyring.gpg |
| Fingerprint | `77857DC6BBB6429C8BE209F5D68E0BFE4115B78C` | 
| Architecture | `amd64`, `arm64` |

### Adding my repositories

1. Retrieve the archive keyring file from the server. Then, verify the GPG key if the fingerprint is exactly `77857DC6BBB6429C8BE209F5D68E0BFE4115B78C`.  

```
curl -o /tmp/archive-keyring.gpg https://files.nekoid.cc/pub/debian/archive-keyring.gpg
gpg --show-keys --with-fingerprint /tmp/archive-keyring.gpg;
```

2. Install the archive keyring file to `/etc/apt/keyrings`. You may pick any filename but it needs to match with `Signed-By` field in the source list.

```
sudo cp /tmp/archive-keyring.gpg /etc/apt/keyrings/archive-keyring-nekoid.gpg
```

3. Create a source list for this repository at `/etc/apt/sources.list.d/nekoid.sources`.

```
Types: deb
URIs: https://files.nekoid.cc/pub/debian/
Suites: trixie
Components: main
Architectures: amd64 arm64
Signed-By: /etc/apt/keyrings/archive-keyring-nekoid.gpg
```

4. Refresh the package list then you are done.

### Provided packages

| Name | Version | Project | Modification | 
|-|-|-|-|
|`podlet`|`0.3.2-1`| [podlet](https://github.com/containers/podlet) | None |


## Archlinux/Pacman

Coming soon