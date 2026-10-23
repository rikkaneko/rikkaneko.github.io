---
date: '2026-10-23T13:31:18+08:00'
draft: false
title: 'RCE vulnerabilities in PHP and Nodejs'
---

This October is definitely a disastrous month to all people work in IT. Multiple critical security vulnerabilities are found in popular open source projects used by nearly all companies in the world.  

[PHP](https://www.php.net/archive/2026.php#2026-10-21-5) ([CVE-2026-109618](https://github.com/php/php-src/security/advisories/GHSA-w8hw-w9fx-j79w), [CVE-2026-109619](https://github.com/php/php-src/security/advisories/GHSA-6wmf-4rv5-p3rp)), [Node.js](https://nodejs.org/en/blog/vulnerability/october-2026-security-releases#nodejs-brotli-decoder-out-of-bounds-write-permits-remote-code-execution-cve-2026-111497---high) ([CVE-2026-111497](https://www.imperva.com/blog/node2shell-from-brotli-data-to-remote-code-execution/)) contains Remote Code Execution (RCE) vulnerabilities that can be exploited to inject arbitrary code in the server. Meanwhile, [LiteLLM](https://docs.litellm.ai/blog/security-incident-oct-21-2026) leaked their release key [again](https://docs.litellm.ai/blog/security-update-march-2026) and [eMudhra](https://emudhra.we-have-a-problem.com/) used very weak private keys, where one of them is literally `4`, for their intermediate CA certificates.

This month, many of the discovered vulnerabilities were found by LLMs, especially OpenAI's GPT and Claude. Some of these bugs have existed for over ten years but are only being reported recently. It is likely that more bugs are already being exploited by interested parties and are waiting to be found. There are many POCs for these CVEs available in Github. You may search them online if you are interested. Here is just for my own notes on how these vulnerabilities works.

## PHP

|Affected Versions|Fixed Version|
|-|-|
|`v8.2.x`|`8.2.35`|
|`v8.3.x`|`8.3.26`|
|`v8.4.x`|`8.4.27`|
|`v8.5.x`|`8.5.12`|
|`7.4`, `8.0`, `8.1`|No official release. Use LTS or backported packages.|
|Older versions|**No fixes**|

### CVE-2026-109618
Out Of Memory (OOM) corruption.  

This bug is caused by incorrect check when handling multipart POST request.  
Although PHP has a `post_max_size` option to limit maximum file upload size, this check does not apply to
- multipart POST request **without** declare content length
- multipart POST request with massive amount of headers
- multipart POST request with massive amount of empty file controls
These kind of requests may cause PHP workers to OOM and being shutdown by its controller.  

Here is the problem ⎯ PHP does not implement early exit properly, request memory is temporarily reachable before it is fully initialized. If memory allocation failed before this point, due to OOM situation, the request memory in an invalid state. Attacker can construct special request payload to inject malicious bytes into the worker memory, achieving RCE.

Note that this bug specially requires the web server to be **Apache mod_php** and **FrankenPHP**, while **FPM** exits the child when request startup fails instead.

### CVE-2026-109619
Stable global state (User-after-free or race condition).  

This bug allows a situation where the next request may access stale state that **has not yet been reset** by the handling of the previous request. Special crafted request may create inject malicious code to the request memory heap.   

As mentioned in the official security advisor, 

> A fatal error can cause this by abandoning the operation before it resets the state.

Runtime errors caused by bad code or misconfiguration, such as the OOM error triggered in [CVE-2026-109618](#cve-2026-109618), can lead to a stale global state. Non fatal errors and warnings are also found to access stale error state. For instance, subsequent request can access the stale value set by [fatal error reporting](https://laravel-news.com/php-fatal-error-backtraces-in-php-85).

It is worth noting that [session upload progress](https://www.php.net/manual/en/session.upload-progress.php) can reach session handling before session initialization complete. This feature is discovered to be the primary attack surface to RCE. If used alongside with CVE-2026-109618, it allows an attacker to access the previous session state interrupted by this error. Later upload progress operation will mark the stale global state valid, leaving the space for the attack.

## Node.js

|Affected Versions|Fixed Version|
|-|-|
|`v22.x`|`v22.23.4`|
|`v24.x`|`v24.22.1`|
|`v26.x`|`v26.12.1`|
|`v20.x` or older|**No fixes**|

### CVE-2026-111497
Built-in Brotli decoder out-of-bounds write may lead to emote code execution.

TBC

### CVE-2026-105482
Node.js' `dns.resolve` domain name checks ignores names containing `NUL` char.

TBC