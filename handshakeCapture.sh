#!/bin/sh
sudo echo "Assuming you are in monitor mode"
sleep 5
iwconfig | cut -d ' ' -f 1 | grep "\S" > networkInterfaces.txt; clear; cat networkInterfaces.txt; rm networkInterfaces.txt
read -p "Enter the interface name you would like to use to monitor networks: " INTERFACE
sudo airodump-ng $INTERFACE
read -p "Enter the BSSID of your target: " BSSID
read -p "Enter the Channel of your target: " CHANNEL
sudo mkdir hashfiles
sudo airodump-ng -c $CHANNEL --bssid $BSSID -w hashfiles/hashfile $INTERFACE
