#!/usr/bin/env python
# coding=utf-8
import string
import re
import csv
from selenium import webdriver
from datetime import datetime

#avaaz url to watch
tehURL = "somethingsomething"
ignores = re.compile('(seconds|minute|minutes|just)\s(ago|now)')
lst = []
while True:
    try:
        driver = webdriver.PhantomJS()
        driver.get(tehURL)

        live = driver.find_element_by_id('block-petition-live-feed')
        now = datetime.now()
        with open("output.csv", "a") as csvfile:
            writer = csv.writer(csvfile, delimiter=',')
            lines = string.split(live.text, '\n')
            for l in lines:
                if l != 'RECENT SIGNERS':
                    if not ignores.search(l):
                        try:
                            enc = l
                        except:
                            enc = l.encode("utf-8")
                        if not enc in lst:
                            lst.append(enc)
                            enc = '%s, %s' %(now, enc.encode("utf-8"))
                            try:
                                print enc.encode("utf-8")
                            except:
                                print "Issuing printing output UTF8"
                            try:
                                writer.writerow(enc.split(','))
                            except:
                                print "Issuing writing to csv"

        driver.quit()
    except:
        print "A weird thing happened..."
