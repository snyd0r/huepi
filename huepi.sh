#!/bin/bash
# set -x

# Variables
# PHONES=0
LIGHTS=0 # 0 = off, 1= on
# Hue Executable
HUEBIN=/usr/bin/hue
# Hue Settings
# DEVICES="10"
DEVICES="2,10"
HUE="7676"
BRI="144"
SAT="199"
# Friends of Hue Settings (Iris, Bloom)
# They differ in ColorSettings
# FOH_DEVICES="9"
FOH_DEVICES="5,9"
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
IDENTIFIER_S7EDGE='192.168.77.49'
PRESENCEFILE_S7EDGE="/tmp/presence_s7edge"

# Echocounter
# Don't repeat the echoes that iphone or s7edge are there
EC_IPHONE=0
EC_S7EDGE=0

# Counters
TURN_OFF_COUNT=0 # After sending the OFF Signal for 3 times it's enough.

function main {
  while true
  do
    # Check if any of the lights in "Wohnzimmer" are activated.
    #IsThereLight=`hue get 9,10 | grep -i '"on":true' >/dev/null 2>&1; echo $?` <- DEBUG
    # IsThereLight=`hue get 2,5,9,10 | grep -i '"on":true' >/dev/null 2>&1; echo $?`
    IsThereLight=`hue get 2,3,5,9,10 | grep -i '"on":true' >/dev/null 2>&1; echo $?`
    if [[ "$IsThereLight" = 0 ]]; then # 0 = There is light, 1 = there is no light
    # Lights are allready on
    LIGHTS=1
    echo "-!- huepi: Lights are on - waiting for phones to leave." | logger
    while true ; do
      checkForPhones
      [ "$?" -eq 0 ] && break # If return Value = 0 break out of the while loop.
      sleep 5s # turn this up in production
    done
  else
    echo "-!- huepi: No lights on. Waiting for phones." | logger
    LIGHTS=0
    while true ; do
      checkForPhones
      [ "$?" -gt 0 ] && break # If return Value = 0 break out of the while loop.
      sleep 5s # turn this up in production
    done
  fi
  # Check if phones are connected
  checkForPhones
  checkForPhonesResult=$?
  showtime $checkForPhonesResult
done
}

# Declare used functions

function checkForPhones() {
  DEVICECOUNT=0
  # Turn on lights ?
  IsIphoneAtHome=`sudo l2ping -s 1 -c 1 $IDENTIFIER_IPHONE7 >/dev/null 2>&1; echo $?` #Check if iPhone is reachable
  IsS7EdgeAtHome=`sudo ping -c 1 -W 3 $IDENTIFIER_S7EDGE >/dev/null 2>&1; echo $?` #Check if s7edge is reachable
  if [ "$IsIphoneAtHome" = 0 ]; then
    #iPhone7 visible via BT
    if [[ "$EC_IPHONE" -eq 0 ]]; then
      echo "-!- huepi: iPhone is visible" | logger
    fi
    writePresenceFile "iphone7"
    ((DEVICECOUNT+=1))
    EC_IPHONE=1
  else
    if [[ "$EC_IPHONE" -gt 0 ]]; then
      echo "-!- huepi: iPhone has left" | logger
    fi
    removePresenceFile "iphone7"
    EC_IPHONE=0
  fi
  if [[ "$IsS7EdgeAtHome" = 0 ]]; then
    # s7Edge visible via ping
    if [[ "$EC_S7EDGE" -eq 0 ]]; then
      echo "-!- huepi: edge7 is visible" | logger
    fi
    writePresenceFile "s7edge"
    ((DEVICECOUNT+=2))
    EC_S7EDGE=1
  else
    if [[ "$EC_S7EDGE" -gt 0 ]]; then
      echo "-!- huepi: edge7 has left" | logger
    fi
    removePresenceFile "s7edge"
    EC_S7EDGE=0
  fi
  return $DEVICECOUNT
}

function showtime() {
  # INDEX = DEVICECOUNT
  INDEX=$1
  case "$INDEX" in
    1)  echo "-!- huepi: iPhone is here. Turn the lights on." | logger
    turnOnLight "arriving"
    AUTO_MODE=0
    TURN_OFF_COUNT=0
    ;;
    2)  echo "-!- huepi: s7edge is here. Turn the lights on." | logger
    turnOnLight "arriving"
    AUTO_MODE=0
    TURN_OFF_COUNT=0
    ;;
    3)  echo "-!- huepi: iPhone and s7edge are here" | logger
    # If boths phones arrive at the same time, light would be useful. Especially at night. ;)
    if [[ "$LIGHTS" -eq 0 ]]; then
      turnOnLight "arriving"
      AUTO_MODE=0
      TURN_OFF_COUNT=0
    fi
    echo "-!- huepi: We don't want to change activated light settings. Otherwise somebody may get mad ;)" | logger
    AUTO_MODE=0
    ;;
    0) echo "-!- huepi: No phones around" | logger
    echo "-!- huepi: Turn off lights because nobody is home." | logger
    if [[ "$TURN_OFF_COUNT" -le 2 ]]; then
      turnOffLightsWhenLeaving
      ((TURN_OFF_COUNT+=1))
      AUTO_MODE=1
    fi
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
  $HUEBIN transit all $TRANSITTIME --off
  # $HUEBIN transit $DEVICES,$FOH_DEVICES $TRANSITTIME --off
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
    if [[ -f $PRESENCEFILE_IPHONE7 ]] ; then
      rm $PRESENCEFILE_IPHONE7
    fi

  elif [[  $1 == "s7edge" ]]; then
    if [[ -f $PRESENCEFILE_S7EDGE ]] ; then
      rm $PRESENCEFILE_S7EDGE
    fi

  fi
}

# TODO Check if it is dark and if lights are needed
# Maybe with some calculation and sunset- / sundown-times.

# Run this script
main
