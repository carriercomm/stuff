import socket
import re
import time

HOST = '127.0.0.1'
PORT = 1337
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect((HOST, PORT))
data = s.recv(1024)
print repr(data)
s.sendall('START')

while(True):
    data = s.recv(1024)
    print repr(data)
    res = re.search('\.\.\. (.*)\?', repr(data))
    try:
        res2 = re.search('(.*).x.(.*)', res.group(1))
        try:
            thestuff = int(res2.group(1)) * int(res2.group(2))
            print '%s = %d' %(res.group(1), thestuff)
            s.sendall(str(thestuff) + '\n')
        except:
            print "maximum errrr"
    except:
        print "much sleeping zzzzzzzzzzzzzzzzzz"
        time.sleep(0.1)
