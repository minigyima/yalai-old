# YaLAI installer
# Version 2.0
# Written by minigyima
# Copyright 2019

# Determinig system type (UEFI or BIOS)
if [[ -d "/sys/firmware/efi/" ]]; then
      SYSTEM="UEFI"
      else
      SYSTEM="BIOS"
fi
welcome_text="Welcome to YaLAI (Yet another Live Arch Installer)! \nNext you will be prompted with a set of questions, that will guide you through installing Arch Linux.\nClick 'Yes' to begin, and 'No' to exit."
title="YaLAI installer (Version 2.0, running in $SYSTEM mode.) "
arch_chroot() {
    arch-chroot /mnt /bin/bash -c "${1}"
}
welcome_box() {
zenity --question --height=300 --width=450 --title="$title" --text "$welcome_text"
if [ "$?" = "1" ]
	then exit
fi
}
# 'Secret' menu for selecting an individual configuration option.
secret_menu () {
    sec_menu_choice=$(zenity --list --height=500 --width=450 --title="$title" --radiolist --text "Which configuration option would you like to jump to?" --column Select --column Option FALSE "Config: Locale" FALSE "Config: Keyboard Layout" FALSE "Config: Timezone" FALSE "Config: Hostname" FALSE "Config: Username" FALSE "Config: Change shell" FALSE "Config: Desktop" FALSE "Config: Display manager" FALSE "Config: Root password" FALSE "Config: User password" FALSE "Make preseed script" FALSE "Install summary" FALSE "Quit")
    case $sec_menu_choice in
        'Config: Locale')
            phase='locale'
            config
        ;;
        'Config: Keyboard Layout')
            phase='keylayout'
            config
        ;;
        'Config: Timezone')
            phase='timezone'
            config
        ;;
        'Config: Hostname')
            phase='hostname'
            config
        ;;
        'Config: Username')
            phase='username'
            config
        ;;
        'Config: Root password')
            phase='root_password'
            config
        ;;
        'Config: Change shell')
            phase='changeshell'
            config
        ;;
        'Config: User password')
            phase='user_password'
            config
        ;;
        'Config: Desktop')
            phase='desktop'
            config
        ;;
        'Config: Display manager')
            phase='display_manager'
            config
        ;;
        'Make preseed script')
            makepreseed
        ;;
        'Install summary')
            summary
        ;;
        'Quit')
            cleanup
        ;;
        esac
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
    # Root partition selector
    root_part=$(zenity --list --radiolist --height=300 --width=450 --title="$title" --text="Please choose a partition to use for the root partition\nWarning, this list shows all available partitions on all available drives.\nPlease choose with care." --column ' ' --column Partitions $(sudo fdisk -l | grep dev | grep -v Disk | awk '{print $1}' | awk '{ printf " FALSE ""\0"$0"\0" }'))
    # Mounting root partition
    touch root_part.txt    
    echo $root_part >> root_part.txt
    mount $root_part /mnt
    # Copying some files to /mnt/yalai
    mkdir /mnt/yalai
    cp -r x86_64/* /mnt/yalai
    # Swap partition selector
    swap_part=$(zenity --list  --radiolist --height=300 --width=450 --title="$title" --text="Please choose a partition to use for the swap partition\nWarning, this list shows all available partitions on all available drives.\nPlease choose with care." --column ' ' --column 'Partitions' $(sudo fdisk -l | grep dev | grep -v Disk | awk '{print $1}' | awk '{ printf " FALSE ""\0"$0"\0" }'))
    mkswap $swap_part
    swapon $swap_part
    # Boot partition selector (if UEFI)
    case $SYSTEM in
            'UEFI')
                # Boot partition selector dialogbox
                efi_boot=$(zenity --list  --radiolist --height=300 --width=450 --title="$title" --text="Please choose a partition to use for the boot partition\nWarning, this list shows all available partitions on all available drives.\nPlease choose with care." --column ' ' --column 'Partitions' $(sudo fdisk -l | grep dev | grep -v Disk | awk '{print $1}' | awk '{ printf " FALSE ""\0"$0"\0" }'))
                ;;
                

            'BIOS')
                echo "# Legacy BIOS detected... Skipping boot partition"
                ;;
                esac
}
loadpreseed() {
# Question box
    if zenity --question --height 300 --width 450 --title "$title" --text "Do you want to use a preseed file for an automated install?\nIf you press 'Yes', preseed.conf will be loaded."; then
    preseedstate=1
    locale=$(cat preseed.conf | grep locale | sed -E 's/^locale=//')
    layout=$(cat preseed.conf | grep keylayout | sed -E 's/^keylayout=//')
    zone=$(cat preseed.conf | grep tzone | sed -E 's/^tzone=//')
    subzone=$(cat preseed.conf | grep subzone | sed -E 's/^subzone=//')
    hostname=$(cat preseed.conf | grep hostname | sed -E 's/^hostname=//')
    username=$(cat preseed.conf | grep username | sed -E 's/^username=//')
    shell=$(cat preseed.conf | grep shell | sed -E 's/^shell=//')
    desktop=$(cat preseed.conf | grep desktop | sed -E 's/^desktop=//')
    dm=$(cat preseed.conf | grep display_manager | sed -E 's/^display_manager=//') 
    else
    preseedstate=0
    fi
}
# Configuration
config() {
    case $phase in
    'locale')
        # Setting up locales 
        locales=$(cat /etc/locale.gen | grep -v "#  " | sed 's/#//g' | sed 's/ UTF-8//g' | grep .UTF-8 | sort | awk '{ printf "FALSE ""\0"$0"\0" }')
        locale=$(zenity --list --radiolist --height=500 --width=450 --title="$title" --text "Please select your locale/language.\nThe default is American English 'en_US.UTF-8'." --column Select --column Locale TRUE en_US.UTF-8 $locales)
        # 'Secret_menu'
        if [ "$?" = "1" ]
        then secret_menu
        fi
        phase='keylayout'
        config
    ;;

    'keylayout')
        # Keyboard layout
        layout=$(zenity --list --radiolist --height=500 --width=450 --title="$title" --text="Please select your keyboard layout, usually a two letter country code" --column Select --column Layout $(localectl list-keymaps | awk '{ printf " FALSE ""\0"$0"\0" }'))
        # 'Secret_menu'
        if [ "$?" = "1" ]
        then secret_menu
        else
        setxkbmap $layout
        loadkeys $layout
        fi
        phase='timezone'
        config
    ;;

    'timezone')
        # Timezone
        zones=$(cat /usr/share/zoneinfo/zone.tab | awk '{print $3}' | grep "/" | sed "s/\/.*//g" | sort -ud | sort | awk '{ printf " FALSE ""\0"$0"\0" }')
        zone=$(zenity --list --radiolist --height=500 --width=450 --title="$title" --text "Please select your zone." --column Select --column Zone $zones)
        # 'Secret_menu'
        if [ "$?" = "1" ]
        then secret_menu
        else
        subzones=$(cat /usr/share/zoneinfo/zone.tab | awk '{print $3}' | grep "$zone/" | sed "s/$zone\///g" | sort -ud | sort | awk '{ printf " FALSE ""\0"$0"\0" }')
        subzone=$(zenity --list --radiolist --height=500 --width=450 --title="$title" --text "Please select your sub-zone." --column Select --column Zone $subzones)
        fi
        # 'Secret_menu'
        if [ "$?" = "1" ]
        then secret_menu
        fi
        phase='hostname'
        config
    ;;

    'hostname')
        # Hostname
        hostname=$(zenity --entry --title="$title" --text "Please enter a hostname for your system.\nIt must be in all lowercase letters." --entry-text "hostname")
        # 'Secret_menu'
        if [ "$?" = "1" ]
        then secret_menu
        fi
        phase='username'
        config
    ;;

    'username')
        # Username
        username=$(zenity --entry --title="$title" --text "Please enter a username for your user. Again, all lowercase." --entry-text "user")
        # 'Secret_menu'
        if [ "$?" = "1" ]
        then secret_menu
        fi
        phase='changeshell'
        config
    ;;

    'root_password')
        # Setting root password
        rtpasswd=$(zenity --entry --title="$title" --text "Please enter a root password." --hide-text)
        # 'Secret_menu'
        if [ "$?" = "1" ]
        then secret_menu
        else
        rtpasswd2=$(zenity --entry --title="$title" --text "Please re-enter your root password." --hide-text)
        fi
        # 'Secret_menu'
        if [ "$?" = "1" ]
        then secret_menu
        else
            if [ "$rtpasswd" != "$rtpasswd2" ]
                then zenity --error --height=500 --width=450 --title="$title" --text "The passwords did not match, please try again."
                root_password

            fi    
        fi
    ;;

    'changeshell')
        # Choosing a shell
        shell=$(zenity --list --radiolist --height=500 --width=450 --title="$title" --text "Which shell would you like to use?" --column Select --column Choice FALSE bash FALSE zsh FALSE fish)
        # 'Secret_menu'
        if [ "$?" = "1" ]
        then secret_menu
        fi
        phase='desktop'
        config
    ;;

    'user_password')
        # Setting user password
        userpasswd=$(zenity --entry --title="$title" --text "Please enter a password for $username." --hide-text)
        # 'Secret_menu'
        if [ "$?" = "1" ]
        then secret_menu
        else
        userpasswd2=$(zenity --entry --title="$title" --text "Please re-enter a password for $username." --hide-text)
        fi
        # 'Secret_menu'
        if [ "$?" = "1" ]
        then secret_menu
        else
            if [ "$userpasswd" != "$userpasswd2" ]
                then zenity --error --height=500 --width=450 --title="$title" --text "The passwords did not match, please try again."
                user_password
            fi
        fi
    ;;

    'desktop')
        # Choosing Desktop
        desktop=$(zenity --list --height=500 --width=450 --title="$title" --radiolist --text "Which desktop would you like to install?" --column Select --column Desktop FALSE "Gnome" FALSE "KDE Plasma" FALSE "Mate" )
        # 'Secret_menu'
        if [ "$?" = "1" ]
        then secret_menu
        fi
        phase='display_manager'
        config
    ;;

    'display_manager')
        # Choosing display manager
        dm=$(zenity --list --title="$title" --radiolist  --height=500 --width=450 --text "Which display manager would you like to use?" --column "Select" --column "Display Manager" FALSE "lightdm" FALSE "sddm" FALSE "gdm")
        # 'Secret_menu'
        if [ "$?" = "1" ]
        then secret_menu
        fi
    ;;
    esac
}
# Make a preseed file out of users choice of options
makepreseed() {
    date=$(date)
    if zenity --question --height 300 --width 450 --title "$title" --text "Would you like to make a preseed file from the configuration options that you have choosen?"; then
    echo "Preseed file for YaLAI installer." >> preseed_gen.conf
    echo "Generated by YaLAI on $date" >> preseed_gen.conf
    echo "locale=$locale" >> preseed_gen.conf
    echo "keylayout=$layout" >> preseed_gen.conf
    echo "tzone=$zone" >> preseed_gen.conf
    echo "subzone=$subzone" >> preseed_gen.conf
    echo "hostname=$hostname" >> preseed_gen.conf
    echo "username=$username" >> preseed_gen.conf
    echo "shell=$shell" >> preseed_gen.conf
    echo "desktop=$desktop" >> preseed_gen.conf
    echo "display_manager=$dm" >> preseed_gen.conf
    else 
    echo "# Skipping preseed creation"
    fi
}
bootloader() {
    # GRUB 2 install (gets called later...)
    case $SYSTEM in
        'UEFI')
            # Installing packages           
			echo "# Installing GRUB for UEFI..."
            arch_chroot "pacman -S grub efibootmgr --noconfirm"
            # Mounting boot partition (if UEFI)
            arch_chroot "mkdir /boot/efi"
            arch_chroot "mount $efi_boot /boot/efi"
            # Installing grub
			arch_chroot "grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB"
			arch_chroot "grub-mkconfig -o /boot/grub/grub.cfg"
			;;
			

        'BIOS') 
			echo "# Installing GRUB for BIOS..."
			sleep 1
            arch_chroot "pacman -S grub --noconfirm"
			arch_chroot "grub-install --target=i386-pc $dev"
			arch_chroot "grub-mkconfig -o /boot/grub/grub.cfg"
            ;;
			esac


}
cleanup() {
    echo "Configuring sudo for everyday use..."
    arch_chroot "sed -i 's/^%wheel ALL=(ALL) NOPASSWD: ALL/# %wheel ALL=(ALL) NOPASSWD: ALL/' /etc/sudoers"
    arch_chroot "sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers"
    echo "# Deleting temporary files..."
    rm -rf /mnt/yalai
    exit
}
install() {
    # Fixing Mirrorlist
    cp mirrorlist /etc/pacman.d/mirrorlist
    # Base, base-devel
    echo "# Installing base system via pacstrap..."
    baselist="bash bzip2 coreutils cryptsetup device-mapper dhcpcd diffutils e2fsprogs file filesystem findutils gawk gcc-libs gettext glibc grep gzip inetutils iproute2 iputils jfsutils less licenses linux linux-firmware logrotate lvm2 man-db man-pages mdadm nano netctl pacman pciutils perl procps-ng psmisc reiserfsprogs s-nail sed shadow sysfsutils systemd-sysvcompat tar texinfo usbutils util-linux vi which xfsprogs"
    pacstrap -i /mnt base base-devel --noconfirm
    echo "# Installing kernel and other utils..."
    arch_chroot "pacman -S --asdeps $baselist"
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
    arch_chroot "useradd -m -g users -G adm,lp,wheel,power,audio,video,uucp,lock -s /bin/bash $username"
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
		   arch_chroot "pacman -S mate mate-extra mate-media --noconfirm"
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
        arch_chroot "sed -i 's/^%wheel ALL=(ALL) ALL/# %wheel ALL=(ALL) ALL/' /etc/sudoers"
        arch_chroot "sed -i 's/^# %wheel ALL=(ALL) NOPASSWD: ALL/%wheel ALL=(ALL) NOPASSWD: ALL/' /etc/sudoers"
        echo "# Installing applications..."
    # Base programs
        arch_chroot "pacman -S bash-completion haveged gst-plugins-good gst-plugins-bad gst-plugins-base gst-plugins-ugly gst-libav networkmanager network-manager-applet dhclient openssh blueman --noconfirm"
        arch_chroot "systemctl enable haveged"
        arch_chroot "systemctl enable NetworkManager"
        echo 'Enabling bluetooth support...'
        arch_chroot "systemctl enable bluetooth"
        arch_chroot "systemctl enable sshd.service"
        arch_chroot "systemctl enable sshd.socket"
    # Yay
        arch_chroot "pacman -U /yalai/yay-9.2.1-1-x86_64.pkg.tar.xz --noconfirm"
    # Apps from appreseed.conf
        pkgs=$(cat appreseed.conf | grep pkgs | sed -E 's/^pkgs=//')
        arch_chroot "pacman -S $pkgs --noconfirm"
    # Numix icons
        arch_chroot "pacman -U /yalai/numix-icon-theme-git-0.r1982.88ba36545-1-any.pkg.tar.xz --noconfirm"
        arch_chroot "pacman -U /yalai/numix-circle-icon-theme-git-0.r50.386d242-1-any.pkg.tar.xz --noconfirm"
    # Oxygen cursors
        arch_chroot "pacman -U /yalai/xcursor-oxygen-5.16.1-1-any.pkg.tar.xz --noconfirm"
    # Grub install
    bootloader
    # Cleanup
    cleanup
}
summary() {
    if zenity --question --height 300 --width 450 --title "$title" --text "Theese are the options you have choosen for the installation.\nLocale: $locale\nKeyboard layout: $layout\nTimezone: $zone\nSubzone: $subzone\nHostname: $hostname\nUsername: $username\nShell: $shell\nDesktop: $desktop\nDisplay manager: $dm\n Would you like to continue?"; then
    install
    else secret_menu
    fi
}
# Execution begins...
welcome_box
partition
loadpreseed
# Checking wether a preseed file is loaded or not... If not, continuing
if (($preseedstate == 0)); then
    phase='locale'
    config
    phase='root_password'
    config
    phase='user_password'
    config
    makepreseed
    summary
else
    phase='root_password'
    config
    phase='user_password'
    config
    summary
fi