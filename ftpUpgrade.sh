#!/bin/sh

localPath=`pwd`
targetFileDownloadPath=$localPath

#----- shell path -----

# wget path
wget="wget"
# wput path
wput="wput"
# md5sum path
md5sum="md5sum"

#----- ftp download/upload -----

# ftp ip & port
ftpIp="**********"
ftpPort="****"
# ftp user
ftpUser="***"
# ftp passwd
ftpPwd="******"

# ftp root path
ftpPath="m20-debug"
# ftp log path
ftpLog=$ftpPath"/log"
# ftp res path
ftpRes=$ftpPath"/res"

# download $srcPath $distPath
# default remote folder /m20
# example: download "m20-debug/update.txt" $localPath"/update.txt"
download()
{
    cmd="$wget --ftp-user=$ftpUser --ftp-password=$ftpPwd ftp://$ftpIp:$ftpPort/$1 -O $2 -t 3 -T 3 -q"
    # echo $cmd
    $cmd
}

# upload $srcPath $distPath
# default remote folder /m20/log
# example: upload $localPath"/order.txt" "m20-debug/log/123.log"
upload()
{
    cmd="$wput -B $1 ftp://$ftpUser:$ftpPwd@$ftpIp:$ftpPort/$2 -q"
    # echo $cmd
    $cmd
}

#----- update.txt deal with -----

# local order
localOrder=$localPath"/order.conf"
# download update.txt
localUpdate=$localPath"/update.txt"
# devnum.conf
devnum=$localPath"/devnum.conf"

# target type: "cmd" or "pkg"
targetType="cmd"
# target file
targetFile=""
# target file md5
targetFileMd5=""
# target hit flag
#         0/invaild
#         1/refresh local order, do nothing
#         2/hit this device, download targetFile and upgrade ..
targetHit=0

# dev number
devId=14770000
if [ -e $devnum ]; then
    devId=`cat $devnum`
fi

# history order
order="20190601083000"
if [ -e $localOrder ]; then
    tmp=`cat $localOrder`
    if [ $tmp -gt $order ]; then
        order=$tmp
    fi
fi
echo $order > $localOrder

# check update.txt
# example: upgrade `sed -n '$p' update.txt`
# return: 0/invaild
#         1/refresh local order, do nothing
#         2/hit this device, download targetFile and upgrade ..
upgrade()
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
            # look for devId
            if [ $# -gt 4 ]; then
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

# upgrade action
# example: upgrade_action
upgrade_action()
{
    if [ $targetHit -gt 0 ]; then

        localTime=`date +%Y%m%d%H%M%S`
        logFileName="$order-$devId-"

        # refresh order.conf
        echo "< ftpUpgrade > refresh order.conf [$order]"
        echo $order > $localOrder

        if [ $targetHit -gt 1 ]; then

            # download target
            echo "< ftpUpgrade > download target [$targetType $targetFile]"
            download "$ftpRes/$targetFile" $targetFileDownloadPath"/$targetFile"
            targetFile=$targetFileDownloadPath"/$targetFile"

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
                        logFileName=$logFileName"cmd.log" && echo "[$localTime]" > $localPath"/$logFileName"
                        # run cmd
                        echo "< ftpUpgrade > cmd run now ..."
                        chmod a+x $targetFile
                        $targetFile >> $localPath"/$logFileName"
                    elif [ $targetType == "pkg" ]; then
                        # result: pkg
                        logFileName=$logFileName"pkg.log" && echo "[$localTime]" > $localPath"/$logFileName"
                        # upgrade
                        echo "< ftpUpgrade > depackage now ..."
                    else
                        # result-err: type
                        logFileName=$logFileName"err-type.log" && echo "[$localTime]" > $localPath"/$logFileName"
                        echo "< ftpUpgrade > err: unknow type $targetType"
                    fi
                else
                    # result-err: md5
                    logFileName=$logFileName"err-md5.log" && echo "[$localTime]" > $localPath"/$logFileName"
                    echo "< ftpUpgrade > err: md5"
                fi
            else
                # result-err: download
                logFileName=$logFileName"err-download.log" && echo "[$localTime]" > $localPath"/$logFileName"
                echo "< ftpUpgrade > err: download"
            fi
        else
            # result: ignore
            logFileName=$logFileName"ignore.log" && echo "[$localTime]" > $localPath"/$logFileName"
            echo "< ftpUpgrade > ignore"
        fi
        # upload result
        if [ -e $logFileName ]; then
            upload "$localPath/$logFileName" "$ftpLog/$logFileName"
            echo "< ftpUpgrade > upload: $logFileName done"
        fi
    fi
    # clear targetHit
    targetHit=0
}

#----- main loop -----

# detect period (sec)
period=10

while : ; do

    # download update.txt
    download "$ftpPath/update.txt" $localUpdate

    # check update.txt
    upgrade `sed -n '$p' $localUpdate`

    # upgrade
    upgrade_action

    # test
    # download "m20-debug/update.txt" $localPath"/update.txt"
    # upload $localPath"/order.conf" "m20-debug/log/123.log"

    sleep $period
done
