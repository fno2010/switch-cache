from p4app import P4Mininet
from mininet.topo import SingleSwitchTopo
from mininet.cli import CLI
import sys
import time

topo = SingleSwitchTopo(2)
net = P4Mininet(program='cache.p4', topo=topo)
net.start()

s1, h1, h2 = net.get('s1'), net.get('h1'), net.get('h2')

# Populate IPv4 forwarding table
hosts = [h1, h2]
for i in [1, 2]:
    host = hosts[i-1]
    s1.insertTableEntry(
        table_name='MyIngress.ipv4_lpm',
        match_fields={'hdr.ipv4.dstAddr': [host.IP(), 32]},
        action_name='MyIngress.ipv4_forward',
        action_params={'dstAddr': host.MAC(), 'port': i}
    )

# Populate the cache table
s1.insertTableEntry(
    table_name='MyIngress.kw_cache',
    match_fields={'hdr.cache_req.key': 3},
    action_name='MyIngress.cache_hint',
    action_params={'value': 33}
)


# Now, we can test that everything works

# Start CLI for debugging
# CLI(net)

# Start the server with some key-values
server = h1.popen('./server.py 1=11 2=22', stdout=sys.stdout, stderr=sys.stdout)
tcpdump = h2.popen('tcpdump -vv', stdout=sys.stdout, stderr=sys.stdout)
time.sleep(2) # wait for the server to be listenning

print('query 1')
out = h2.cmd('./client.py 10.0.0.1 1') # expect a resp from server
print(out)
assert out.strip() == "11"
print('query 1')
out = h2.cmd('./client.py 10.0.0.1 1') # expect a value from switch cache (registers)
print(out)
assert out.strip() == "11"
print('query 2')
out = h2.cmd('./client.py 10.0.0.1 2') # resp from server
print(out)
assert out.strip() == "22"
print('query 3')
out = h2.cmd('./client.py 10.0.0.1 3') # from switch cache (table)
print(out)
assert out.strip() == "33"
print('query 123')
out = h2.cmd('./client.py 10.0.0.1 123') # resp not found from server
print(out)
assert out.strip() == "NOTFOUND"

tcpdump.terminate()
server.terminate()
