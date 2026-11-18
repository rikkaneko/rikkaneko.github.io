---
date: '2026-11-18T16:52:00+08:00'
draft: false
title: 'Linux 軟件包倉庫'
---

我正在維護一個 Linux 軟件包倉庫來方便我自己下載安裝未修錄來官方倉庫的包，我不保證這個倉庫的可用性和更新速度。如果你覺得我是值得信任的話，可以根據以下的步驟在你的 Debian/Arch 系統添加這個倉庫來源。

## Debian/APT

在此以前，請確保你清楚了解 Debian APT [如何](https://wiki.debian.org/SecureApt)驗證遠端軟件包的安全性。

| 軟件包倉庫 | |
|-|-|
| 伺服器 | https://files.nekoid.cc/pub/debian |
| APT 套件庫金鑰環 | 使用我的 GPG key 或者 <br> https://files.nekoid.cc/pub/debian/archive-keyring.gpg |
| GPG 指紋 | `77857DC6BBB6429C8BE209F5D68E0BFE4115B78C` | 
| 架構 | `amd64`, `arm64` |

### 添加我的倉庫來源

1. 從伺服器下載 APT 套件庫金鑰環

> 請檢查下載的 APT 套件庫金鑰環的 GPG 指紋是 `77857DC6BBB6429C8BE209F5D68E0BFE4115B78C`。

```bash
curl -o /tmp/archive-keyring.gpg https://files.nekoid.cc/pub/debian/archive-keyring.gpg
gpg --show-keys --with-fingerprint /tmp/archive-keyring.gpg;
```

2. 安裝APT 套件庫金鑰環至 `/etc/apt/keyrings`。
你可以選擇任意檔案名稱，但檔案名稱必須跟 APT 來源設定檔的 `Signed-By` 一致。

```bash
sudo cp /tmp/archive-keyring.gpg /etc/apt/keyrings/archive-keyring-nekoid.gpg
sudo chmod 644 /etc/apt/keyrings/archive-keyring-nekoid.gpg
```

3. 在 `/etc/apt/sources.list.d/nekoid.sources` 創建 APT 來源設定檔，並設定其 Linux 檔案模式為 `0644`。

```yaml
Types: deb
URIs: https://files.nekoid.cc/pub/debian/
Suites: trixie
Components: main
Architectures: amd64 arm64
Signed-By: /etc/apt/keyrings/archive-keyring-nekoid.gpg
```

### 軟件包列表

| 名稱 | 版本 | amd64 | arm64 | 描述 |
|-|-|-|-|-|
|`podlet`|`0.3.2-1`| Yes | Yes | 從 [podlet](https://github.com/containers/podlet) 構建 |

## Archlinux/Pacman

敬請期待～