#!/bin/sh

#----- ftp config -----

# ftp ip & port
ftpUrl="192.168.1.2"
ftpUrlBakup="www.xxxooo.com"
ftpPort="9999"
# ftp user & pwd
ftpUser="usr"
ftpPwd="123abc"
# ftp log path
ftpLog="log"

# [ ftp server folder structure ]
# root path ............... read only
# |-update.txt ............ read only
# |-cmd_file .............. read only
# |-pkg_file .............. read only
# |-... ................... read only
# |-.. .................... read only
# |-. ..................... read only
# |-log ................... read/append
# |  |-xxxx1.log .......... read/append
# |  |-xxxx2.log .......... read/append
# |  |-... ................ read/append
# |  |-.. ................. read/append
# |  |-. .................. read/append

#----- shell path -----

rootPath="/root"
tmpPath="/tmp"
pkgPath="/mnt/update"

# wget path
wget="wget"
# wput path
wput="wput"
# md5sum path
md5sum="md5sum"

#----- ftp download/upload -----

# download $srcPath $distPath
# example: download "update.txt" $rootPath"/update.txt"
download()
{
    # -t [retry] -T [timeout] -q [quit]
    $wget -t 2 -T 10 ftp://$ftpUser:$ftpPwd@$ftpUrl:$ftpPort/$1 -O $2 -o $tmpPath/wget.log
    if cat $tmpPath/wget.log | grep '100%' > /dev/null
    then
        rm $tmpPath/wget.log
    else
        echo "wget backup ip $ftpUrlBakup"
        $wget -t 2 -T 10 -q ftp://$ftpUser:$ftpPwd@$ftpUrlBakup:$ftpPort/$1 -O $2
    fi
}

# upload $srcPath $distPath
# example: upload $rootPath"/order.txt" "log/123.log"
upload()
{
    # -t [retry] -T [timeout] -q [quit]
    $wput -t 2 -T 10 $1 ftp://$ftpUser:$ftpPwd@$ftpUrl:$ftpPort/$2 -o $tmpPath/wput.log
    if cat $tmpPath/wput.log | grep 'Transfered' > /dev/null
    then
        rm $tmpPath/wput.log
    else
        echo "wput backup ip $ftpUrlBakup"
        $wput -t 2 -T 10 -q $1 ftp://$ftpUser:$ftpPwd@$ftpUrlBakup:$ftpPort/$2
    fi
}

#----- deal with update.txt -----

# local order
localOrder=$rootPath"/ftp_upgrade_order.conf"
# download update.txt
localUpdate=$tmpPath"/ftp_upgrade_update.txt"
# devnum.conf
devnum=$rootPath"/ftp_upgrade_devnum.conf"

# target type: "cmd" or "pkg"
targetType="cmd"
# target file
targetFile=""
# target file md5
targetFileMd5=""
# target hit flag
#   0/invaild
#   1/refresh local order, do nothing
#   2/hit this device, download targetFile and upgrade ..
targetHit=0

# dev number
devId=12345678
if [ -e $devnum ]; then
    devId=`cat $devnum`
fi

# history order
order="20210326094143"
if [ -e $localOrder ]; then
    tmp=`cat $localOrder`
    if [ $tmp -gt $order ]; then
        order=$tmp
    fi
fi
echo $order > $localOrder

# check update.txt
# example: check_update `sed -n '$p' update.txt`
# return: 0/invaild
#         1/refresh local order, do nothing
#         2/hit this device, download targetFile and upgrade ..
check_update()
{
    # echo "< ftpUpgrade > [$*]"
    # order compare
    if [ $# -gt 3 ] && [ $1 -gt $order ]; then
        echo "< ftpUpgrade > order: $1 > $order"
        # invaild type ?
        if [ $2 == "cmd" ] || [ $2 == "pkg" ]; then
            order=$1
            targetType=$2
            targetFile=$3
            targetFileMd5=$4
            # load devId
            if [ -e $devnum ]; then
                devId=`cat $devnum`
            fi
            # device list ?
            if [ $# -gt 4 ]; then
                # look for devId
                for i in $* ; do
                    if [ $i == $devId ]; then
                        targetHit=2
                        return 2
                    fi
                done
                targetHit=1
                return 1
            else
                targetHit=2
                return 2
            fi
        else
            echo "< ftpUpgrade > type: unknow $2"
            targetHit=0
            return 0
        fi
    else
        echo "< ftpUpgrade > order: $1 <= $order"
        targetHit=0
        return 0
    fi
}

# update
# example: update
do_update()
{
    # targetHit > 1 ?
    if [ $targetHit -gt 0 ]; then

        localTime=`date +%Y%m%d%H%M%S`
        logFileName="$order-$devId-"

        # refresh order.conf
        echo "< ftpUpgrade > refresh order.conf [$order]"
        echo $order > $localOrder

        # targetHit == 2 ?
        if [ $targetHit -gt 1 ]; then

            # download file
            if [ $targetType == "pkg" ] && [ -e $pkgPath ]; then
                # download target
                echo "< ftpUpgrade > download target [$targetType $targetFile]"
                download "$targetFile" $pkgPath"/$targetFile"
                targetFile=$pkgPath"/$targetFile"
            elif [ $targetType == "cmd" ] && [ -e $tmpPath ]; then
                # download target
                echo "< ftpUpgrade > download target [$targetType $targetFile]"
                download "$targetFile" $tmpPath"/$targetFile"
                targetFile=$tmpPath"/$targetFile"
            fi

            # download success ?
            if [ -e $targetFile ]; then
                # md5 calculate
                tmpMd5=`$md5sum $targetFile`
                tmpMd5=${tmpMd5%\ *}
                # md5 compare
                echo "< ftpUpgrade > md5: $tmpMd5 -- $targetFileMd5"
                if [ $tmpMd5 == $targetFileMd5 ]; then
                    if [ $targetType == "cmd" ]; then
                        # result: cmd
                        logFileName=$logFileName"cmd.log" && echo "[$localTime]" > $tmpPath"/$logFileName"
                        # delete '\r'
                        dos2unix $targetFile
                        # enable for shell
                        chmod a+x $targetFile
                        # run cmd and get log
                        echo "< ftpUpgrade > cmd run now ..."
                        $targetFile >> $tmpPath"/$logFileName"
                    elif [ $targetType == "pkg" ]; then
                        # result: pkg
                        logFileName=$logFileName"pkg.log" && echo "[$localTime]" > $tmpPath"/$logFileName"
                        # upgrade
                        echo "< ftpUpgrade > upgrade now ..."
                        # upload result
                        upload "$tmpPath/$logFileName" "$ftpLog/$logFileName"
                        echo "< ftpUpgrade > upload: $logFileName done" && rm "$tmpPath/$logFileName"
                        # reboot and upgrade
                        reboot && sleep 30
                    else
                        # result-err: type
                        logFileName=$logFileName"err-type.log" && echo "[$localTime]" > $tmpPath"/$logFileName"
                        echo "< ftpUpgrade > err: unknow type $targetType"
                    fi
                else
                    # result-err: md5
                    logFileName=$logFileName"err-md5.log" && echo "[$localTime]" > $tmpPath"/$logFileName"
                    echo "< ftpUpgrade > err: md5"
                fi
            else
                # result-err: download
                logFileName=$logFileName"err-download.log" && echo "[$localTime]" > $tmpPath"/$logFileName"
                echo "< ftpUpgrade > err: download"
            fi
        else
            # result: ignore
            logFileName=$logFileName"ignore.log" && echo "[$localTime]" > $tmpPath"/$logFileName"
            echo "< ftpUpgrade > ignore"
        fi
        # clear targetFile
        rm $targetFile -rf
        # upload result
        upload "$tmpPath/$logFileName" "$ftpLog/$logFileName"
        echo "< ftpUpgrade > upload: $logFileName done" && rm "$tmpPath/$logFileName"
    fi
    # clear targetHit
    targetHit=0
}

#----- main loop -----

# detect period (sec)
delay1=15
delay2=45

while : ; do

    sleep $delay1

    # download update.txt
    download "update.txt" $localUpdate

    # check update.txt
    # set targetHit
    check_update `sed -n '$p' $localUpdate`

    # check targetHit and do update
    do_update

    sleep $delay2
done
