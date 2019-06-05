#!/bin/sh

# wget path
wget="wget"
# ftp login
ftpLogin="--ftp-user=admin --ftp-password=admin"
# ftp root path
ftpPath="ftp://172.16.23.215/Qbox10/"

# load file from ..
ftpSrc=$ftpPath"update.txt"
# save file to ..
ftpDist="./update.txt"

cmd="$wget $ftpLogin $ftpSrc -O $ftpDist"
echo $cmd && $cmd
