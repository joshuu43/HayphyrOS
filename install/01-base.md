ls /sys/firmware/efi        # se listar arquivos, está em UEFI (ok)
ping -c 3 archlinux.org     # confere a internet
timedatectl set-ntp true
lsblk                       # descobre o nome do disco

cfdisk /dev/sda

mkfs.fat -F32 /dev/sda1
mkfs.ext4 /dev/sda2
mount /dev/sda2 /mnt
mount --mkdir /dev/sda1 /mnt/boot

pacstrap -K /mnt base linux linux-firmware amd-ucode networkmanager nano sudo
genfstab -U /mnt >> /mnt/etc/fstab
arch-chroot /mnt

ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
hwclock --systohc
nano /etc/locale.gen        # tire o # de pt_BR.UTF-8 UTF-8 e en_US.UTF-8 UTF-8
locale-gen
echo "LANG=pt_BR.UTF-8" > /etc/locale.conf
echo "KEYMAP=br-abnt2" > /etc/vconsole.conf
echo "hayphyr" > /etc/hostname
passwd                      # senha do root

useradd -m -G wheel seunome
passwd seunome
EDITOR=nano visudo          # tire o # da linha: %wheel ALL=(ALL:ALL) ALL

bootctl install
nano /boot/loader/loader.conf

blkid -s UUID -o value /dev/sda2

nano /boot/loader/entries/arch.conf
title   HayphyrOS
linux   /vmlinuz-linux
initrd  /amd-ucode.img
initrd  /initramfs-linux.img
options root=UUID=COLE-O-UUID rw

systemctl enable NetworkManager
exit
umount -R /mnt
reboot

nmcli device status         # confere a rede
sudo pacman -Syu
