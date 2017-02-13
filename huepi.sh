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
IDENTIFIER_IPHONE7='70:70:0D:98:A6:9C'
PRESENCEFILE_IPHONE7="/tmp/presence_iphone7"
# S7-Marker => IP Address (Lease is two Weeks)
IDENTIFIER_S7EDGE='192.168.77.49'
PRESENCEFILE_S7EDGE="/tmp/presence_s7edge"

# Turn off counter. Give the phones a chance to reconnect if there was just a Problem with bluetooth or network
TURN_OFF_COUNT=0

function main {
  while :
  do
    IsIphoneAtHome=`sudo l2ping -s 1 -c 1 $IDENTIFIER_IPHONE7 >/dev/null 2>&1; echo $?` #Check if iPhone is reachable
    IsS7EdgeAtHome=`sudo ping -c 1 -W 3 $IDENTIFIER_S7EDGE >/dev/null 2>&1; echo $?` #Check if s7edge is reachable
    if [ "$IsIphoneAtHome" = 0 ]; then
      #iPhone7 visible via BT
      echo "huepi: iPhone is visible" | logger
      writePresenceFile "iphone7"
    fi
    if [[ "$IsS7EdgeAtHome" = 0 ]]; then
      # s7Edge visible via ping
      echo "huepi: edge7 is visible" | logger
      writePresenceFile "s7edge"
    fi
    # else #Phones not visible via BT or Ping
    #   echo "huepi: no is not at home" | logger
    #   turnOffLightsWhenLeaving
    # fi
    showtime
    sleep 5s # raise to 15 or 30 in production
  done
}

function showtime() {
  # Check for presence Files and determine what to do with the lights
  PHONECOUNT=0
  # We're determining what to do by quickly calculate the Values of the phones
  # iphone7  = 1
  # s7edge   = 2
  # no_phone = 0

  if [[ -f $PRESENCEFILE_IPHONE7 ]]; then
    ((PHONECOUNT+=1))
  fi

  if [[ -f $PRESENCEFILE_S7EDGE ]]; then
    ((PHONECOUNT+=2))
  fi

  case "$PHONECOUNT" in

    1)  echo "huepi: iPhone is here." | logger
    turnOnLight "arriving"
    ;;
    2)  echo "huepi: s7edge is here" | logger
    turnOnLight "arriving"
    ;;
    3)  echo "huepi: iPhone and s7edge are here" | logger
    echo "huepi: We don't want to change activated light settings. Otherwise somebody may get mad ;)" | logger
    ;;
    0) echo "huepi: No phones around" | logger
    echo "huepi: Grace Time before turn off." | logger
    if [[ $TURN_OFF_COUNT = 3 ]]; then
      echo "huepi: Turn off lights" | logger
      turnOffLightsWhenLeaving
    fi
    ((TURN_OFF_COUNT+=1))
    ;;
  esac

}

# Declare used functions
function turnOnLight() {
  if [[ "$1" == "arriving" ]]; then
    #statements
    $HUEBIN transit 2,10 5 --hue $HUE --bri $BRI --sat $SAT --on # Turn on original Hue Lights (Bulbs, Strips)
    $HUEBIN transit 5,9 5 --hue $FOHUE --bri $FOBRI --sat $FOSAT --on # Turn on Friends of Hue lights (Iris, Bloom)
  fi
}

function turnOffLightsWhenLeaving {
  # If Phones are leaving, turn off the lights
  $HUEBIN transit all 5 --off
}

# function checkIfLightsAreOn {
#   # Check if any of the lights in "Wohnzimmer" are activated.
#   IsThereLight=`hue get 2,3,5,9,10 | grep -i '"on":true' >/dev/null 2>&1; echo $?`
#   if [[ "$IsThereLight" = 0 ]]; then # 0 = There is light, 1 = there is no light
#   # Lights are allready on
#   echo "huepi: Lights are on"
# else
#   # Turn on lights
#   turnOnLightWhenArriving
# fi
#}

function writePresenceFile() {
  if [[  $1 == "iphone7" ]]; then
    touch $PRESENCEFILE_IPHONE7
  elif [[  $1 == "s7edge" ]]; then
    touch $PRESENCEFILE_S7EDGE
  fi
}

function removePresenceFile() {
  if [[  $1 == "iphone7" ]]; then
    rm $PRESENCEFILE_IPHONE7
  elif [[  $1 == "s7edge" ]]; then
    rm $PRESENCEFILE_S7EDGE
  fi
}

# TODO Check if it is dark and if lights are needed
# Maybe with some calculation and sunset- / sundown-times.

# Run this script
main
