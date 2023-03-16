#!/bin/bash
set -e
set -x

run_as_user() {
    local cmd="$@"
    local _UID=$(getent passwd $NORMAL_USER | cut -d: -f3)
    DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$_UID/bus su --whitelist-environment=DBUS_SESSION_BUS_ADDRESS - $NORMAL_USER -c "cd $(pwd) && $cmd"
}

if [ "$1" ]; then
    NORMAL_USER="$1"
else
    NORMAL_USER="sanduuz"
fi

if [ "$UID" != "0" ]; then
    echo "This tool needs to be run as root!" 1>&2
    exit 1
fi

DATA_DIRECTORY="DATA"

if [ ! -d "$DATA_DIRECTORY" ]; then
    echo "ERROR: Directory 'DATA' does not exist." 1>&2
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

echo "Configuring WireShark"
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
tshark traceroute apt-transport-https python3-requests \
tree pass gdb axel

echo "Installing python modules"
python3 -m pip install requests flake8

echo "Installing Sublime Text"
wget -qO - https://download.sublimetext.com/sublimehq-pub.gpg | apt-key add -
echo "deb https://download.sublimetext.com/ apt/stable/" | tee /etc/apt/sources.list.d/sublime-text.list
apt -y update
apt -y install sublime-text

echo "Installing Sublime Text plugins"
if [ ! -d "~$NORMAL_USER/.config" ]; then
    echo "WARNING: ~$NORMAL_USER/.config directory does not exist. Creating..." 1>&2
    mkdir ~$NORMAL_USER/.config
fi

echo "Running st_helper.py"
python3 helpers/st_helper.py

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
run_as_user git config --global user.email "sanduuz@iki.fi"

echo "Modifying .bashrc"
run_as_user tee -a ~$NORMAL_USER/.bashrc <<EOF
export HISTTIMEFORMAT="%F %T "
export HISTFILESIZE=5000000
export HISTSIZE=100000

alias la="ls -al"
alias grep="grep --color=auto"
alias less="less -r"
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

bind ^H chopwordleft main
EOF

echo "Modifying .dircolors"
run_as_user tee -a ~$NORMAL_USER/.dircolors <<EOF
DIR 01;94
EOF

echo "Adding SSH ControlMaster to SSH config"
if [ ! -d "~$NORMAL_USER/.ssh/cm_socket" ]; then
    echo "WARNING: ~$NORMAL_USER/.ssh/cm_socket directory does not exist. Creating..." 1>&2
    mkdir -p ~$NORMAL_USER/.ssh/cm_socket
fi

run_as_user tee -a ~$NORMAL_USER/.ssh/config <<EOF
host *
    controlmaster auto
    controlpath ~/.ssh/cm_socket/ssh-%r@%h:%p
    serveraliveinterval 60
EOF

echo "Installing Python Exploit Development Assistance for GDB"
if [ ! -d "~$NORMAL_USER/bin" ]; then
    echo "WARNING: ~$NORMAL_USER/bin directory does not exist. Creating..." 1>&2
    mkdir -p ~$NORMAL_USER/bin
fi

run_as_user git clone https://github.com/longld/peda.git ~/bin/peda
echo "source ~/bin/peda/peda.py" >> ~$NORMAL_USER/.gdbinit

echo "Installing volatility3"
python3 -m pip install $DATA_DIRECTORY/wheels/volatility3-2.4.0-py3-none-any.whl
ln -s /usr/local/bin/vol /usr/local/bin/volatility3

echo "Installing volatility2"
run_as_user unzip -d ~$NORMAL_USER/bin/ $DATA_DIRECTORY/volatility_2.6_lin64_standalone.zip
ln -s ~$NORMAL_USER/bin/volatility_2.6_lin64_standalone/volatility_2.6_lin64_standalone /usr/local/bin/volatility2

echo "It is now recommended to restart your computer."
