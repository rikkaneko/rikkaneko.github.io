---
date: '2026-10-23T13:31:18+08:00'
draft: false
title: 'RCE vulnerabilities in PHP and Nodejs'
---

This October is definitely a disastrous month to all people working in IT. Multiple critical security vulnerabilities are found in popular open source projects used by nearly all companies in the world.  

[PHP](https://www.php.net/archive/2026.php#2026-10-21-5) ([CVE-2026-109618](https://github.com/php/php-src/security/advisories/GHSA-w8hw-w9fx-j79w), [CVE-2026-109619](https://github.com/php/php-src/security/advisories/GHSA-6wmf-4rv5-p3rp)), [Node.js](https://nodejs.org/en/blog/vulnerability/october-2026-security-releases#nodejs-brotli-decoder-out-of-bounds-write-permits-remote-code-execution-cve-2026-111497---high) ([CVE-2026-111497](https://www.imperva.com/blog/node2shell-from-brotli-data-to-remote-code-execution/)) contains Remote Code Execution (RCE) vulnerabilities that can be exploited to inject arbitrary code in the server. Meanwhile, [LiteLLM](https://docs.litellm.ai/blog/security-incident-oct-21-2026) leaked their release key [again](https://docs.litellm.ai/blog/security-update-march-2026) and [eMudhra](https://emudhra.we-have-a-problem.com/) used very weak private keys, where one of them is literally `4`, for their intermediate CA certificates.

This month, many of the discovered vulnerabilities were found by LLMs, especially OpenAI's GPT and Claude. Some of these bugs have existed for over ten years but are only being reported recently. It is likely that more bugs are already being exploited by interested parties and are waiting to be found. There are many POCs for these CVEs available in Github. You may search them online if you are interested. Here is just for my own notes on how these vulnerabilities works.

# PHP

|Affected Versions|Fixed Version|
|-|-|
|`v8.2.x`|`8.2.35`|
|`v8.3.x`|`8.3.26`|
|`v8.4.x`|`8.4.27`|
|`v8.5.x`|`8.5.12`|
|`7.4`, `8.0`, `8.1`|No official release. Use LTS or backported packages.|
|Older versions|**No fixes**|

## CVE-2026-109618
Out Of Memory (OOM) corruption.  

This bug is caused by incorrect check when handling multipart POST request.  
Although PHP has a `post_max_size` option to limit maximum file upload size, this check does not apply to
- Multipart POST request **without** declare content length
- Multipart POST request with massive amount of headers
- Multipart POST request with massive amount of empty file controls
These kind of requests may cause PHP workers to OOM and being shutdown by its controller.  

Here is the problem ⎯ PHP does not implement early exit properly, request memory is temporarily reachable before it is fully initialized. If memory allocation failed before this point, due to OOM situation, the request memory in an invalid state. Attacker can construct special request payload to inject malicious bytes into the worker memory, achieving RCE.

Note that this bug specially requires the web server to be **Apache mod_php** and **FrankenPHP**, while **FPM** exits the child when request startup fails instead.

### Workaround

#### 1. Enforce stricter requirements for request bodies in Nginx and WAF.  
*(Adjust the value as your application need)*

```nginx
server {
  ...
  # Limits headers to 4 buffers of 8K each (max 32KB total).
  large_client_header_buffers 4 8k;
  # Disables chunked streaming. Request must contains valid Content-Length header.
  chunked_transfer_encoding off;
  # Limit the absolute maximum payload size
  client_max_body_size 10M;
  # Prevent Nginx itself from buffering large attacks in RAM
  client_body_buffer_size 128k;
}
```

#### 2. Set `memory_limit=-1` in PHP main configuration and restart all workers to avoid predictable OOM condition.

## CVE-2026-109619
Stable global state (User-after-free or race condition).  

This bug allows a situation where the next request may access stale state that **has not yet been reset** by the handling of the previous request. Special crafted request may create inject malicious code to the request memory heap.   

As mentioned in the official security advisor, 

> A fatal error can cause this by abandoning the operation before it resets the state.

Runtime errors caused by bad code or misconfiguration, such as the OOM error triggered in [CVE-2026-109618](#cve-2026-109618), can lead to a stale global state. Non fatal errors and warnings are also found to access stale error state. For instance, subsequent request can access the stale value set by [fatal error reporting](https://laravel-news.com/php-fatal-error-backtraces-in-php-85).

It is worth noting that [session upload progress](https://www.php.net/manual/en/session.upload-progress.php) can reach session handling before session initialization complete. This feature is discovered to be the primary attack surface to RCE. If used alongside with CVE-2026-109618, it allows an attacker to access the previous session state interrupted by this error. Later upload progress operation will mark the stale global state valid, leaving the space for the attack.

### Workaround

#### 1. Set `session.upload_progress.enabled=0` in main configuration and restart all workers to remove this easiest attack path.
#### 2. Disable all fatal error, especially `fatal_error_backtraces=0`, warnings and diagnostics from all INI configuration.
#### 3. Set `pm.max_requests=1` to avoid concurrent workers. Note that this options may harm performance.

# Node.js

|Affected Versions|Fixed Version|
|-|-|
|`v22.x`|`v22.23.4`|
|`v24.x`|`v24.22.1`|
|`v26.x`|`v26.12.1`|
|`v20.x` or older|**No fixes**|

## CVE-2026-111497

*(Applied to any application linked to `libbrotli>=1.0.3,<=1.2.0` C library binding)*

Google's open source Brotli decoder out-of-bounds write may lead to emote code execution. 

Since this library is widely used by the network libraries for popular languages (Node.js, C++, Python, ...), basically any network library enabled with Brotli support are vulnerable to this bug. Another Google libraries [woff2](https://github.com/google/woff2), which is used to handle WOFF2 fonts, also depends on `libbrotli`. This affects any application need font rendering.

The fix is available in [google/brotli](https://github.com/google/brotli) v1.2.1 @ [0ed4268a](https://github.com/google/brotli/commit/0ed4268a) commit. 

Brotli stream is organized into metablocks, which contains multiple blocks. Each block has a `block_length` and its instruction to be decoded. If that counter reached zero, decoder will fetch new block from the Huffman tree until drained.

The core problem is in `c/dec/decode.c`. It defined a `BROTLI_SAFE` marco to map `BROTLI_FALSE` result from `SafeXXX` function to `BROTLI_DECODER_NEEDS_MORE_INPUT`. This marco blindly treat falsy result from safe function to be requesting new block.

```c
#define BROTLI_SAFE(METHOD)                         \
  {                                                 \
    if (safe) {                                     \
      if (!Safe##METHOD) {                          \
        result = BROTLI_DECODER_NEEDS_MORE_INPUT;   \
        goto saveStateAndReturn;                    \
      }                                             \
    } else {                                        \
      METHOD;                                       \
    }                                               \
  }
```

In RFC 7932, the [maximum metablock length](https://www.rfc-editor.org/info/rfc7932/#section-2) defined as 16,777,216 (16 MiB) bytes. In the Proof-Of-Concept code, the attacker packed exactly 16,777,216 block instructions into a single metablock, but wrote nothing to the output buffer to achieve `s->block_length[2] == 0`.

```c
...
CommandPostDecodeLiterals:
  // safe = true;
  if (BROTLI_PREDICT_FALSE(s->block_length[2] == 0)) {
    BROTLI_SAFE(DecodeDistanceBlockSwitch(s));
  }
  ...
```

```c
static BROTLI_INLINE BROTLI_BOOL DecodeDistanceBlockSwitchInternal(
    int safe, BrotliDecoderState* s) {
  if (!DecodeBlockTypeAndLength(safe /* true */, s, 2)) {
    return BROTLI_FALSE;
  }
  ...
}
```

If a stream declared a single block (`max_block_type <= 1`) and `s->block_length[2] == 0` successfully achieved, the decoder will enter an invalid state --- it need new block, but there are actually no block remains. Due to the missed boundary check here, attackers can write malicious bytes outside the output buffer region.

```c
static BROTLI_INLINE BROTLI_BOOL DecodeBlockTypeAndLength(int safe, BrotliDecoderState* s, int tree_type) {
    brotli_reg_t max_block_type = s->num_block_types[tree_type];
    if (max_block_type <= 1) {
      return BROTLI_FALSE; // Incorrectly handled as BROTLI_DECODER_NEEDS_MORE_INPUT
    }
  }
```

To achieve RCE, an attacker must know the target process's exact memory layout, down to the specific virtual memory addresses of the base system libraries. Moreover, existing verified POCs requir the target system to be running without [ASLR](https://en.wikipedia.org/wiki/Address_space_layout_randomization) and to run a [non-PIE](https://gcc.gnu.org/onlinedocs/gcc/Code-Gen-Options.html#index-fpie) executable, which is not easily found in the production environment.

### Workaround

#### 1. Disable brotli support in your application

- Reject Brotli request handling in Express 5.x

```js
const app = express();

// *Must* run before request parsing begin
app.use((req, res, next) => {
  const encoding = req.headers['content-encoding'];
  
  // Check for the 'br' token, handling comma-separated encoding chains
  if (encoding && /\bbr\b/i.test(encoding)) {
    return res.status(415).end();
  }
  next();
});

app.use(express.json());
```

- Turn off body inflation in Express 5.x. Note that this also disable other decompression support, including `gzip` and `deflate`.

```js
express.json({ inflate: false })
```

- Remove Brotli dependencies `brotli`,  `brotlicffi` and `httpx[brotli]` if possible in Python. Therefore, `aiohttp`, `request` and `urllib3` will fallback to gzip and deflate.

#### 2. Reject `Content-Encoding: br` request in reverse proxy and WAF

- Reject Brotli encoded request in Nginx (*for proxied application*)

```nginx
map $http_accept_encoding $safe_accept_encoding {
  # Match and remove 'br', leaving other encodings like 'gzip, deflate' remains
  ~*(.*)\bbr\b,?\s*(.*)  $1$2;
  default                $http_accept_encoding;
}

server {
  ...

  if ($http_content_encoding ~* "\bbr\b") {
    return 415;
  }

  location / {
    proxy_pass http://your_backend;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header Accept-Encoding $safe_accept_encoding;
    # Additional proxy settings...
  }
}
```

- Strip Accept-Encoding header from the $_SERVER array in PHP (*for PHP application*)

```nginx
server {
  if ($http_content_encoding ~* "\bbr\b") {
    return 415;
  }

  location ~ \.php$ {
    include fastcgi_params;
    fastcgi_pass unix:/run/php/php8.2-fpm.sock;

    # Forces PHP to return uncompressed or gzip data only
    fastcgi_param HTTP_ACCEPT_ENCODING ""; 
  }
}
```

- Disable Brotli support entirely in Nginx (*if enabled caching or used with FastCGI/PHP-FPM*)

```nginx
http {
  brotli off;
  brotli_static off;

  # Use gzip
  gzip on;
  gzip_proxied any;
  gzip_vary on;
  gzip_comp_level 6;
  gzip_min_length 256;
  gzip_types 
    application/json 
    application/javascript 
    application/xml 
    text/css 
    text/plain 
    text/xml;

  
  if ($http_content_encoding ~* "\bbr\b") {
      return 415 "Unsupported Media Type";
  }
}
```

## CVE-2026-105482
Node.js' `dns.resolve` domain name checks ignores names containing `NUL` char.

TBC