#!/bin/bash
year="http://www.slackware.com/security/list.php?l=slackware-security&y=2014"
todownload=()
md5db=()
echo "Checking state of system patches from Slackware Security.."
for advnum in $(wget -qO- "$year" | grep viewer | awk -F"\"" '{print "http://www.slackware.com/security/"$2}')
do
  files="`wget -qO- $advnum | grep "slackware64-14.1"`"
  for file in $files
  do
    if [ $(for n in `echo $file | grep -Eo '[^/]+/?$' | awk -F"-x86" '{print $1}'`;do ls /var/log/packages | grep $n;done) ]; then
      echo "    $(echo $file | grep -Eo '[^/]+/?$' | awk -F"-x86" '{print $1}') has already been applied"
    else
      echo "    $(echo $file | grep -Eo '[^/]+/?$' | awk -F"-x86" '{print $1}') has NOT been applied"
      todownload+=($file)
      rmd5="`wget -qO- $advnum | grep -e "[0-9a-f]\{32\}" | sed 's/ //g'`"
      for hashes in $rmd5
      do
        md5db+=($hashes)
      done
    fi
  done
done

echo
echo "SYSTEM REQUIRES FOLLOWING PATCHES....."
for n in "${todownload[@]}"
do
  echo "        DOWNLOADLIST: $(echo $n | grep -Eo '[^/]+/?$' | awk -F"-x86" '{print $1}')"
done
  
read -p "Continue patching system? [y]es | [n]o: " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
  exit 1
fi
#we will continue and download the patches now..
for n in "${todownload[@]}"
do
  echo
  echo "Fetching: $(echo $n | grep -Eo '[^/]+/?$' | awk -F"-x86" '{print $1}')"
  wget -nv $n
done
echo


safe=()
echo "Finished fetching.. Checking MD5 Sums..."
for n in "${todownload[@]}"
do
  f=$(echo $n | grep -Eo '[^/]+/?$')
  fmd5="`md5sum $f* | awk '{print $1}'`"
  echo "MD5: $f     - $fmd5"
  echo "Checking sum against published signatures"
  fstripped="`echo $f | sed 's/\-[0-9].*$//'`"
  for r in "${md5db[@]}"
  do
    if [ $(echo $r | grep $f) ]; then
      echo "Checking against $r"
      if [ $(echo $r | grep $f |grep $fmd5) ]; then
        echo "          MD5 Matched"
        safe+=($f)
      else
        echo "          MD5sum cannot be matched"
      fi
    fi
  done
  echo
done
echo "The following packages are safe to upgrade.."
for chkd in "${safe[@]}"
do
  echo "        $chkd"
done
echo "Running updatepkg"
for item in "${safe[@]}"
do
  upgradepkg $item
