---
date: '2026-10-15T17:47:29+08:00'
draft: false
title: 'Linux Network Hardening: Best Practices Using Reverse Proxies, FirewallD and Fail2Ban (Part II)'
---

# Preface

In my previous [post](./linux-network-hardening.md), I shared how to harden your OpenSSH server and reverse proxy to protect against web scans and malicious requests. This post will continue with best security practices with FirewallD and Fail2Ban. Especially if you start your service with Docker, this can be quite tricky while worked with these two tools.

# Filtering connection with FirewallD

FirewallD acts as a high level, user space frontend that manages and configures Linux Kernel's Netfilter framework, using nftables as the default backend. It provides simple CLI to manage the system firewall abstractly. While working with FirewallD, I found it often misbehave with Docker. 

> By default, Docker overrides FirewallD rules, accepting incoming connections to published ports regardless of your FirewallD settings.

## Enforce FirewallD rules with Docker published ports

There is a configurable option `StrictForwardPorts` in FirewallD which allow you enforcing the zone rules. 

```ini
# /etc/firewalld/firewalld.conf
# Defaults to "no"
StrictForwardPorts=yes
```

However, enabling this option effectively *breaks* the ability to automatically forward traffic from published ports to the container IP. You can think of this like port forwarding in NAT networks. Therefore, you need to explicitly add forwarding rules to the public zone in FirewallD.   

> Here is the most tricky part: ***You need to know the actual container IP!***.

Note that Docker may assign a different IP to the container on startup unless you configure a static IP explicitly. I would recommend configuring static IP for a reverse proxy container, and then routing all traffic via through container.

```sh
# StrictForwardPorts=no
# Automatically add DNAT rewrite rules
<host-ip:port> -► [DNAT] -► <container-ip:port>

# StrictForwardPorts=yes
# Requires explicit forward port rules
<host-ip:port> -► [Forward port rules (FirewallD)] -► <container-ip:port>
```

### Example Docker Compose config with static IP

```yaml
service:
  app:
    build: .
    ports:
      - 8080:8080 # Still required 
    networks:
      app_net:
        ipv4_address: 172.20.0.254

networks:
  app_net:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/24
```

### Example command to forward port 443 to port 8080 in specific container

```
# firewall-cmd --add-forward-port=port=443:proto=udp:toport=8080:toaddr=172.20.0.254
```

## Deep in Netfilter: Exact packet path between FirewallD and Docker

### Netfilter Routing Architecture

{{< ascii_graph >}}
          [ Ingress Traffic ]
                  │
                  ▼
          ┌────────────────┐
          │   PREROUTING   │
          └────────┬───────┘
                   │
                   ▼
             Route Decision
              ╱          ╲
    (For This Host)  (For Another Host)
          ╱                 ╲
         ▼                   ▼
    ┌─────────┐         ┌───────────┐
    │  INPUT  │         │  FORWARD  │
    └─────────┘         └───────────┘
         │                    │
         ▼                    ▼
   [ Host service ]    ┌───────────────┐
                       │  POSTROUTING  │
                       └───────────────┘
{{</ ascii_graph >}}

Fig. 1. Netfilter Routing Architecture

As you can see from the below diagram, in default settings (`StrictForwardPorts=no`), FirewallD rules will be bypassed by Docker's injected `DNAT` rules in the early `PREROUTING` stage. This will rewrites the destination IP from the host's IP to the container's private bridge IP, therefore, the package will be routed to `FORWARD` hook instead of the `NF_INET_LOCAL_IN` hook where FirewallD public zone input rules mounted. Consequently, any published ports will be exposed to the internet, bypassing all firewall rules.

### Netfilter Packet Flow: Docker Container Ingress

{{< ascii_graph >}}
                                 [ Ingress Traffic ]
                                         │
                                         ▼
            ┌────────────────────────────────────────────────────────────┐
            | Hook: NF_INET_PRE_ROUTING hook (Priority: -100 / nat)      |
            ├────────────────────────────────────────────────────────────┤
            | Table: ip nat                                              |
            ├────────────────────────────────────────────────────────────┤
            | Chain: PREROUTING ──► DOCKER ──► [ Rule: DNAT ]            |
            |                                         |                  |
            |                                         ▼                  |
            |                            Rewrite DEST to <container-ip>  |
            └────────────────────────────────────────────────────────────┘
                                         │
                                         ▼
      ┌────────────────────────────────────────────────────────────────────────┐
      | Kernel Routing Decision                                                |
      ├────────────────────────────────────────────────────────────────────────┤
      | * DEST is not local host IP ──► [ NF_INET_FORWARD Hook ]               |
      | * Bypass FirewallD public zone input rules in [NF_INET_LOCAL_IN Hook]  |
      └────────────────────────────────────────────────────────────────────────┘
                                         │
                                         ▼
  ┌───────────────────────────────────────────────────────────────────────────────┐
  | Hook: NF_INET_FORWARD (Priority: 0 / filter)                                  |
  ├───────────────────────────────────────────────────────────────────────────────┤
  |                                       │                                       |
  |                   ┌───────────────────┴───────────────────┐                   |
  |                   ▼                                       ▼                   |
  |  ┌─────────────────────────────────┐      ┌────────────────────────────────┐  |
  |  | StrictForwardPorts=no (Default) |      | StrictForwardPorts=yes         |  │
  |  ├─────────────────────────────────┤      ├────────────────────────────────┤  │
  |  | Table: inet firewalld           |      | Table: inet firewalld          |  │
  |  ├─────────────────────────────────┤      ├────────────────────────────────┤  │
  |  | Chain: filter_FORWARD           |      | Chain: filter_FORWARD          │  │
  |  |              │                  |      |              │                 │  │
  |  |              ▼                  |      |              ▼                 │  │
  |  | [ Rule: ct status dnat accept ] |      | Chain: filter_FORWARD_IN_ZONES |  │
  |  |              │                  |      |              │                 │  │
  |  |              ▼                  |      |              ▼                 |  │
  |  |          [Continue]             |      |  [Evaluate FirewallD rules]    |  │
  |  └─────────────────────────────────┘      |              │                 │  │
  |                                           |              ▼                 │  │
  |                                           |         [Continue]             │  │
  |                                           └────────────────────────────────┘  |
  └───────────────────────────────────────────────────────────────────────────────┘
                                        │
                                        ▼
              ┌───────────────────────────────────────────────────────┐
              | Hook: NF_INET_FORWARD (Priority: 0 / filter)          |
              ├───────────────────────────────────────────────────────┤
              | Table: ip filter                                      |
              | Chain: FORWARD                                        |
              |           ├──► Chain: DOCKER-USER (Custom user rules) |
              |           ├──► Chain: DOCKER-ISOLATION-STAGE-1        |
              |           └──► Chain: DOCKER                          |
              |                         │                             |
              |                         ▼                             |
              |   [ Rule: daddr <container-ip> dport <port> ACCEPT ]  |
              └───────────────────────────────────────────────────────┘
                                        │
                                        ▼ 
                  [ Route traffic to <container-ip> via docker0 ]
                                        │
                                        ▼
                            [ Container Application ]
{{</ ascii_graph >}}

Fig. 2. Netfilter Packet Flow: Docker Container Ingress  
*I make this diagram to explain the network traffic internally. If you find there are mistake, please tell me!*

# Banning IPs with Fail2Ban

Fail2Ban should be familiar to most of you. It continuously scans server log files, tracking how many times a specific IP address triggers the rules defined by its jails. If the IP exceeds the allowed threshold, it will execute the defined action ── i.e, blocking traffic from that address using `nftables`. 
By default, the `nftables` action bans ip or ports by a chain mounted at `input` hook with the priority `-1`. However, as show in Fig. 1, DNAT-ed traffic will be routed to `FORWARD` hook instead, completely bypassing the IP blacklist set by Fail2ban. I can only realize this firewall conflict after a month of my logs being spammed with massive numbers of requests, where individual IPs would repeatedly hammer the server.

## Example Netfilter table generated by Fail2Ban (Default)

```c
table inet f2b-table {
  set addr-set-banip {
    type ipv4_addr
    elements = { 1.2.3.4, 5.6.7.8, 8.9.10.11, 12.13.14.15 }
  }

  set addr6-set-banip {
    type ipv6_addr
  }

  chain f2b-chain {
    type filter hook input priority -1; policy accept; // Problem
    meta l4proto tcp ip saddr @addr-set-banip drop
    meta l4proto tcp ip saddr @addr-set-banip drop
    meta l4proto tcp ip saddr @addr-set-banip drop
    meta l4proto tcp ip6 saddr @addr6-set-banip drop
  }
}
```

To apply the IP blacklist correctly, this chain must be mounted at an earlier stage ── i.e, the `PREROUTING` hook with higher priority.  

## Fix Fail2Ban IP blacklist

Use the following action with custom `chain_hook` and `chain_priority`:

### 1. Ban from any ports

```ini
action_banip = %(nftables)s[name=banip, type=allports, chain_hook=prerouting, chain_priority=-150, blocktype=drop]
```

### 2. Ban from the specific port only

```ini
action_banip_port = %(nftables)s[name=banip-port, port=8080, protocol=tcp, chain_hook=prerouting, chain_priority=-150, blocktype=drop]
```

# Last words...

Reverse Proxies (Nginx), FirewallD and Fail2Ban are great network security shield against malicious Internet traffic. Combination with newer service deployment approach, like Docker, Podman and K8s, may result in surprise result. In the old days, system administrators would start services directly ── either as standalone processes or as code run by the web server—and manage the system firewall through low-level commands like `iptables` or `nftables`. Newer high-level management tools help abstract and hide low-level details. However, I think it is important to understand their underlying mechanism instead of blindly using them. That way, when things go wrong, we can easily pinpoint the root cause of the issue.