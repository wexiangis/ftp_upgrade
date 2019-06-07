#!/bin/sh

#
localPath=`pwd`

#----- ftp download/upload -----

# wget path
wget="wget"
# ftp ip
ftpIp="192.168.1.103"
# ftp user
ftpUser="admin"
# ftp passwd
ftpPwd="admin"
# ftp root path
ftpPath="m20"
# ftp log path
ftpLog=$ftpPath"/log"

# download $src $dist
# default remote folder /m20
# example: download update.txt $localPath"/update.txt"
download()
{
    cmd="$wget --ftp-user=$ftpUser --ftp-password=$ftpPwd ftp://$ftpIp/$ftpPath/$1 -O $2 -t 3 -T 3"
    echo $cmd
    $cmd
}

# upload $src $dist
# default remote folder /m20/log
# example: upload $localPath"/update.txt" 123.log
upload()
{
ftp -inv <<EOF
open $ftpIp
user $ftpUser $ftpPwd
cd $ftpLog
put $1 $2
bye
EOF
}

#----- update.txt deal with -----

# local update.txt
localUpdate="./update.txt"
# download update.txt
tmpUpdate="./tmp.txt"

# dev number
devId=14770000
if [ -e "./devnum.conf" ] ; then
    devId=`cat ./devnum.conf`
fi

# history order
order="20190601083000"
if [ -e $localUpdate ] ; then
    tmp=`sed -n '$p' $localUpdate`
    if [ $tmp -gt $order ]; then
        order=$tmp
    fi
fi

# sort update.txt
# example: upgrade update.txt
# return: 0/invaild
#         1/refresh update.txt, do nothing
#         2/hit this device, download targetFile and upgrade ..
upgrade()
{
    if [ $# -gt 3 ] && [ $1 -gt $order ]; then

        order=$1




        return 2

    else

        return 0

    fi
}



#----- main loop -----

# detect period (sec)
period=60

while : ; do

    localTime=`date +%Y%m%d%H%M%S`

    # 
    echo $localTime
    echo $devId
    echo $localDate

    sleep $period
done
