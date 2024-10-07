#!/usr/bin/env bash

echo "Selecciona la partición EFI: (DEBE ESTAR EN FAT 32)"
read EFI

echo "Selecciona la partición Root: (Se borrará lo que hubiera)"
read ROOT  

echo "Login:"
read USER 

echo "Contraseña:"
read PASSWORD 

# make filesystems
echo -e "\nCreando Particiones...\n"

mkfs.btrfs -f "${ROOT}"

# mount target
mount "${ROOT}" /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
umount /mnt
mount -o compress=zstd,subvol=@ "${ROOT}" /mnt
mkdir -p /mnt/home
mount -o compress=zstd,subvol=@home "${ROOT}" /mnt/home
mount --mkdir "$EFI" /mnt/efi

echo "--------------------------------------"
echo "-- INSTALLING Base Arch Linux --"
echo "--------------------------------------"
pacstrap /mnt base base-devel linux linux-firmware linux-headers networkmanager wireless_tools nano intel-ucode bluez bluez-utils git --noconfirm --needed

# fstab
genfstab -U /mnt >> /mnt/etc/fstab

cat <<REALEND > /mnt/next.sh
useradd -aG wheel $USER
echo $USER:$PASSWORD | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

echo "-------------------------------------------------"
echo "Setup Language to ES and set locale"
echo "-------------------------------------------------"
sed -i 's/^#es_ES.UTF-8 UTF-8/es_ES.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=es_ES.UTF-8" >> /etc/locale.conf

ln -sf /usr/share/zoneinfo/Europe/Madrid /etc/localtime
hwclock --systohc

echo "archlinux" > /etc/hostname
cat <<EOF > /etc/hosts
127.0.0.1	localhost
::1			localhost
127.0.1.1	archlinux.localdomain	archlinux
EOF

echo "--------------------------------------"
echo "-- Bootloader Installation  --"
echo "--------------------------------------"

pacman -S grub ntfs-3g os-prober efibootmgr --noconfirm --needed
grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

echo "-------------------------------------------------"
echo "Video and Audio Drivers"
echo "-------------------------------------------------"

pacman -S xorg mesa-utils nvidia nvidia-utils nvidia-settings opencl-nvidia nvidia-prime pipewire pipewire-alsa pipewire-pulse --noconfirm --needed

systemctl enable NetworkManager bluetooth
systemctl --user enable pipewire pipewire-pulse


echo "-------------------------------------------------"
echo "Desktop Environment"
echo "-------------------------------------------------"
pacman -S gnome-shell gnome-control-center gnome-calculator gnome-menus colord-gtk nautilus python-nautilus ffmpegthumbnailer gvfs-mtp file-roller xdg-desktop-portal-gnome gnome-tweaks gnome-terminal gnome-themes-extra gnome-color-manager gnome-backgrounds gnome-disk-utility gnome-screenshot gnome-shell-extensions evince loupe gnome-text-editor xdg-user-dirs-gtk gdm gnome-keyring power-profiles-daemon --noconfirm --needed

pacman -S ttf-liberation ttf-fira-sans ttf-jetbrains-mono noto-fonts noto-fonts-cjk noto-fonts-emoji noto-fonts-extra --noconfirm --needed

pacman -S wget vlc rhythmbox neofetch qbittorrent switcheroo-control --noconfirm --needed

systemctl enable gdm switcheroo-control 

echo "-------------------------------------------------"
echo "Install Complete, You can reboot now"
echo "-------------------------------------------------"

REALEND

arch-chroot /mnt sh next.sh

