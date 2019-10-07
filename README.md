# In-Network Cache

[![Travis Status](https://travis-ci.org/fno2010/switch-cache.svg?branch=master)](https://travis-ci.org/fno2010/switch-cache)

> CPSC634: In this assignment you will implement a cache for a simple key-value service.

Implement a simple in-network cache in P4.

> Although p4app is a lightweight tool to run P4 program, it is still a heavy
> load to run the docker service in my PC. Fortunately,
> [travis-ci][travis-ci-docker] provides the docker service support so that I
> can test my program easily. Thanks, [travis-ci][travis-ci-docker]!

Limitations:

- Current register cache is inefficient.
- Current UDP checksum is not enabled.
- Cannot handle ARP (static ARP tables now).

[travis-ci-docker]: https://docs.travis-ci.com/user/docker/

## Key-value service overview

A server contains a store of key-value mappings. A client can read values from
the store by issuing a read request. The read request indicates the key (8-bit
integer) of the object to be read. The server responds to a read request with
the key, along with its corresponding value. If the store doesn't contain a
value for the key, the server responds with the key, along with a flag
indicating the value is not present.

## Key-value Protocol

The client and server communicate with a custom protocol. The protocol has two
types of messages: requests and responses. The header format for requests and
responses is different. The UDP destination and source ports are used to
distinguish requests from responses: requests are sent to UDP *destination
port* 1234, whereas responses are *from UDP source port* 1234. The exact format
of the headers is outlined below.

### Request

Packet sent from client to server:

``` ascii
    +----------------------+
    |       ........       |  Ethernet
    +----------------------+
    |       ........       |  IPv4
    +----------------------+
    |       ........       |  UDP (dstPort=1234)
    +----------------------+
    | key (8 bits)         |  Request header
    +----------------------+
```

### Response

Response packet from server to client:

``` ascii
    +----------------------+
    |       ........       |  Ethernet
    +----------------------+
    |       ........       |  IPv4
    +----------------------+
    |       ........       |  UDP (srcPort=1234)
    +----------------------+
    | key (8 bits)         |
    | is_valid (8 bits)    |  Response header
    | value (32 bits)      |
    +----------------------+
```

## Client/Server Programs

Implementations of the client and server are provided for you in `client.py`
and `server.py`. They use the protocol definitions in `cache_protocol.py`. You
can run them locally on your computer (i.e. without the need for running BMV2
or Mininet). Start the server:

``` bash
./server.py
```

In another terminal, read key `1` with the client:

``` bash
./client.py 127.0.0.1 1
```

It should print `11`, which is the default value for key `1`. The server's
store has these default values:

``` bash
store = {1: 11, 2: 22}
```

You can override them when you start the server, e.g.

``` bash
./server.py 1=123 2=345 3=678
```

## Switch-based cache

Packets travel through exactly one switch between the client and the server:

``` ascii
client (h2) <---> switch (s1) <---> server (h1)
```

You should implement a cache in the switch. The cache is transparent, in
that neither the server nor the client is aware of the cache. When a client
requests a key, it sends a request packet through the switch. The switch should
parse the request packet, to determine the key that is being requested. If
there is a cache hit (i.e. the requested key is in the switch cache), then the
switch should respond directly to the client with the value in a response
packet. If there is a cache miss, the switch should forward the packet to the
server as normal. Note that the server shouldn't receive the client's request
if there was a cache hit at the switch.

### Updating the switch cache

The switch maintains two types of caches. The first is implemented as a P4
table, and is updatable from the control plane with P4Runtime. The second is
implemented with registers, and is updated from responses from the server.

The switch checks the caches in this order: if there's a cache hit in the
table, it uses the value from the table; if there is a cache hit in the
registers, then it uses the value from the registers; otherwise, it's a cache
miss, and the packet should be forwarded as normal.

To implement the register-based cache, you can use the key as an index into the
register cell that contains the value. This means that with an 8-bit key, the
register array needs at least 2^8 cells.

## Getting Started

Make sure you have installed `make` and `docker`.

To automatically set up your environment:

``` bash
$ make prepare
git clone -b rc-2.0.0 https://github.com/p4lang/p4app.git
Cloning into 'p4app'...
remote: Enumerating objects: 597, done.
remote: Total 597 (delta 0), reused 0 (delta 0), pack-reused 597
Receiving objects: 100% (597/597), 151.92 KiB | 1.95 MiB/s, done.
Resolving deltas: 100% (309/309), done.
p4app/p4app update
rc-2.0.0: Pulling from p4lang/p4app
Status: Downloaded newer image for p4lang/p4app:rc-2.0.0
```

(**Optional**) If you are also running `docker` in a Windows-based bash environment (e.g.,
WSL) like me, you can apply a patch to the original `p4app` tool to make it
recognize your file path correctly:

``` bash
$ make patch
if [ ! -d p4app ]; then \
        git clone -b rc-2.0.0 https://github.com/p4lang/p4app.git; \
fi
p4app/p4app update
rc-2.0.0: Pulling from p4lang/p4app
Digest: sha256:f4a376e61a84d4cee1e4a19b9ff45a140327d5c1ff2021ed45f9101d26fb812d
Status: Image is up to date for p4lang/p4app:rc-2.0.0
docker.io/p4lang/p4app:rc-2.0.0
cd p4app
git apply ../win-docker.patch
```

To run this p4app:

``` bash
$ make run
p4app/p4app run cache.p4app
> python /p4app/main.py
*** Error setting resource limits. Mininet's performance may be affected.
> p4c-bm2-ss --std p4-16 "/p4app/cache.p4" -o "/tmp/p4app-logs/cache.json" --p4runtime-files "/tmp/p4app-logs/cache.p4info.txt"
tcpdump: listening on eth0, link-type EN10MB (Ethernet), capture size 262144 bytes
query 1
15:04:23.064930 IP (tos 0x0, ttl 64, id 47498, offset 0, flags [DF], proto UDP (17), length 29)
    10.0.0.2.47509 > 10.0.0.1.1234: [udp sum ok] UDP, length 1
('10.0.0.2', 47509) -> Req(1), <- Res(11)
15:04:23.067511 IP (tos 0x0, ttl 63, id 21629, offset 0, flags [DF], proto UDP (17), length 34)
    10.0.0.1.1234 > 10.0.0.2.47509: [udp sum ok] UDP, length 6
11

query 1
15:04:23.092308 IP (tos 0x0, ttl 64, id 47499, offset 0, flags [DF], proto UDP (17), length 29)
    10.0.0.2.45280 > 10.0.0.1.1234: [udp sum ok] UDP, length 1
15:04:23.093151 IP (tos 0x0, ttl 63, id 47499, offset 0, flags [DF], proto UDP (17), length 34)
    10.0.0.1.1234 > 10.0.0.2.45280: [no cksum] UDP, length 6
11

query 2
15:04:23.133726 IP (tos 0x0, ttl 64, id 47503, offset 0, flags [DF], proto UDP (17), length 29)
    10.0.0.2.40699 > 10.0.0.1.1234: [udp sum ok] UDP, length 1
('10.0.0.2', 40699) -> Req(2), <- Res(22)
15:04:23.139191 IP (tos 0x0, ttl 63, id 21636, offset 0, flags [DF], proto UDP (17), length 34)
    10.0.0.1.1234 > 10.0.0.2.40699: [udp sum ok] UDP, length 6
22

query 3
15:04:23.176333 IP (tos 0x0, ttl 64, id 47504, offset 0, flags [DF], proto UDP (17), length 29)
    10.0.0.2.49337 > 10.0.0.1.1234: [udp sum ok] UDP, length 1
15:04:23.178082 IP (tos 0x0, ttl 63, id 47504, offset 0, flags [DF], proto UDP (17), length 34)
    10.0.0.1.1234 > 10.0.0.2.49337: [no cksum] UDP, length 6
33

query 123
15:04:23.227228 IP (tos 0x0, ttl 64, id 47507, offset 0, flags [DF], proto UDP (17), length 29)
    10.0.0.2.42384 > 10.0.0.1.1234: [udp sum ok] UDP, length 1
('10.0.0.2', 42384) -> Req(123), <- Res(NOTFOUND)
15:04:23.230451 IP (tos 0x0, ttl 63, id 21641, offset 0, flags [DF], proto UDP (17), length 34)
    10.0.0.1.1234 > 10.0.0.2.42384: [udp sum ok] UDP, length 6
NOTFOUND


10 packets captured
10 packets received by filter
0 packets dropped by kernel
```
