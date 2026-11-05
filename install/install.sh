#!/usr/bin/env bash
# HayphyrOS - instalador (rodar na ISO live, como root, em UEFI)
# ATENCAO: apaga TODO o disco escolhido.
set -euo pipefail

red()   { printf '\e[31m%s\e[0m\n' "$*"; }
green() { printf '\e[32m%s\e[0m\n' "$*"; }
die()   { red "ERRO: $*"; exit 1; }

[[ $EUID -eq 0 ]] || die "rode como root."
[[ -d /sys/firmware/efi ]] || die "o PC nao esta em modo UEFI."
ping -c1 -W3 archlinux.org >/dev/null 2>&1 || die "sem internet (use cabo ou iwctl)."
timedatectl set-ntp true

echo
green "=== HayphyrOS installer ==="
echo
lsblk -d -o NAME,SIZE,MODEL,TRAN,FSTYPE -e7,11
echo
read -rp "Disco onde instalar (ex: /dev/nvme1n1): " DISCO
[[ -b "$DISCO" ]] || die "$DISCO nao existe."

# --- travas de seguranca ---
if lsblk -no FSTYPE "$DISCO" | grep -qi ntfs; then
  die "$DISCO tem particao NTFS (provavelmente o Windows). Abortado."
fi
BOOTSRC=$(findmnt -no SOURCE /run/archiso/bootmnt 2>/dev/null || true)
if [[ -n "$BOOTSRC" && "$BOOTSRC" == "$DISCO"* ]]; then
  die "$DISCO e o pendrive de instalacao."
fi
if lsblk -no MOUNTPOINTS "$DISCO" | grep -q '[^[:space:]]'; then
  die "$DISCO tem particoes montadas."
fi

echo
lsblk -o NAME,SIZE,MODEL,FSTYPE,LABEL "$DISCO"
echo
red "TODO o conteudo de $DISCO sera APAGADO."
read -rp "Digite o caminho do disco de novo para confirmar: " CONF
[[ "$CONF" == "$DISCO" ]] || die "confirmacao nao confere."
read -rp "Digite APAGAR para continuar: " CONF2
[[ "$CONF2" == "APAGAR" ]] || die "cancelado."

read -rp "Nome do computador [hayphyr]: " HOSTN; HOSTN=${HOSTN:-hayphyr}
read -rp "Nome do usuario: " USERN
[[ "$USERN" =~ ^[a-z_][a-z0-9_-]*$ ]] || die "nome de usuario invalido."
read -rsp "Senha do usuario: " PASS1; echo
read -rsp "Repita a senha: " PASS2; echo
[[ "$PASS1" == "$PASS2" && -n "$PASS1" ]] || die "senhas diferentes ou vazias."
read -rp "Instalar pilha de jogos (Steam, GameMode, MangoHud, Gamescope)? [S/n]: " JOGOS
JOGOS=${JOGOS:-S}

# sufixo p para nvme/mmcblk
if [[ "$DISCO" =~ (nvme|mmcblk) ]]; then P="p"; else P=""; fi
EFI="${DISCO}${P}1"; ROOT="${DISCO}${P}2"

green ">> Particionando $DISCO"
umount -R /mnt 2>/dev/null || true
wipefs -af "$DISCO"
sgdisk -Z "$DISCO"
sgdisk -n1:0:+1G -t1:ef00 -c1:EFI "$DISCO"
sgdisk -n2:0:0   -t2:8300 -c2:HayphyrOS "$DISCO"
partprobe "$DISCO"; sleep 2

green ">> Formatando"
mkfs.fat -F32 "$EFI"
mkfs.ext4 -F "$ROOT"
mount "$ROOT" /mnt
mount --mkdir "$EFI" /mnt/boot

green ">> Instalando sistema base (precisa de internet)"
pacstrap -K /mnt base linux linux-firmware amd-ucode networkmanager nano sudo \
  sway foot wmenu mesa vulkan-radeon vulkan-tools \
  pipewire pipewire-pulse wireplumber ttf-dejavu htop zram-generator
genfstab -U /mnt >> /mnt/etc/fstab

ROOT_UUID=$(blkid -s UUID -o value "$ROOT")

green ">> Configurando"
cat > /mnt/root/chroot.sh <<CHROOT
set -euo pipefail
ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
hwclock --systohc
sed -i 's/^#pt_BR.UTF-8 UTF-8/pt_BR.UTF-8 UTF-8/; s/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=pt_BR.UTF-8" > /etc/locale.conf
echo "KEYMAP=br-abnt2" > /etc/vconsole.conf
echo "$HOSTN" > /etc/hostname

useradd -m -G wheel "$USERN"
echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/10-wheel
chmod 440 /etc/sudoers.d/10-wheel

bootctl install
cat > /boot/loader/loader.conf <<L
default arch.conf
timeout 3
L
cat > /boot/loader/entries/arch.conf <<L
title   HayphyrOS
linux   /vmlinuz-linux
initrd  /amd-ucode.img
initrd  /initramfs-linux.img
options root=UUID=$ROOT_UUID rw quiet loglevel=3 amd_pstate=active
L

cat > /etc/systemd/zram-generator.conf <<L
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
L
cat > /etc/sysctl.d/99-hayphyr.conf <<L
vm.swappiness = 180
vm.page-cluster = 0
vm.watermark_boost_factor = 0
vm.watermark_scale_factor = 125
L

cat > /home/$USERN/.bash_profile <<'L'
[[ -f ~/.bashrc ]] && . ~/.bashrc
if [ -z "\$WAYLAND_DISPLAY" ] && [ "\$XDG_VTNR" = 1 ]; then
  exec sway
fi
L
mkdir -p /home/$USERN/.config/sway
cp /etc/sway/config /home/$USERN/.config/sway/config

systemctl enable NetworkManager systemd-timesyncd
CHROOT

if [[ "$JOGOS" =~ ^[sSyY]$ ]]; then
cat >> /mnt/root/chroot.sh <<'CHROOT'
sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
pacman -Sy --noconfirm
pacman -S --noconfirm --needed lib32-vulkan-radeon lib32-mesa
pacman -S --noconfirm --needed steam gamemode lib32-gamemode mangohud lib32-mangohud gamescope
CHROOT
cat >> /mnt/root/chroot.sh <<CHROOT
usermod -aG gamemode "$USERN"
mkdir -p /home/$USERN/.config/MangoHud
printf 'fps\ncpu_stats\ngpu_stats\nram\nframetime\nposition=top-left\nfont_size=18\n' > /home/$USERN/.config/MangoHud/MangoHud.conf
CHROOT
fi

cat >> /mnt/root/chroot.sh <<CHROOT
chown -R $USERN:$USERN /home/$USERN
CHROOT

arch-chroot /mnt bash /root/chroot.sh
echo "root:$PASS1"    | arch-chroot /mnt chpasswd
echo "$USERN:$PASS1"  | arch-chroot /mnt chpasswd
rm -f /mnt/root/chroot.sh

umount -R /mnt
echo
green "Instalacao concluida! Retire o pendrive e reinicie (poweroff)."
