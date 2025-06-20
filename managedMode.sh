#!/bin/sh
echo "Stopping Monitor Mode"
echo ""
echo ""
sudo iwconfig
read -p "Enter the interface name you would like to switch to managed mode: " INTERFACE
sudo airmon-ng stop $INTERFACE
echo ""
echo ""
echo ""
echo ""
echo "Starting Network Manager"
echo ""
echo ""
sudo service NetworkManager restart
echo ""
echo ""
echo ""
echo ""
echo $INTERFACE" is now in managed mode"
echo ""
echo ""
sudo iwconfig
