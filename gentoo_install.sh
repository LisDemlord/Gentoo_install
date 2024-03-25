#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

echo -ne "label:gpt\nsize=2GiB,type=\"EFI System\"\nsize=12GiB,type=\"Linux swap\"\nsize=+,type=\"Linux root (x86-64)\"\n" | sfdisk /dev/vda

mkfs.vfat -F 32 /dev/vda1
mkfs.xfs /dev/vda3
mkswap /dev/vda2
swapon /dev/vda2

mkdir --parents /mnt/gentoo
mount /dev/vda3 /mnt/gentoo

mkdir --parents /mnt/gentoo/efi
mount /dev/vda1 /mnt/gentoo/efi  # Монтируем раздел EFI в /mnt/gentoo/efi

cd /mnt/gentoo
date

wget https://distfiles.gentoo.org/releases/amd64/autobuilds/20240317T170433Z/stage3-amd64-systemd-mergedusr-20240317T170433Z.tar.xz
tar xpvf stage3-*.tar.xz --xattrs-include='*.*' --numeric-owner