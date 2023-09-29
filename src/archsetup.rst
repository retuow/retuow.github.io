================
 I use Arch btw
================

.. contents:: :depth: 2

Introduction
============

This document describes the Arch Linux installation process I went through
to install it on my laptop (a Dell XPS 13, model 9315). Everything seems to
work, except for the webcam. But I don't really care for that.

Note that this is more a braindump than an actual tutorial.

I used many helpful resources during the installation. Some worth mentioning
are the
`ArchWiki <https://wiki.archlinux.org/>`_
and the very helpful
`Arch Linux Setup with Disk Encryption <https://paedubucher.ch/articles/2020-09-26-arch-linux-setup-with-disk-encryption.html>`_
article.

For the disk layout, I wanted disk encryption, but I did not bother with
intricate partition layouts or even a swap partition. I just used a single
root partition (apart from the EFI system partition) and a swap file.

This is also not a dual boot setup, so I just turned off Secure Boot.

Minimal installation
====================

- Make sure Secure Boot is disabled.

- Download the `installation iso <https://archlinux.org/download/>`_
  and boot from it.

- First thing to do after booting from the iso is connecting to the Wi-Fi::

    # iwctl --passphrase SECRET station wlan0 connect SSID

- After that, test if an internet connection is established::

    # ping archlinux.org

- Find out the name of the device Arch Linux will be installed on::

    # lsblk

  It is ``/dev/nvme0n1`` in my case.

- Fill the SSD with random junk::

    # shred --random-source=/dev/urandom --iterations=1 /dev/nvme0n1

- Next up, create a new GPT partition scheme::

    # parted -s /dev/nvme0n1 mklabel gpt

- Create the EFI system partition::

    # parted -s /dev/nvme0n1 mkpart boot fat32 1MiB 1025MiB
    # parted -s /dev/nvme0n1 set 1 esp on
    # mkfs.fat -F 32 /dev/nvme0n1p1

- Next, create the encrypted root partition::

    # parted -s /dev/nvme0n1 mkpart root 1025MiB '100%'
    # cryptsetup luksFormat /dev/nvme0n1p2
    # cryptsetup open /dev/nvme0n1p2 root
    # mkfs.ext4 /dev/mapper/root

- Mount the partitions::

    # mount /dev/mapper/root /mnt
    # mkdir /mnt/boot
    # chmod 0700 /mnt/boot
    # mount /dev/nvme0n1p1 /mnt/boot

- Bootstrap the installation::

    # pacstrap /mnt base linux linux-firmware

- Generate the ``/etc/fstab`` file::

    # genfstab -U /mnt >> /mnt/etc/fstab

- Chroot into the system::

    # arch-chroot /mnt

- Install some additional software we will need later on::

    # pacman -S base-devel git networkmanager less man-db neovim
    # echo 'EDITOR=nvim' >> /etc/environment

- Configure date and time::

    # ln -sf /usr/share/zoneinfo/Europe/Brussels /etc/localtime
    # hwclock --systohc

- Configure locale::

    # nvim /etc/locale.gen

  and enable the line ``en_GB.UTF-8 UTF-8``. Save, quit and run::

    # locale-gen
    # echo 'LANG=en_GB.UTF-8' >> /etc/locale.conf

- Set hostname::

    # echo aisha >> /etc/hostname

- Create hosts file::

    # nvim /etc/hosts

  and add the lines::

    127.0.0.1 localhost
    127.0.1.1 aisha
    ::1 localhost ip6-localhost ip6-loopback

- Configure the boot loader (``systemd-boot``)::

    # systemd-machine-id-setup
    # bootctl --path=/boot install

- Generate boot loader entries::

    # uuid=$(blkid --match-tag UUID -o value /dev/nvme0n1p2)
    # echo $uuid
    # cat << EOF > /boot/loader/entries/arch.conf
    > title   Arch Linux
    > linux   /vmlinuz-linux
    > initrd  /initramfs-linux.img
    > options cryptdevice=UUID=${uuid}:root root=/dev/mapper/root rw
    > EOF
    # cat << EOF > /boot/loader/entries/arch-fallback.conf
    > title   Arch Linux (fallback)
    > linux   /vmlinuz-linux
    > initrd  /initramfs-linux-fallback.img
    > options cryptdevice=UUID=${uuid}:root root=/dev/mapper/root rw
    > EOF

- Add ``keyboard`` and ``encrypt`` hooks to ``/etc/mkinitcpio.conf``::

    HOOKS=(base udev autodetect modconf kms keyboard keymap consolefont block encrypt filesystems fsck) 

- Regenerate the initial ramdisk environments::

    # mkinitcpio -P

- Add an admin user account::

    # useradd -m -G wheel retuow
    # passwd retuow
    # echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/wheel

- Reboot into Arch Linux.

Configuring the system
======================

- Configure NetworkManager and connect to the Wi-Fi again::

    $ sudo nmtui

- Enable NTP::

    $ sudo timedatectl set-ntp true

- Create a swap file::

    $ sudo -i
    # dd if=/dev/zero of=/swapfile bs=1M count=16k status=progress
    # chmod 0600 /swapfile
    # mkswap -U clear /swapfile
    # swapon /swapfile

- Add the swap file to ``/etc/fstab``::

    # swap
    /swapfile none swap defaults 0 0

- Reload ``systemd`` manager configuration::

    $ sudo systemctl daemon-reload

- Install ``paru`` AUR helper::

    $ git clone https://aur.archlinux.org/paru-bin.git
    $ cd paru-bin
    $ makepkg -si

- Configure mdns::

    $ paru -S nss-msdns
    $ sudo systemctl enable avahi-daemon.service
    $ sudo systemctl start avahi-daemon.service
    $ sudoedit /etc/nsswitch.conf

  and add the ``mdns_minimal`` entry to the ``hosts`` lookup::

    hosts: mymachines mdns_minimal [NOTFOUND=return] resolve [!UNAVAIL=return] files myhostname dns

- Install GNOME::

    $ paru -S gnome
    $ paru -S power-profiles-daemon gnome-terminal-transparency gnome-tweaks gnome-shell-extensions
    $ paru -S noto-fonts noto-fonts-cjk noto-fonts-emoji noto-fonts-extra
    $ paru -S ttf-dejavu ttf-jetbrains-mono ttf-ubuntu-font-family

- Go to `<https://extensions.gnome.org/>`_ and install the *Gnome Shell
  integration* plugin. Next, install the following extensions:
  
    * AppIndicator and KStatusNotifierItem Support
    * Arch Linux Updates Indicator
    * No Overview at start-up
    * Unblank lock screen

- Install Firefox::

    $ paru -S firefox gnome-browser-connector

- Enable sound::

    $ paru -S sof-firmware pipewire pipewire-alsa pipewire-pulse

- Enable Bluetooth::

    $ paru -S bluez bluez-utils
    $ sudo systemctl enable bluetooth.service
    $ sudo systemctl start bluetooth.service

  Enable the *Fast Connectable* setting in
  ``/etc/bluetooth/main.conf``::

    FastConnectable = true

- Configure firmware update support::

    $ paru -S fwupd gnome-firmware

- Install some additional software::

    $ paru -S inetutils neofetch openbsd-netcat pacman-contrib vifm tmux
    $ paru -S 1password 1password-cli asdf-vm protonvpn

- Configure ``reflector`` to keep the ``pacman`` mirrorlist up to date::

    $ paru -S reflector rsync
    $ sudoedit /etc/xdg/reflector/reflector.conf
    $ sudo systemctl start reflector.service
    $ sudo systemctl enable reflector.timer
    $ sudo systemctl start reflector.timer

- Configure user-mountable NAS shares::

    $ sudo mkdir -p /etc/samba/credentials
    $ sudo touch /etc/samba/credentials/nas
    $ sudo chown retuow:retuow /etc/samba/credentials/nas
    $ sudo chmod 0600 /etc/samba/credentials/nas
    $ nvim /etc/samba/credentials/nas

  Make sure the file only contains these settings::

    username=retuow
    password=SECRET

  Add entries for the NAS shares to ``/etc/fstab``::

    # NAS SMB Shares
    //SERVER/Share /mnt/share cifs _netdev,nofail,credentials=/etc/samba/credentials/nas,user,noauto,uid=retuow,gid=retuow 0 0

  Reload ``systemd`` manager configuration::

    $ sudo systemctl daemon-reload

- Configure GNOME Terminal::

    $ export TERMINAL=gnome-terminal
    $ cd ~/Development
    $ git clone https://github.com/Gogh-Co/Gogh gogh
    $ cd gogh/installs
    $ ./gruvbox-dark.sh

  **TIP:** Go to the *Preferences - General* and turn off the option
  *Enable the menu accelerator key* if you want to use the ``F10`` key
  (in ``htop`` for example).

- Configure bash, tmux, neovim

  See my `dotfiles <https://gitlab.com/retuow/dotfiles>`_ repository.

- Configure Keychron Bluetooth keyboard::

    $ sudoedit /etc/modprobe.d/hid_apple.conf

  Set the following options::

    options hid_apple fnmode=2 swap_opt_cmd

  Regenerate the initramfs::

    $ sudo mkinitcpio -P
