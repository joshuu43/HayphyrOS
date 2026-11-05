systemd-analyze            # tempo de boot
free -h                    # RAM usada
systemctl list-unit-files --state=enabled   # serviços ligados

sudo pacman -S zram-generator
sudo nano /etc/systemd/zram-generator.conf

[zram0]
zram-size = ram / 2
compression-algorithm = zstd

sudo systemctl daemon-reload
sudo systemctl start systemd-zram-setup@zram0.service
zramctl                    # confere se apareceu

sudo nano /etc/sysctl.d/99-hayphyr.conf

vm.swappiness = 180
vm.page-cluster = 0
vm.watermark_boost_factor = 0
vm.watermark_scale_factor = 125

sudo sysctl --system

sudo pacman -S sway foot wmenu mesa pipewire pipewire-pulse wireplumber ttf-dejavu htop

sudo pacman -S virtualbox-guest-utils
sudo systemctl enable --now vboxservice

nano ~/.bash_profile

if [ -z "$WAYLAND_DISPLAY" ] && [ "$XDG_VTNR" = 1 ]; then
  WLR_RENDERER=pixman WLR_NO_HARDWARE_CURSORS=1 sway
fi

mkdir -p ~/.config/sway
cp /etc/sway/config ~/.config/sway/config

systemd-analyze blame | head
systemctl list-unit-files --state=enabled
