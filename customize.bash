#!/bin/bash
set -e
set -x

run_as_user() {
    local cmd="$@"
    local _UID=$(getent passwd $NORMAL_USER | cut -d: -f3)
    DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$_UID/bus su --whitelist-environment=DBUS_SESSION_BUS_ADDRESS - $NORMAL_USER -c "cd $(pwd) && $cmd"
}

NORMAL_USER="sanduuz"
data_directory="DATA"

if [ ! -e "$data_directory" ]; then
    echo "ERROR: Directory 'DATA' does not exist." 1>&2
    exit 1
fi

if [ "$UID" != "0" ]; then
    echo "This tool needs to be run as root!" 1>&2
    exit 1
fi

echo "Allowing NOPASSWD for sudo group"
echo "%sudo ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/nopasswd

echo "Adding $NORMAL_USER to group sudo"
adduser $NORMAL_USER sudo

echo "Installing non-free firmware and microcode"
echo "deb http://deb.debian.org/debian/ buster contrib non-free" > /etc/apt/sources.list.d/non-free.list
apt -y update
apt -y install firmware-iwlwifi firmware-misc-nonfree intel-microcode
rmmod iwlwifi || true
rmmod cfg80211 || true
modprobe cfg80211 || true
modprobe iwlwifi || true

echo "Configuring autologout on console logins"
cat > /etc/profile.d/auto-logout.sh <<EOF
case "\$(tty)" in
/dev/tty[1-9])
    TMOUT=600
    ;;
esac
EOF

echo "Disabling suspend on laptop lid close"
if ! grep -q ^HandleLidSwitch=ignore /etc/systemd/logind.conf; then
    echo HandleLidSwitch=ignore >> /etc/systemd/logind.conf
    echo HandleLidSwitchDocked=ignore >> /etc/systemd/logind.conf
fi

echo "Disabling sleeping on battery"
run_as_user "dconf write /org/gnome/settings-daemon/plugins/power/sleep-inactive-battery-type \"'nothing'\""
run_as_user "dconf write /org/gnome/settings-daemon/plugins/power/sleep-inactive-ac-type \"'nothing'\""

echo "Configuring wireshark for later"
echo "wireshark-common wireshark-common/install-setuid boolean false" | debconf-set-selections

echo "Installing other packages"
apt -y update
apt -y install rsync default-jdk virt-manager ufw \
apt-file python3-pip python3-lxml curl vim gimp jq picocom \
meld ssh zip git pv screen bmon pwgen xmlstarlet dos2unix \
debsecan lsof apt-show-versions sshfs binwalk rlwrap pavucontrol \
manpages-dev apt-mirror dislocker d-feet strace ltrace \
binutils-multiarch libguestfs-tools chromium memtest86+ \
tcpdump whois wireshark openvpn socat golang nano wget \
tshark traceroute apt-transport-https python3-requests tree

echo "Installing Sublime Text"
wget -qO - https://download.sublimetext.com/sublimehq-pub.gpg | apt-key add -
echo "deb https://download.sublimetext.com/ apt/stable/" | tee /etc/apt/sources.list.d/sublime-text.list
apt -y update
apt -y install sublime-text

echo "Disabling SSH"
systemctl disable --now ssh

echo "Enabling UFW"
ufw enable

echo "Updating apt-file database"
apt-file update

echo "Updating configurations"
(
    cat <<EOF
    dconf write /org/gnome/desktop/wm/preferences/focus-mode "'click'"
    dconf write /org/gnome/desktop/session/idle-delay 'uint32 3600'
    dconf write /org/gnome/settings-daemon/plugins/power/sleep-display-ac 3600
    dconf write /org/gnome/settings-daemon/plugins/power/sleep-display-battery 3600
    dconf write /org/gnome/settings-daemon/peripherals/touchpad/scroll-method "'two-finger-scrolling'"
    dconf write /org/gnome/settings-daemon/plugins/media-keys/max-screencast-length 3600
    dconf write /org/gnome/desktop/peripherals/touchpad/natural-scroll true
    dconf write /org/gnome/desktop/peripherals/touchpad/speed 0.2
    dconf write /org/gnome/desktop/peripherals/mouse/natural-scroll false
    dconf write /org/gnome/desktop/interface/clock-show-seconds "'true'"
    dconf write /org/gnome/desktop/interface/clock-show-weekday "'true'"
    gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'
    gsettings set org.gnome.desktop.media-handling automount false
    gsettings set org.gnome.desktop.media-handling automount-open false
    gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us'), ('xkb', 'fi')]"
    gsettings set org.gnome.desktop.interface show-battery-percentage true
    gsettings set org.gnome.desktop.interface enable-hot-corners false
    gsettings set org.gnome.desktop.interface clock-format 24h
    gsettings set org.gnome.desktop.calendar show-weekdate true
EOF
) | run_as_user bash

echo "Updating git information"
run_as_user git config --global user.name "Sanduuz"
run_as_user git config --global user.email "19jdmz5js@protonmail.ch"

echo "Modifying .bashrc"
run_as_user tee -a ~$NORMAL_USER/.bashrc <<EOF
export HISTTIMEFORMAT="%F %T "
export HISTFILESIZE=5000000
export HISTSIZE=100000

alias la="ls -al"
bind '"\C-H": backward-kill-word'
bind '"\t": menu-complete'
bind "set show-all-if-ambiguous on"
bind "set menu-complete-display-prefix on"
EOF

echo "Modifying .nanorc"
run_as_user tee -a ~$NORMAL_USER/.nanorc <<EOF
include /usr/share/nano/*.nanorc

set tabsize 4
set tabstospaces
set constantshow
set softwrap
set linenumbers

bind ^H cutwordleft main
EOF