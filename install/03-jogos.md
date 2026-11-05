sudo nano /etc/pacman.conf

[multilib]
Include = /etc/pacman.d/mirrorlist

sudo pacman -Syu

sudo pacman -S steam gamemode lib32-gamemode mangohud lib32-mangohud gamescope \
  vulkan-radeon lib32-vulkan-radeon lib32-mesa vulkan-tools

sudo usermod -aG gamemode $USER

gamemoded -t

mkdir -p ~/.config/MangoHud
nano ~/.config/MangoHud/MangoHud.conf

fps
cpu_stats
gpu_stats
ram
frametime
position=top-left
font_size=18

sudo pacman -S --needed base-devel git
git clone https://aur.archlinux.org/yay-bin.git
cd yay-bin && makepkg -si
cd .. && rm -rf yay-bin
yay -S protonup-qt
