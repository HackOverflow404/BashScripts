#!/bin/sh
echo "Stopping Monitor Mode"
echo "\n\n"
sudo iwconfig
read -p "Enter the interface name you would like to switch to managed mode: " INTERFACE
sudo airmon-ng stop $INTERFACE
echo "\n\n\n\nStarting Network Manager\n\n"
sudo service NetworkManager restart
echo -e "\n\n\n\n ${INTERFACE} is now in managed mode\n\n"
sudo iwconfig
