#!/bin/sh
clear
echo "1. Embed a file"
echo "2. Extract the file"
read -p "> " USER_OPTION
if [ $USER_OPTION = "1" ]
then
	read -p "Enter the path of your cover image: " IMAGE_DIRECTORY
	read -p "Enter the path of the file you wish to hide: " FILE_DIRECTORY
	steghide embed -cf $IMAGE_DIRECTORY -ef $FILE_DIRECTORY
	sudo rm $FILE_DIRECTORY
elif [ $USER_OPTION = "2" ]
then
	read -p "Enter the path of the image you want use: " IMAGE_DIRECTORY
	steghide extract -sf $IMAGE_DIRECTORY
fi
