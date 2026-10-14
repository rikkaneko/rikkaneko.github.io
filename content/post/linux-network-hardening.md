---
date: '2026-10-14T11:07:07+08:00'
draft: false
title: 'Linux Network Hardening: Best Practices Using Reverse Proxies, FirewallD and Fail2Ban (Part I)'
---

# Preface

Most Linux distributions provides [FirewallD](https://wiki.archlinux.org/title/Firewalld) packages which allow dynamically managed firewall with support for firewall [zones](https://firewalld.org/documentation/zone/), without the need of manipulating [nftables](https://wiki.archlinux.org/title/Nftables)/[iptables](https://wiki.archlinux.org/title/Iptables) rules manually. FirewallD is convenient and powerful enough to protect your server from malicious Internet traffic.  

Last year (2025), I even replaced the official OpenWrt image with stock Debian 13 on my home router ([NanoPi R5S](https://wiki.friendlyelec.com/wiki/index.php/NanoPi_R5S)) and used FirewallD for firewall management. It still works pretty well today. You may view [Trey's blog](https://eldon.me/arch-linux-based-home-router-part-iii-firewalld-configuration/) for detail instruction.

> You need to be aware of the fact that the Internet is very dangerous —- any internet-accessible device will keep being scanned and targeted with exploits by some **S.O.B.**.  

# Use non-standard ports

Most web scanner scan standard service ports, especially, `22` (ssh), `80` (http) and `443` (https). Unless you have a strong reason, you should not publish the services with their default ports. Instead, pick a non-standard high port (`1024`~`65535`) randomly for your services. With just this small change, the number of malicious requests and login attempts was greatly reduced.

# Hardening OpenSSH server

Your OpenSSH server is the ultimate backdoor to your system. Traditional password login is vulnerable to brute force login attack. Therefore, you should enable public key authentication only for OpenSSH server.
Once you login your system, the very first task is to configure your public SSH key. You can either 
1. [Copy the public key to the remote server](https://wiki.archlinux.org/title/SSH_keys#Copying_the_public_key_to_the_remote_server) or
2. Insert your public key to `~/.ssh/authorized_keys` directly. Follow [this instruction](https://wiki.archlinux.org/title/SSH_keys#Key_ignored_by_the_server) to set the correct permission.

> **Double-check** if your public key is correctly configured before updating the server config. Otherwise, you will be locked outside your system.

```
# /etc/ssh/sshd_config
PasswordAuthentication no
PubkeyAuthentication yes
# Applicable to old version of SSH
ChallengeResponseAuthentication no
```

# Hardening reverse proxy

I typically use Nginx as my primary reverse proxy in my servers. Nginx is an open-source, high-performance web server with a highly customizable architecture. You may also use newer alternative like [caddy](https://github.com/caddyserver/caddy) and [traefik](https://github.com/traefik/traefik). They may share similar as I use in my Nginx configuration.

From my observation, common malicious requests to nginx are
- Scanning common application or file path, like `/login.jsp`, `/admin/config.php`, `/.env`, etc.
- Proxy command, like `CONNECT example.com:443 HTTP/1.1`
- Non-http requests, you will see a bunch of garbled text (each start with `\x` or some random characters)
  - If you see `mstshash=Administr` in the request, meaning it is scanning if you open a MS remote desktop.

Note that any request headers including `User-Agent` string is **meaningless**. Recently, I observed that many new requests often pretend to be AI bots, like `ClaudeBot/1.0` and `DeepSeekBot/1.0`, and keep trying different titles. These malicious requests are extremely disgusting so I did many research on how to block away these requests while keep legitimate traffic going.

## Ways to handle these malicious requests

### 1. Define a default server block with `ssl_reject_handshake` option ⭐

This approach is the most effective since most attackers scan using only raw IP addresses, without a proper hostname or SNI header.  

`ssl_reject_handshake` requires the requested hostname matching your defined `server_name`, while `_` is an invalid placeholder that cannot be matched, otherwise, those requests will be aborted without further processing.

```nginx
server {
  listen 8000 ssl default_server;
  listen 8000 quic default_server reuseport;
  # Declare as default server
  server_name _;
  
  # Terminate TLS handshake if the requested hostname does not match.
  ssl_reject_handshake on;

  # Map to 444 if receive plain http traffic
  error_page 400 =444 /444_error;
  error_page 497 =444 /444_error;

  location = /444_error {
    return 444;
  }
}
```

In the above snippet, `return 444` is a special status code that instructs Nginx server to terminate the current connection without sending a standard HTTP response. This is useful for handling these kinds of requests while minimizing server overhead.

**cURL Example Response**

TLS Request with invalid hostname or raw IP address

```
* LibreSSL/3.3.6: error:1404B458:SSL routines:ST_CONNECT:tlsv1 unrecognized name
* Closing connection
```

When trigger `return 444` in Nginx

```
* Empty reply from server
* Closing connection
curl: (52) Empty reply from server
```

### 2. Specify the base path for proxied services

Instead of defining everything in the default location `/`, mount your application with a specific base path. Most web development frameworks already support specify application base path, i.e., `basePath` and `NEXT_PUBLIC_*` options. As a result, most web scan requests cannot reach your actual service and are instead filtered out.

If the application does not support prefixing, you may use [rewrite](https://nginx.org/en/docs/http/ngx_http_rewrite_module.html) option in Nginx to rewrite client request before sending to the actual server endpoint.

```nginx
server {
  ...
  # Actual service entry point
  location /api/v1/ {
    # Use this line if your service does not support prefix
    # rewrite ^/api/v1/(.<other>*)?$ /$other break;
    ...
    proxy_pass http://api;
  }
 
  # Fallback path
  location / {
    return 444;
  }
}
```

### 3. Put your server behind CDN

This is universal way for Internet facing application. With this approach, you can unitize the rich features from the CDN. In this case, all "user" should come from the CDN provider IP ranges only. You can find the list of IP blocks from their website. 

**Cloudflare Example**

IP whitelist from [Cloudflare IP Ranges](https://www.cloudflare.com/ips/)

```
# cdn_ips.rules
allow 173.245.48.0/20;
allow 103.21.244.0/22;
allow 103.22.200.0/22;
allow 103.31.4.0/22;
...
```

**Nginx configuration**

```nginx
server {
  listen 443 ssl;
  # As same as CDN domain name
  server_name example.nekoid.cc;
  include /etc/nginx/conf.d/cdn_ips.rules;
  # Only allow request from CDN
  deny all;

  # More blocks...
}
```