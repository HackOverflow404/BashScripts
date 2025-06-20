#!/bin/sh
echo "Killing processes that could cause trouble"
echo ""
echo ""
sudo airmon-ng check kill
echo ""
echo ""
echo ""
echo ""
echo "Starting Monitor Mode"
echo ""
echo ""
sudo iwconfig
read -p "Enter the interface name you would like to switch to managed mode: " INTERFACE
sudo airmon-ng start $INTERFACE
echo ""
echo ""
echo ""
echo ""
echo $INTERFACE " is now in monitor mode"
echo ""
echo ""
sudo iwconfig
