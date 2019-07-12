#!/bin/sh
# YaLAI downloader script
# Version 1.1
# Written by minigyima
# Copyright 2019

title="YaLAI Downloader"
wellcome_text="Welcome to YaLAI (Yet another Live Arch Installer)! \nPlease ensure that you have an active connection to de internet, since it is mandatory for downloading this installer and also for the installation of Arch Linux. If you need to connect to a wifi network, you may click the NetworkManager icon in the top left corner of the panel. However, if you are using a wireless connection, NetworkManager should automatically detect that, and configure it for you.\nOnce you are connected to the internet, click the 'Yes' button on this dialogbox to proceed. If you would like to exit the installer, press the 'No' button instead.\nAlso you can use this live installer as a rescue cd, by opening a terminal from the system tools menu."

# Displaying welcome message
welcome_box () { 

zenity --question --width=450 --height=300 --title="$title" --text "$wellcome_text"

if [ "$?" = "1" ]
	then exit
fi
}
ping_google() {

	if [[ ! $(ping -c 1 google.com) ]]; then
     	zenity --info --title="$title" --text "The internet connection was not detected, please try again."
     	welcome_box
	fi
}
# Downloading installer...
download() {
  git clone https://github.com/minigyima/yalai.git
  cd yalai
  chmod +x yalai.sh
}

# execute the installer, then provide choices
installer() {
	bash yalai.sh
	
	choice=$(zenity --list --title="YaLAI - Installation finished!" --radiolist --text "YaLAI has finished installing Arch Linux on your system. What would you like to do now?"  --column "Select" --column "Option" FALSE Restart FALSE Close FALSE "Chroot into new system" FALSE "Open pacman.conf")
		if [ "$choice" = "Restart" ]
		then reboot
		elif [ "$choice" = "Chroot into new system" ]
		then sudo mount $(cat root_part.txt) /mnt
		mate-terminal -e sudo arch-chroot /mnt
		umount -R /mnt
		elif [ "$choice" = "Open pacman.conf" ]
		then sudo mount $(cat root_part.txt) /mnt
		mate-terminal -e sudo nano /mnt/etc/pacman.conf     
		else exit
		fi
}


welcome_box
ping_google
download
installer
