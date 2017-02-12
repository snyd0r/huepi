#!/bin/bash
set -x

# Variables
# Hue Settings
HUE=""
BRI=""
SAT=""
#Friends of Hue Settings (Iris, Bloom)
FOHUE=""
FOBRI=""
FOSAT=""

# Section to define how to check presence of the phones
# iPhonemarker => BluetoothMac
IPHONE7BTMAC='70:70:0D:98:A6:9C'
# S7-Marker => IP Address (Lease is two Weeks)
S7IP='192.168.77.49'

while :
    do
        IsMyiPhoneAtHome=`sudo l2ping -s 1 -c 1 $IPHONE7BTMAC >/dev/null 2>&1; echo $?` #Pruefung, ob das Phone erreichbar ist
        if [ "$IsMyiPhoneAtHome" = 0 ];
            then #Phone visible via BT
               	echo "iPhone is visible"
                hue set 10 --on
            else #Phone not visible via BT
                echo "iPhone is not at home"
                hue set 10 --off
        fi
        sleep 5s
   done

# function turnOnLightWhenArriving
# hue transit 2,5,9,10 5 --hue 7688 --bri 144 --sat 199 --on

# function isLightAllreadyOn

# function writePresenceFile

# function isSomebodyhere
