#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

# Проверка наличия необходимых утилит
check_dependencies() {
    local dependencies=("sfdisk" "wget" "tar" "mkfs.vfat" "mkfs.ext4" "mkswap" "swapon" "gcc")
    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            echo "Error: $dep is not installed or not in PATH"
            exit 1
        fi
    done
}

# Проверка доступности URL для загрузки
check_url() {
    if ! wget --spider --quiet "$1"; then
        echo "Error: Unable to reach $1"
        exit 1
    fi
}

# Проверка смонтированных точек
mount_check() {
    if ! mountpoint -q "$1"; then
        echo "Error: Failed to mount $1"
        exit 1
    else
        echo "$1 successfully mounted"
    fi
}

# Создание разделов на диске
create_partitions() {
    # Check for existing partitions
    if [ "$(lsblk /dev/vda | grep -c vda1)" -ne 0 ]; then
        read -p "There are already partitions on the disk. Should I continue executing the script? (yes/no): " choice
        case "$choice" in
            yes|Yes) ;;
            *) echo "The installation has been canceled..."; exit 1;;
        esac
    fi
    
    # Create partitions
    echo "Mounting partitions..."
    echo -ne "label:gpt\nsize=2GiB,type=\"EFI System\"\nsize=12GiB,type=\"Linux swap\"\nsize=+,type=\"Linux root(x86-64)\"\n" | sfdisk /dev/vda && echo "Partitions created successfully."
}



# Форматирование разделов
format_partitions() {
    echo "Making filesystems... formatting partitions"
    mkfs.vfat -F 32 /dev/vda1
    mkfs.ext4 /dev/vda3
    mkswap /dev/vda2
    swapon /dev/vda2
}

# Создание и монтирование точек монтирования
mount_partitions() {
    mkdir -p /mnt/gentoo
    mount /dev/vda3 /mnt/gentoo
    mount_check "/mnt/gentoo"

    mkdir -p /mnt/gentoo/efi
    mount /dev/vda1 /mnt/gentoo/efi
    mount_check "/mnt/gentoo/efi"
}

# Установка make.conf
setup_make_conf() {
    echo "Setting up make.conf..."
    echo -ne "COMMON_FLAGS=\"-O2 -march=znver3 -pipe\"\nCFLAGS=\"\${COMMON_FLAGS}\"\nCXXFLAGS=\"\${COMMON_FLAGS}\"\nMAKEOPTS=\"-j3 -l3\"\nACCEPT_LICENSE=\"*\"\n" > /mnt/gentoo/etc/portage/make.conf
}

# Монтирование файловых систем для chroot
mount_for_chroot() {
    echo "Mounting filesystems for chroot..."
    mount --types proc /proc /mnt/gentoo/proc
    mount_check "/mnt/gentoo/proc"

    mount --rbind /sys /mnt/gentoo/sys
    mount --make-rslave /mnt/gentoo/sys
    mount_check "/mnt/gentoo/sys"

    mount --rbind /dev /mnt/gentoo/dev
    mount --make-rslave /mnt/gentoo/dev
    mount_check "/mnt/gentoo/dev"

    mount --bind /run /mnt/gentoo/run
    mount --make-slave /mnt/gentoo/run
    mount_check "/mnt/gentoo/run"
}

# Передача управления в chroot среду
enter_chroot() {
    chroot /mnt/gentoo /bin/bash -c "source /etc/profile && export PS1=\"(chroot) \$PS1\" && exec bash"
}

# Основной поток исполнения скрипта
main() {
    local stage_tarball_url="https://distfiles.gentoo.org/releases/amd64/autobuilds/20240317T170433Z/stage3-amd64-systemd-mergedusr-20240317T170433Z.tar.xz"
    
    check_dependencies
    check_url "$stage_tarball_url"
    
    create_partitions
    format_partitions
    mount_partitions
    
    cd /mnt/gentoo
    wget "$stage_tarball_url"
    tar xpvf stage3-*.tar.xz --xattrs-include='*.*' --numeric-owner
    
    setup_make_conf
    
    cp --dereference /etc/resolv.conf /mnt/gentoo/etc/
    
    mount_for_chroot
    
    echo "Part №1 - complete..."
    
    enter_chroot
}

main

