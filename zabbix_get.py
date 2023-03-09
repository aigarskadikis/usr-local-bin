#!/bin/env python3
import argparse
import socket
import struct
import sys

ZBX_HDR_SIZE = 13

def recv_all(sock):
    buf = bytes('', 'utf-8')
    while len(buf)<ZBX_HDR_SIZE:
        chunk = sock.recv(ZBX_HDR_SIZE-len(buf))
        if not chunk:
            return buf
        buf += chunk
    return buf

data = 'agent.version'
packet = bytes('ZBXD\1', 'utf-8') + struct.pack('<Q', len(data)) + bytes(data, 'utf-8')

zbx_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

try:
    zbx_sock.connect(('127.0.0.1', 10050))
    zbx_sock.sendall(packet)
    zbx_srv_resp_hdr = recv_all(zbx_sock)
    zbx_srv_resp_body_len = struct.unpack('<Q', zbx_srv_resp_hdr[5:])[0]
    zbx_srv_resp_body = zbx_sock.recv(zbx_srv_resp_body_len)
    zbx_sock.close()

except socket.error as exc:
    print("Caught exception socket.error : %s" % exc)

print('='*50)
print(zbx_srv_resp_body.decode())
print('='*50)


print("Size of String representation is {}.".format(struct.calcsize('<Q')))


