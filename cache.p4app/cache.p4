/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>
#include "udp.p4"

const socketPort_t PORT_CACHE_REQ = 0x4d2;

/**
    +----------------------+
    |       ........       |  Ethernet
    +----------------------+
    |       ........       |  IPv4
    +----------------------+
    |       ........       |  UDP (dstPort=1234)
    +----------------------+
    | key (8 bits)         |  Request header
    +----------------------+
*/
header cache_req_t {
    bit<8> key;
}

/**
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
*/
header cache_res_t {
    bit<8>  key;
    bit<8>  isvalid;
    bit<32> value;
}

struct cache_metadata_t {
    bit<8>  isvalid;
    bit<32> value;
}

struct metadata {
    cache_metadata_t cache_metadata;
}

struct headers {
    ethernet_t  ethernet;
    ipv4_t      ipv4;
    udp_t       udp;
    cache_req_t cache_req;
    cache_res_t cache_res;
}

parser MyParser(packet_in packet,
                out headers hdr,
                inout metadata meta,
                inout standard_metadata_t standard_metadata) {
    state start {
        packet.extract(hdr.ethernet);
        transition select(hdr.ethernet.etherType) {
            TYPE_IPV4: parse_ipv4;
            default: accept;
        }
    }

    state parse_ipv4 {
        packet.extract(hdr.ipv4);
        transition select(hdr.ipv4.protocol) {
            PROTO_UDP: parse_udp;
            default: accept;
        }
    }

    state parse_udp {
        packet.extract(hdr.udp);
        transition select(hdr.udp.srcPort, hdr.udp.dstPort) {
            (_, PORT_CACHE_REQ): parse_cache_req;
            (PORT_CACHE_REQ, _): parse_cache_res;
            (_, _): accept;
        }
    }

    // state other_port {
    //     transition select(hdr.udp.srcPort) {
    //         (PORT_CACHE_REQ, _): parse_cache_res;
    //         default: accept;
    //     }
    // }

    state parse_cache_req {
        packet.extract(hdr.cache_req);
        transition accept;
    }

    state parse_cache_res {
        packet.extract(hdr.cache_res);
        transition accept;
    }
}

control MyVerifyChecksum(inout headers hdr, inout metadata meta) {   
    apply { /* empty */ }
}

control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {
    register<bit<33>>(256) cacheReg;

    action drop() {
        mark_to_drop();
    }

    action ipv4_forward(macAddr_t dstAddr, egressSpec_t port) {
        standard_metadata.egress_spec = port;
        hdr.ethernet.srcAddr = hdr.ethernet.dstAddr;
        hdr.ethernet.dstAddr = dstAddr;
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
    }

    action cache_hint(bit<32> value) {
        hdr.cache_req.setInvalid();

        hdr.cache_res.setValid();
        hdr.cache_res.key = hdr.cache_req.key;
        hdr.cache_res.isvalid = 0x1;
        hdr.cache_res.value = value;

        socketPort_t originSrcPort = hdr.udp.srcPort;
        hdr.udp.srcPort = hdr.udp.dstPort;
        hdr.udp.dstPort = originSrcPort;
        hdr.udp.len = hdr.udp.len + 5;
        hdr.udp.checksum = 0;

        ipv4Addr_t originSrcIp = hdr.ipv4.srcAddr;
        hdr.ipv4.srcAddr = hdr.ipv4.dstAddr;
        hdr.ipv4.dstAddr = originSrcIp;
        hdr.ipv4.totalLen = hdr.ipv4.totalLen + 5;

        macAddr_t originSrcMac = hdr.ethernet.srcAddr;
        hdr.ethernet.srcAddr = hdr.ethernet.dstAddr;
        hdr.ethernet.dstAddr = originSrcMac;

        standard_metadata.egress_spec = standard_metadata.ingress_port;
    }

    table ipv4_lpm {
        key = {
            hdr.ipv4.dstAddr: lpm;
        }
        actions = {
            ipv4_forward;
            drop;
            NoAction;
        }
        size = 1024;
        default_action = NoAction();
    }

    table kw_cache {
        key = {
            hdr.cache_req.key: exact;
        }
        actions = {
            cache_hint;
            NoAction;
        }
        size = 1024;
        default_action = NoAction();
    }

    apply {
        if (hdr.ipv4.isValid()) {
            if (hdr.cache_req.isValid()) {
                // lookup cache table
                kw_cache.apply();
                bit<33> cachei;
                cacheReg.read(cachei, (bit<32>)hdr.cache_req.key);
                if (cachei & (bit<33>)0x100000000 != 0) {
                    cache_hint((bit<32>)(cachei & 0xFFFFFFFF));
                } else {
                    ipv4_lpm.apply();
                }
            } else {
                if (hdr.cache_res.isValid()) {
                    // refresh cache table
                    bit<33> cacheo;
                    cacheo = 33w1 << 32;
                    cacheo = cacheo | (bit<33>)hdr.cache_res.value;
                    cacheReg.write((bit<32>)hdr.cache_res.key, cacheo);
                }
                ipv4_lpm.apply();
            }
        }
    }
}

control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {
    apply { }
}

control MyComputeChecksum(inout headers  hdr, inout metadata meta) {
    apply {
        update_checksum(
            hdr.ipv4.isValid(),
            {
                hdr.ipv4.version,
                hdr.ipv4.ihl,
                hdr.ipv4.tos,
                hdr.ipv4.totalLen,
                hdr.ipv4.identification,
                hdr.ipv4.flags,
                hdr.ipv4.fragOffset,
                hdr.ipv4.ttl,
                hdr.ipv4.protocol,
                hdr.ipv4.srcAddr,
                hdr.ipv4.dstAddr
            },
            hdr.ipv4.hdrChecksum,
            HashAlgorithm.csum16
        );
    }
}

control MyDeparser(packet_out packet, in headers hdr) {
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.ipv4);
        packet.emit(hdr.udp);
        packet.emit(hdr.cache_res);
        packet.emit(hdr.cache_req);
    }
}

V1Switch(
MyParser(),
MyVerifyChecksum(),
MyIngress(),
MyEgress(),
MyComputeChecksum(),
MyDeparser()
) main;
