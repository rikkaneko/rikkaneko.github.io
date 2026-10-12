---
date: '2026-10-12T11:00:00+08:00'
draft: false
lang: zh
title: '我的項目'
---

我所有開源項目都在 [@rikkaneko](https://github.com/rikkaneko).   
如果你想貢獻新的功能和補丁，歡迎 PR ！

## paste

[[倉庫]](https://github.com/rikkaneko/paste) [[鏈結]](https://pb.nekoid.cc)

針對 [Cloudflare Workers](https://developers.cloudflare.com/workers/) 平台開發的小文件 （Paste）快速分享服務。
支持透過在大部分 Linux 發行版 / Windows / MacOS 內建 `curl` 命令行、[paste-cli](https://raw.githubusercontent.com/rikkaneko/paste/refs/heads/main/client/paste-cli) 客戶端和網頁前端上傳和檢視 Paste。

## yue2pinyin

[[倉庫]](https://github.com/rikkaneko/yue2pinyin) [[鏈結]](https://yue2pinyin.nekoid.cc)

將粵語字轉換成，帶發音提示近拼普通話拼音的實驗性項目。  
使用了來自 CUHK 語言系的教學文檔、[works.hk](https://works.hk) 的粵語字典和來自 [rime-cantonese](https://github.com/rime/rime-cantonese) 項目的粵拼字典，目標是幫助來自中國內地的普通話使用者學習粵語。

## sloth

[[倉庫]](https://github.com/rikkaneko/sloth)

針對容器化和本地服務的雲端備份工具，支持備份主流關聯式資料庫、Directus 快照、RabbitMQ 和 Docker/Podman Volume 至任何兼容 S3 標準的物件儲存服務。  
單一 Go 命令行。

## rabbitmq-action

[[倉庫]](https://github.com/rikkaneko/rabbitmq-action)

透過 RabbitMQ 或其他兼容 AMQP 的服務觸發本地任務的 GitHub Action。  
跟 [rabbitmq-action-agent](https://github.com/rikkaneko/rabbitmq-action-agent) 配搭使用。

## rabbitmq-action-agent

[[倉庫]](https://github.com/rikkaneko/rabbitmq-action-agent)

在本地運行的 Go 守護進程，負責處理來自特定 RabbitMQ 
佇列的消息。  
跟 [RabbitMQ Publish Action](https://github.com/marketplace/actions/rabbitmq-publish) 配搭使用。

## [pdf2md-pipeline](https://github.com/rikkaneko/pdf2md-pipeline)

[[倉庫]](https://github.com/rikkaneko/pdf2md-pipeline)

以 Python 編寫，將任意/第三方應用滙出的 PDF 透過 LLM 整理成易讀的 Markdown 文檔。

## cert-tool

[[倉庫]](https://github.com/rikkaneko/cert-tool)

簡易維護自建 X.509 公鑰基礎設施的腳本。

## [useful-script](https://github.com/rikkaneko/useful-script)

[[倉庫]](https://github.com/rikkaneko/useful-script)

一些自用的腳本倉庫。