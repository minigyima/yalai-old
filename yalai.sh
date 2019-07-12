# YaLAI installer
# Version 1.1
# Written by minigyima
# Copyright 2019

# Determinig system type (UEFI or BIOS)
if [[ -d "/sys/firmware/efi/" ]]; then
      SYSTEM="UEFI"
      else
      SYSTEM="BIOS"
fi
welcome_text="Welcome to YaLAI (Yet another Live Arch Installer)! \nNext you will be prompted with a set of questions, that will guide you through installing Arch Linux.\nClick 'Yes' to begin, and 'No' to exit."
title="YaLAI installer (Version 1.0, running in $SYSTEM mode.) "
arch_chroot() {
    arch-chroot /mnt /bin/bash -c "${1}"
}
welcome_box() {
zenity --question --height=300 --width=450 --title="$title" --text "$welcome_text"
if [ "$?" = "1" ]
	then exit
fi
}
# Partitioning
partition() {
# Listing drives
    list=` lsblk -lno NAME,TYPE,SIZE,MOUNTPOINT | grep "disk" `
    zenity --info --height=300 width=450 --title="$title" --text "Below is a list of the available drives on your system:\n\n$list" 
    lsblk -lno NAME,TYPE | grep 'disk' | awk '{print "/dev/" $1 " " $2}' | sort -u > devices.txt
    sed -i 's/\<disk\>//g' devices.txt
    devices=` awk '{print "FALSE " $0}' devices.txt `
    dev=$(zenity --list --radiolist --height=500 --width=450 --title="$title" --text "Please select the drive, that you want to use for installation. \nThis drive will be used as the GRUB MBR location if the installer is running in BIOS mode." --column Drive --column Info $devices)


# Allow user to partition using gparted
    zenity --question --height=500 --width=450 --title="$title" --text "Do you want to partition $dev?\nSelect 'Yes' to open gparted and partition\nthe disk or format partitions if neccesary.\nThe installer will not format the partitions after this,\nso if your partitions need to be formatted please select yes\nand use gparted to format them now."
    if [ "$?" = "0" ]
	    then gparted
    fi
# Root partition selector partition
    root_part=$(zenity --list --radiolist --height=300 --width=450 --title="$title" --text="Please choose a partition to use for the root partition\nWarning, this list shows all available partitions on all available drives.\nPlease choose with care." --column ' ' --column Partitions $(sudo fdisk -l | grep dev | grep -v Disk | awk '{print $1}' | awk '{ printf " FALSE ""\0"$0"\0" }'))
# Mounting root partition
    touch root_part.txt    
    echo $root_part >> root_part.txt
    mount $root_part /mnt
# Swap partition selector
    swap_part=$(zenity --list  --radiolist --height=300 --width=450 --title="$title" --text="Please choose a partition to use for the swap partition\nWarning, this list shows all available partitions on all available drives.\nPlease choose with care." --column ' ' --column 'Partitions' $(sudo fdisk -l | grep dev | grep -v Disk | awk '{print $1}' | awk '{ printf " FALSE ""\0"$0"\0" }'))
    mkswap $swap_part
    swapon $swap_part
# Boot partition selector (if UEFI)
    if [$SYSTEM = UEFI]; then
    efi_boot=$(zenity --list  --radiolist --height=300 --width=450 --title="$title" --text="Please choose a partition to use for the boot partition\nWarning, this list shows all available partitions on all available drives.\nPlease choose with care." --column ' ' --column 'Partitions' $(sudo fdisk -l | grep dev | grep -v Disk | awk '{print $1}' | awk '{ printf " FALSE ""\0"$0"\0" }'))
# Mounting boot partition (if UEFI)
    mkdir /mnt/boot/efi
    mount $efi_boot /boot/efi
    fi
}
config() {
# Setting up locales 
    locales=$(cat /etc/locale.gen | grep -v "#  " | sed 's/#//g' | sed 's/ UTF-8//g' | grep .UTF-8 | sort | awk '{ printf "FALSE ""\0"$0"\0" }')
    locale=$(zenity --list --radiolist --height=500 --width=450 --title="$title" --text "Please select your locale/language.\nThe default is American English 'en_US.UTF-8'." --column Select --column Locale TRUE en_US.UTF-8 $locales)
# Keyboard layout
    layout=$(zenity --list --radiolist --height=500 --width=450 --title="$title" --text="Please select your keyboard layout, usually a two letter country code" --column Select --column Layout $(localectl list-keymaps | awk '{ printf " FALSE ""\0"$0"\0" }'))
    setxkbmap $layout
    loadkeys $layout
# Timezone
    zones=$(cat /usr/share/zoneinfo/zone.tab | awk '{print $3}' | grep "/" | sed "s/\/.*//g" | sort -ud | sort | awk '{ printf " FALSE ""\0"$0"\0" }')
    zone=$(zenity --list --radiolist --height=500 --width=450 --title="$title" --text "Please select your zone." --column Select --column Zone $zones)
    subzones=$(cat /usr/share/zoneinfo/zone.tab | awk '{print $3}' | grep "$zone/" | sed "s/$zone\///g" | sort -ud | sort | awk '{ printf " FALSE ""\0"$0"\0" }')
    subzone=$(zenity --list --radiolist --height=500 --width=450 --title="$title" --text "Please select your sub-zone." --column Select --column Zone $subzones)
# Hostname
    hostname=$(zenity --entry --title="$title" --text "Please enter a hostname for your system.\nIt must be in all lowercase letters." --entry-text "hostname")
# Username
    username=$(zenity --entry --title="$title" --text "Please enter a username for your user. Again, all lowercase." --entry-text "user")
}

root_password() {
# Setting root password
    rtpasswd=$(zenity --entry --title="$title" --text "Please enter a root password." --hide-text)
    rtpasswd2=$(zenity --entry --title="$title" --text "Please re-enter your root password." --hide-text)
        if [ "$rtpasswd" != "$rtpasswd2" ]
            then zenity --error --height=500 --width=450 --title="$title" --text "The passwords did not match, please try again."
            root_password
        fi
}
changeshell() {
# Choosing a shell
    shell=$(zenity --list --radiolist --height=500 --width=450 --title="$title" --text "Which shell would you like to use?" --column Select --column Choice FALSE bash FALSE zsh FALSE fish)
}
user_password() {
# Setting user password
    userpasswd=$(zenity --entry --title="$title" --text "Please enter a password for $username." --hide-text)
    userpasswd2=$(zenity --entry --title="$title" --text "Please re-enter a password for $username." --hide-text)
        if [ "$userpasswd" != "$userpasswd2" ]
            then zenity --error --height=500 --width=450 --title="$title" --text "The passwords did not match, please try again."
            user_password
        fi
}
desktop() {
# Choosing Desktop
    desktop=$(zenity --list --height=500 --width=450 --title="$title" --radiolist --text "Which desktop would you like to install?" --column Select --column Desktop FALSE "Gnome" FALSE "KDE Plasma" FALSE "Mate" )
}
display_manager() {
# Choosing display manager
    dm=$(zenity --list --title="$title" --radiolist  --height=500 --width=450 --text "Which display manager would you like to use?" --column "Select" --column "Display Manager" FALSE "lightdm" FALSE "sddm" FALSE "gdm")
}
# GRUB 2 install (gets called later...)
bootloader() {
    case $SYSTEM in
        'UEFI')
           
			echo "# Installing GRUB for UEFI..."
            arch_chroot "pacman -S grub efibootmgr --noconfirm"
			arch_chroot "grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB"
			arch_chroot "grub-mkconfig -o /boot/grub/grub.cfg"
			;;
			

        'BIOS') 
			echo "# Installing GRUB for BIOS..."
			sleep 1
            arch_chroot "pacman -S grub --noconfirm"
			arch_chroot "grub-install --target=i386-pc "
			arch_chroot "grub-mkconfig -o /boot/grub/grub.cfg $(cat /installtemp/dev.txt)"
            ;;
			esac


}
install() {
    # Base, base-devel
    echo "# Installing base system via pacstrap..."
    pacstrap -i /mnt base base-devel --noconfirm
    # Genfstab
    echo "# Generating fstab via genfstab..."
    genfstab -U /mnt >> /mnt/etc/fstab
    # /etc/hosts
    echo "# Configuring hosts file..."
    arch_chroot "echo "$hostname" >> /etc/hostname"
    arch_chroot "echo "127.0.0.1		localhost" >> /etc/hosts"
    arch_chroot "echo "::1			localhost" >> /etc/hosts"
    # mkinitcpio
    echo "# Preparing kernel..."
    arch_chroot "mkinitcpio -p linux"
    # Root password
    echo "# Setting root password..."
    touch .passwd
    echo -e "$rtpasswd\n$rtpasswd2" > .passwd
    arch_chroot "passwd root" < .passwd >/dev/null
    rm .passwd
    # User
    echo "# Making new user..."
    arch_chroot "useradd -m -g users -G adm,lp,wheel,power,audio,video -s /bin/bash $username"
    touch .passwd
    echo -e "$userpasswd\n$userpasswd2" > .passwd
    arch_chroot "passwd $username" < .passwd >/dev/null
    rm .passwd    
    # Locale
    echo "# Setting locale..."
    echo "LANG=\"${locale}\"" > /mnt/etc/locale.conf
    echo "${locale} UTF-8" > /mnt/etc/locale.gen
    echo "# Generating Locale..."
    arch_chroot "locale-gen"
    export LANG=${locale}
    # Keyboard layout
    echo "# Setting keyboard layout for console..."
    echo KEYMAP=$layout >> /mnt/etc/vconsole.conf
    # Timezone
    echo "# Setting timezone..."
    arch_chroot "rm /etc/localtime"
    arch_chroot "ln -s /usr/share/zoneinfo/${zone}/${subzone} /etc/localtime"
    # Hardware clock
    echo "# Setting up hardware clock..."
    arch_chroot "hwclock --systohc"
    # Shell
    case $shell in
        'zsh')
           echo "# Setting up zsh..."
		   sleep 1
		   arch_chroot "pacman -S --noconfirm zsh zsh-syntax-highlighting zsh-completions grml-zsh-config;chsh -s /usr/bin/zsh $username"
		   ;;
			

        'bash') 
			echo "# Setting up Bash..."
			sleep 1
			arch_chroot "pacman -S --noconfirm bash;chsh -s /bin/bash $username"
            ;;
		
		
		'fish') 
			echo "# Setting up fish..."
			sleep 1
			arch_chroot "pacman -S --noconfirm fish;chsh -s /usr/bin/fish $username"
            ;;
			esac
    # Xorg
    echo "# Installing Xorg and Pulseaudio..."
    pacstrap /mnt xorg-server xorg-xinit mesa xf86-video-intel pulseaudio pulseaudio-alsa pulseaudio-bluetooth
    # Display manager
    case $dm in
        'lightdm')
           echo "# Setting up lightdm..."
		   sleep 1
		   arch_chroot "pacman -S lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings --noconfirm"
		   arch_chroot "systemctl enable lightdm"
			;;
			

        'sddm') 
			echo "# Setting up sddm..."
			sleep 1
			arch_chroot "pacman -S sddm sddm-kcm --noconfirm"
			arch_chroot "systemctl enable sddm"
            ;;
			
		'gdm') 
			echo "# Setting up gdm..."
			sleep 1
			arch_chroot "pacman -S gdm --noconfirm"
			arch_chroot "systemctl enable gdm"
            ;;
			esac
    # Desktop envrioment
    case $desktop in
        'Mate')
           echo "# Installing mate..."
		   sleep 1
		   arch_chroot "pacman -S mate mate-extra mate-menu mate-media --noconfirm"
		   ;;
			

        'KDE Plasma') 
			echo "# Installing KDE Plasma..."
			sleep 1
			arch_chroot "pacman -S plasma dolphin konsole ark --noconfirm"
            ;;
		
		
		'Gnome') 
			echo "# Installing Gnome..."
			sleep 1
			arch_chroot "pacman -S gnome-desktop gnome-tweaks gnome-control-center --noconfirm"
            ;;
			esac
    # Applications
        echo "# Configuring Sudo for automation..."
        sed -i 's/^# %wheel ALL=(ALL) NOPASSWD: ALL/%wheel ALL=(ALL) NOPASSWD: ALL/' /etc/sudoers
        echo "# Installing applications..."
        arch_chroot "pacman -S bash-completion --noconfirm"
        arch_chroot "pacman -S haveged --noconfirm"
        arch_chroot "systemctl enable haveged"
        arch_chroot "pacman -S gst-plugins-good --noconfirm"
        arch_chroot "pacman -S gst-plugins-bad --noconfirm"
        arch_chroot "pacman -S gst-plugins-base --noconfirm"
        arch_chroot "pacman -S gst-plugins-ugly --noconfirm"
        arch_chroot "pacman -S gst-libav --noconfirm"
        arch_chroot "pacman -S pluma --noconfirm"
        arch_chroot "pacman -S clementine --noconfirm"
        arch_chroot "pacman -S chromium --noconfirm"
        arch_chroot "pacman -S variety --noconfirm"
        arch_chroot "pacman -S grub-customizer --noconfirm"
        arch_chroot "pacman -S networkmanager network-manager-applet dhclient --noconfirm"
        arch_chroot "systemctl enable NetworkManager"
        arch_chroot "pacman -S openssh --noconfirm"
        arch_chroot "systemctl enable sshd.service"
        arch_chroot "systemctl enable sshd.socket"
        arch_chroot "pacman -S thunderbird --noconfirm"
        arch_chroot "pacman -S vlc --noconfirm"
        arch_chroot "pacman -S kodi --noconfirm"
        arch_chroot "pacman -S audacity --noconfirm"
        arch_chroot "pacman -S arduino arduino-avr-core --noconfirm"
        arch_chroot "gpasswd -a $username uucp"
        arch_chroot "gpasswd -a $username lock"
        arch_chroot "pacman -S gnome-calculator --noconfirm"
        arch_chroot "pacman -S filezilla --noconfirm"
        arch_chroot "pacman -S arc-gtk-theme --noconfirm"
        arch_chroot "pacman -S git yajl wget --noconfirm"
        arch_chroot "pacman -S neofetch screenfetch --noconfirm"
        arch_chroot "pacman -S pavucontrol --noconfirm"
    # Bluetooth
        echo 'Enabling bluetooth support...'
        arch_chroot "pacman -S blueman --noconfirm"
        arch_chroot "systemctl enable bluetooth"
    # Yay
        echo "# Installing Yay..."
        arch_chroot "mkdir installtemp"
        mv installyay.sh /mnt/installtemp/
        echo $username >> /mnt/installtemp/username.txt
        echo $dev >> /mnt/installtemp/dev.txt
        arch_chroot "chmod -R 777 installtemp"
        arch_chroot "su -c 'bash /installtemp/installyay.sh' $(cat /installtemp/username.txt)"
        arch_chroot "su -c 'yay -S numix-circle-icon-theme-git --noconfirm' $(cat /installtemp/username.txt)"
        echo "# Setting up sudo for normal operation..."
        arch_chroot "sed -i 's/^%wheel ALL=(ALL) NOPASSWD: ALL/# %wheel ALL=(ALL) NOPASSWD: ALL/' /etc/sudoers"
        arch_chroot "sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers"
    # Calling bootloader function
    bootloader
    # Temp clear
        echo "# Cleaning up temporary files..."
        rm -rf /mnt/installtemp
}
# Execution begins...
welcome_box
partition
config
root_password
changeshell
user_password
desktop
display_manager
install