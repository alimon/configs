#!/bin/bash
#===============================================================================
#
#          FILE: update_default_boot.sh
#
#         USAGE: ./update_default_boot.sh [TYPE]
#         [TYPE]: kernel, uboot, optee, netboot
#
#        AUTHOR: Christophe Priouzeau
#  ORGANIZATION: STMicroelectronics
#     COPYRIGHT: Copyright (C) 2016, STMicroelectronics - All Rights Reserved
#       CREATED: 08/23/2016 11:53
#===============================================================================
_DEFAULT_BOOTSCRIPT=u-bootrom.script
_DEFAULT_TYPE=kernel

_TYPE=

usage() {
    echo "Usage:"
    echo "  $1 <type>"
    echo "  type: type of boot can be \"kernel\", \"uboot\" or \"optee\" or \"netboot\""
    echo ""
}
parse_argument() {
    case $1 in
    kernel)
        _TYPE=kernel
        ;;
    uboot)
        _TYPE=uboot
        ;;
    optee)
        _TYPE=optee_uboot
        ;;
    netboot)
        _TYPE=netboot
        ;;
    esac
}

ask_tftp_ip_address() {
    IP_ETH0=`ifconfig eth0 | awk '/inet addr/{print substr($2,6)}'`
    echo "Please enter the IP address of your TFTP server [$IP_ETH0]: "
    read _ip

    if [ -z "$_ip" ];
    then
        #use ip address of eth0
        IP_ADDRESS=$IP_ETH0
    else
        echo "Would you like to use this IP address '$_ip' ? [Y/n] "
        read answer
        if [ -z "$answer" ]
        then
            # yes selected
            IP_ADDRESS=$_ip
        elif (echo -n $answer | grep -q -e "^[yY][a-zA-Z]*$")
        then
            # yes selected
            IP_ADDRESS=$_ip
        else
            echo "[EXIT] you don't validate the ip address entered."
            echo ""
            exit 1
        fi
    fi
}
# -----------------------------------
# Parse option

case $# in
0)
    parse_argument kernel
    ;;
1)
    case $1 in
    -h|--help)
        usage $1
        exit 1
        ;;
    kernel|uboot|optee|netboot)
        parse_argument $1
        shift
        ;;
    *)
        usage $1
        exit 1
        ;;
    esac

    ;;
*)
    #error
    usage $1
    exit 1
    ;;
esac

if [ -z $_TYPE ];
then
    echo "FORCE type of boot to : $_DEFAULT_TYPE"
    _TYPE=$_DEFAULT_TYPE
fi

echo ""
echo " Type of boot:            $_TYPE"
echo ""

if [ "$_TYPE" == "netboot" ];
then
    ask_tftp_ip_address
    echo "IP ADDRESS $IP_ADDRESS"
fi

# generate script of mkimage
#for f in `find . -name *.script -print`;
#do
#    filename="$f"
#    mkimage -A arm -T script -C none -n "Open SDK Boot Script" -d $f ${filename%.*}.scr > /dev/null
#done

for d in `find . -maxdepth 1 -type d | grep "./" | sort`;
do
    BOOTSCRIPT_ROOT=`basename $d`
    if [ -f $d/$_DEFAULT_BOOTSCRIPT ];
    then
        # apply default configuration
        if [ -f $d/$_DEFAULT_BOOTSCRIPT-$_TYPE ];
        then
            echo "INFO: update $BOOTSCRIPT_ROOT/$_DEFAULT_BOOTSCRIPT script"
            sed -i 's#\(script_path=\".*/'"$_DEFAULT_BOOTSCRIPT"'\).*$#\1-$_TYPE\"#g' $d/$_DEFAULT_BOOTSCRIPT
            if [ "$_TYPE" == "netboot" ];
            then
                if [ -f $d/$_DEFAULT_BOOTSCRIPT-$_TYPE ];
                then
                    sed -i 's#setenv serverip '\(.*\)'#setenv serverip '$IP_ADDRESS'#g' $d/$_DEFAULT_BOOTSCRIPT-$_TYPE
                fi
            fi
        else
            echo "ERROR: missing '$_DEFAULT_BOOTSCRIPT-$_TYPE' in $BOOTSCRIPT_ROOT folder."
            echo "ERROR: skip update in $BOOTSCRIPT_ROOT/$_DEFAULT_BOOTSCRIPT script"
        fi
    else
        echo "ERROR: missing '$_DEFAULT_BOOTSCRIPT' in $BOOTSCRIPT_ROOT folder"
        echo "ERROR: cannot update default boot for $BOOTSCRIPT_ROOT folder"
    fi
done
