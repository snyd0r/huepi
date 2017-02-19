#!/bin/bash
set -x

# Variables
# Hue Executable
HUEBIN=/usr/bin/hue
# Hue Settings
DEVICES="10"
# DEVICES="2,10"
HUE="7676"
BRI="144"
SAT="199"
# Friends of Hue Settings (Iris, Bloom)
# They differ in ColorSettings
FOH_DEVICES="9"
# FOH_DEVICES="5,9"
FOH_HUE="12057"
FOH_BRI="144"
FOH_SAT="143"
# Transitiontime (Time for lights to come on slowly)
TRANSITTIME=5

# Section to define how to check presence of the phones
# iPhonemarker => BluetoothMac
IDENTIFIER_IPHONE7='70:70:0D:98:A6:9C'
PRESENCEFILE_IPHONE7="/tmp/presence_iphone7"
# S7-Marker => IP Address (Lease is two Weeks)
IDENTIFIER_S7EDGE='192.168.77.48'
# IDENTIFIER_S7EDGE='192.168.77.49'
PRESENCEFILE_S7EDGE="/tmp/presence_s7edge"

# Counters
# Turn off counter. Give the phones a chance to reconnect if there was just a Problem with bluetooth or network connection
TURN_OFF_COUNT=0
# Counter how long the phones have been seen
# Otherwise huepi won't know that if i turn the lights off at night, they shall stay off.
NO_AUTO_MODE=0

function main {
  while :
  do

    # Turn on lights ?
    IsIphoneAtHome=`sudo l2ping -s 1 -c 1 $IDENTIFIER_IPHONE7 >/dev/null 2>&1; echo $?` #Check if iPhone is reachable
    IsS7EdgeAtHome=`sudo ping -c 1 -W 3 $IDENTIFIER_S7EDGE >/dev/null 2>&1; echo $?` #Check if s7edge is reachable
    if [ "$IsIphoneAtHome" = 0 ]; then
      #iPhone7 visible via BT
      echo "-!- huepi: iPhone is visible" | logger
      writePresenceFile "iphone7"
    else
      removePresenceFile "iphone7"
    fi
    if [[ "$IsS7EdgeAtHome" = 0 ]]; then
      # s7Edge visible via ping
      echo "-!- huepi: edge7 is visible" | logger
      writePresenceFile "s7edge"
    else
      removePresenceFile "s7edge"
    fi
    showtime


  sleep 1s # raise to 15 or 30 in production
done
}

# Declare used functions

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
    1)  echo "-!- huepi: iPhone is here." | logger
    turnOnLight "arriving"
    ;;
    2)  echo "-!- huepi: s7edge is here" | logger
    turnOnLight "arriving"
    ;;
    3)  echo "-!- huepi: iPhone and s7edge are here" | logger
    echo "-!- huepi: We don't want to change activated light settings. Otherwise somebody may get mad ;)" | logger
    ;;
    0) echo "-!- huepi: No phones around" | logger
    echo "-!- huepi: Grace Time before turn off." | logger
    if [[ $TURN_OFF_COUNT = 3 ]]; then
      echo "-!- huepi: Turn off lights and reset grace counter" | logger
      turnOffLightsWhenLeaving
      TURN_OFF_COUNT=0
      # NO_AUTO_MODE=0 # Nobody home, so reset the counter
    fi
    ((TURN_OFF_COUNT+=1))
    ;;
  esac

}

function turnOnLight() {
  if [[ "$1" == "arriving" ]]; then
    #statements
    $HUEBIN transit $DEVICES $TRANSITTIME --hue $HUE --bri $BRI --sat $SAT --on # Turn on original Hue Lights (Bulbs, Strips)
    $HUEBIN transit $FOH_DEVICES $TRANSITTIME --hue $FOH_HUE --bri $FOH_BRI --sat $FOH_SAT --on # Turn on Friends of Hue lights (Iris, Bloom)
  fi
}

function turnOffLightsWhenLeaving {
  # If Phones are leaving, turn off the lights
  $HUEBIN transit $DEVICES,$FOH_DEVICES $TRANSITTIME --off
}

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
