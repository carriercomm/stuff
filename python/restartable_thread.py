import threading
import time

class ThreadRestartable(threading.Thread):
    def __init__(self, theName):
        threading.Thread.__init__(self, name=theName)

    def run(self):
        print "In ThreadRestartable\n"
        time.sleep(10)

thd = ThreadRestartable("WORKER")
thd.start()

while(1):
    i = 0
    for t in threading.enumerate():
        if t.name is "WORKER":
        i = 1
    print threading.enumerate()
    if i == 0:
        thd = ThreadRestartable("WORKER")
        thd.start()
    time.sleep(5)
