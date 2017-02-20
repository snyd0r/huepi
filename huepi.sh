#!/bin/bash
set -x

# Variables
PHONES=0
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
IDENTIFIER_S7EDGE='192.168.77.49'
PRESENCEFILE_S7EDGE="/tmp/presence_s7edge"

# Counters
# Enable or disable automatic mode
AUTO_MODE=1 # 1 = on, 0 = off

function main {
  while true
  do
    # Check if any of the lights in "Wohnzimmer" are activated.
    IsThereLight=`hue get 9,10 | grep -i '"on":true' >/dev/null 2>&1; echo $?`
    # IsThereLight=`hue get 2,3,5,9,10 | grep -i '"on":true' >/dev/null 2>&1; echo $?`
    if [[ "$IsThereLight" = 0 ]]; then # 0 = There is light, 1 = there is no light
    # Lights are allready on
    echo "-!- huepi: Lights are on - waiting for phones to leave." | logger
    while true ; do
      checkForPhones
      [ "$?" -eq 0 ] && AUTO_MODE=1 && break # If return Value = 0 set to Automatic Mode and break the while.
      sleep 5s # turn this up in production
    done
  else
    echo "-!- huepi: No lights on. Check what to do."
    # Something has to happen here - but i can't concentrate O_O
  fi
  # Check if phones are connected
  checkForPhones
  checkForPhonesResult=$?
  showtime $checkForPhonesResult
done
}

# Declare used functions

function checkForPhones() {
  PHONECOUNT=0
  # Turn on lights ?
  IsIphoneAtHome=`sudo l2ping -s 1 -c 1 $IDENTIFIER_IPHONE7 >/dev/null 2>&1; echo $?` #Check if iPhone is reachable
  IsS7EdgeAtHome=`sudo ping -c 1 -W 3 $IDENTIFIER_S7EDGE >/dev/null 2>&1; echo $?` #Check if s7edge is reachable
  if [ "$IsIphoneAtHome" = 0 ]; then
    #iPhone7 visible via BT
    echo "-!- huepi: iPhone is visible" | logger
    writePresenceFile "iphone7"
    ((PHONECOUNT+=1))
  else
    removePresenceFile "iphone7"
  fi
  if [[ "$IsS7EdgeAtHome" = 0 ]]; then
    # s7Edge visible via ping
    echo "-!- huepi: edge7 is visible" | logger
    writePresenceFile "s7edge"
    ((PHONECOUNT+=2))
  else
    removePresenceFile "s7edge"
  fi
  return $PHONECOUNT
}

function showtime() {
  # INDEX = PHONECOUNT
  INDEX=$1
  case "$INDEX" in
    1)  echo "-!- huepi: iPhone is here." | logger
    turnOnLight "arriving"
    AUTO_MODE = 0
    ;;
    2)  echo "-!- huepi: s7edge is here" | logger
    turnOnLight "arriving"
    AUTO_MODE = 0
    ;;
    3)  echo "-!- huepi: iPhone and s7edge are here" | logger
    echo "-!- huepi: We don't want to change activated light settings. Otherwise somebody may get mad ;)" | logger
    AUTO_MODE = 0
    ;;
    0) echo "-!- huepi: No phones around" | logger
    echo "-!- huepi: Grace Time before turn off." | logger
    echo "-!- huepi: Turn off lights 'cause nobody is home.'" | logger
    turnOffLightsWhenLeaving
    AUTO_MODE = 1
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
