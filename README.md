# LNet Selftest Advanced Launcher

## Purpose

This script is a wrapper to the sequence of LNet Selftest commands.

## Features

- Translation from Hostnames to IP addresses through NSLookup
- Healthcheck of clients/servers through LNET Ping before startup
- Automated startup/shutdown of LNET Selftest module on clients/servers

## Usage

```
Usage: lnet-selftest -client-ips "HOST1 [HOST2]" -client-lnd-id "ID" -server-ips "HOST1 [HOST2]" -server-lnd-id "ID"

Mandatory Options:
  -client-hosts "HOST1 [HOST2]"   Space-Separated List of Hostnames or IP Addresses for Clients
  -client-lnd-id ID               Lustre Network Driver (LND) ID for Clients: { o2ib<INSTANCE> | tcp<INSTANCE> }
  -server-hosts "HOST1 [HOST2]"   Space-Separated List of Hostnames or IP Addresses for Servers
  -server-lnd-id ID               Lustre Network Driver (LND) ID for Servers: { o2ib<INSTANCE> | tcp<INSTANCE> }

Additional Options:
  -concurrency CONCURRENCY         Concurrency                                                            Default: [32]
  -distribute DISTRIBUTE           Distribution: { 1:1 | 1:n | n:1 | n:n }                                Default: [1:1]
  -loop LOOP                       Number of Loops                                                        Default: [1]
  -manage-lst-module-on-clients    Automatically Start/Stop LNET Selftest Module on Clients: { 0 | 1 }    Default: [0]
  -manage-lst-module-on-servers    Automatically Start/Stop LNET Selftest Module on Servers: { 0 | 1 }    Default: [0]
  -mode MODE                       Mode: { read | write }                                                 Default: [Write]

Purpose:
  Runs LNET Selftest Read / Write Performance Test between Clients and Servers
```

## Reference

LNET Selftest Wiki: https://wiki.lustre.org/LNET_Selftest
