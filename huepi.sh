#!/bin/bash
set -x

# Variables
#Hue Executable
HUEBIN=/usr/bin/hue
# Hue Settings
HUE="7676"
BRI="144"
SAT="199"
#Friends of Hue Settings (Iris, Bloom)
FOHUE="12057"
FOBRI="144"
FOSAT="143"

# Section to define how to check presence of the phones
# iPhonemarker => BluetoothMac
IPHONE7BTMAC='70:70:0D:98:A6:9C'
PRESENCEFILEIPHONE7="/tmp/presenceiphone7"
# S7-Marker => IP Address (Lease is two Weeks)
S7IP='192.168.77.49'

function main {
while :
do
  IsMyiPhoneAtHome=`sudo l2ping -s 1 -c 1 $IPHONE7BTMAC >/dev/null 2>&1; echo $?` #Check if iPhone is reachable
  if [ "$IsMyiPhoneAtHome" = 0 ];
  then #Phone visible via BT
  echo "iPhone is visible"
  turnOnLightWhenArriving
else #Phone not visible via BT
  echo "iPhone is not at home"
  turnOffLightsWhenLeaving
fi
sleep 5s
done
}

# Declare used functions
function turnOnLightWhenArriving {
  $HUEBIN transit 2,10 5 --hue $HUE --bri $BRI --sat $SAT --on # Turn on original Hue Lights (Bulbs, Strips)
  $HUEBIN transit 5,9 5 --hue $FOHUE --bri $FOBRI --sat $FOSAT --on # Turn on Friends of Hue lights (Iris, Bloom)
}

function turnOffLightsWhenLeaving {
  # If Phones are leaving, turn off the lights
  sleep 60 # Maybe the phones are not away? Maybe they reconnect?
  # hue transit all 5 --off
  $HUEBIN transit 10 5 --off
}

function checkIfLightsAreOn {
  # Check if any of the lights in "Wohnzimmer" are activated.
  IsThereLight=`hue get 2,3,5,9,10 | grep -i '"on":true' >/dev/null 2>&1; echo $?`
  if [[ "$IsThereLight" = 0 ]]; then # 0 = There is light, 1 = there is no light
  # Lights are allready on
  echo "Lights are on"
else
  # Turn on lights
  turnOnLightWhenArriving
fi
}

# function writePresenceFile

# function isSomebodyhere

# TODO Check if it is dark and if lights are needed
# Maybe with some calculation and sunset- / sundown-times.

# Run this script
main
