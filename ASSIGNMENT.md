# Assignment Tips

## Getting started

We have provided a p4app with boilerplate code to get started with:

- `cache.p4` is a boilerplate P4 program in which you should implement your
  cache functionality.

- `main.py` starts a Mininet network with a single switch connecting a client
  and server host. You should extend this with P4Runtime calls to populate
  the table-based cache on the switch.

Before you start implementing the cache functionality, you should get basic
IPv4 forwarding working. You can look at these examples for how to implement
both the data plane and control plane:

- [p4app examples](https://github.com/p4lang/p4app/tree/rc-2.0.0/examples)
- [P4 tutorial exercises](https://github.com/p4lang/tutorials/tree/p4app/p4app-exercises)

Specifically, for implementing IPv4 forwarding, you should look at the [control
plane](https://github.com/p4lang/tutorials/blob/p4app/p4app-exercises/basic.p4app/main.py#L61)
and [data
plane](https://github.com/p4lang/tutorials/blob/p4app/p4app-exercises/basic.p4app/solution/basic.p4#L100)
from the `basic.p4app` tutorial exercise.

## Resources

You can get familiar with the P4_16 language specification:
https://p4.org/p4-spec/docs/P4-16-v1.1.0-spec.html

Registers are not part of the P4 language specfication, but are an extern in
the
[v1model.p4](https://github.com/p4lang/p4c/blob/a1c3e0b868d5be2c7921cc8a80cf1ea6c4aba80d/p4include/v1model.p4#L109)
used by BMV2. For sample usage, take a look at the
[register.p4app](https://github.com/p4lang/p4app/tree/rc-2.0.0/examples/registers.p4app)
example.

## Tips

- If you're changing the packet, don't forget to:
    - update the IP and UPD length fields; and
    - set the UDP checksum to 0.
- Don't use `valid` as a header field, as it conflicts with setValid/setInvalid in P4.
- p4app uses Mininet to connect hosts h1 and h2 to switch s1. The port numbers
  are assigned in increasing order, so h1 is connected to s2 on port 1, and h2 on
  port 2.
- After you run p4app, check that it creates the directory `/tmp/p4app-logs`.
    - If this directory does not exit, there may be a problem with your Docker installation.
- The switch dumps sent/received packets in `/tmp/p4app-logs/s1-eth*.pcap`
    - `eth1` is connected to h1, and `eth2` to h2
    - you can inspect the pcaps with [wireshark](https://www.wireshark.org/)
- You can also run wireshark on a single host, e.g. on host2:

    ~/p4app/p4app exec m h2 tcpdump -Uw - | wireshark -ki -

## Running

First, make sure you have p4app:

    cd ~/
    git clone --branch rc-2.0.0 https://github.com/p4lang/p4app.git

Then run this p4app:

    ~/p4app/p4app run cache.p4app