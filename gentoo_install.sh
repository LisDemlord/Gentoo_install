#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

# Функция для проверки успешности монтирования
check_mount_success() {
    if ! mountpoint -q "$1"; then
        echo "Ошибка: Не удалось смонтировать $1"
        exit 1
    else
        echo "$1 успешно смонтирован"
    fi
}

# Монтирование разделов
echo "Монтирование разделов..."
echo -ne "label:gpt\nsize=2GiB,type=\"EFI System\"\nsize=12GiB,type=\"Linux swap\"\nsize=+,type=\"Linux root (x86-64)\"\n" | sfdisk /dev/vda

echo "Форматирование разделов..."
mkfs.vfat -F 32 /dev/vda1
mkfs.xfs /dev/vda3
mkswap /dev/vda2
swapon /dev/vda2

echo "Монтирование файловых систем..."
mkdir --parents /mnt/gentoo
mount /dev/vda3 /mnt/gentoo
check_mount_success "/mnt/gentoo"

mkdir --parents /mnt/gentoo/efi
mount /dev/vda1 /mnt/gentoo/efi
check_mount_success "/mnt/gentoo/efi"

# Остальные действия
cd /mnt/gentoo
date

wget https://distfiles.gentoo.org/releases/amd64/autobuilds/20240317T170433Z/stage3-amd64-systemd-mergedusr-20240317T170433Z.tar.xz
tar xpvf stage3-*.tar.xz --xattrs-include='*.*' --numeric-owner

echo "Настройка системы..."
echo -ne "COMMON_FLAGS=\"-O2 -march=znver2 -pipe\"\nCFLAGS=\"\${COMMON_FLAGS}\"\nCXXFLAGS=\"\${COMMON_FLAGS}\"\nMAKEOPTS=\"-j3 -l3\"\nACCEPT_LICENSE=\"*\"\n" > /etc/portage/make.conf
cp --dereference /etc/resolv.conf /mnt/gentoo/etc/

echo "Монтирование необходимых файловых систем внутри chroot..."
mount --types proc /proc /mnt/gentoo/proc
check_mount_success "/mnt/gentoo/proc"

mount --rbind /sys /mnt/gentoo/sys
mount --make-rslave /mnt/gentoo/sys
check_mount_success "/mnt/gentoo/sys"

mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/dev
check_mount_success "/mnt/gentoo/dev"

mount --bind /run /mnt/gentoo/run
mount --make-slave /mnt/gentoo/run
check_mount_success "/mnt/gentoo/run"

echo "Войдите в chroot окружение..."
echo "Выполнение скрипта завершено."
