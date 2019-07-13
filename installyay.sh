#!/bin/sh
# YaLAI Yay installer script
# DEPRECATED...
# # Version 1.0
# Written by minigyima
# Copyright 2019

# Changeing to temporary directory
    cd /installtemp
# Git cloning
    git clone https://aur.archlinux.org/yay.git
# yay dir
    cd yay
# Building package...
    makepkg -si --noconfirm
