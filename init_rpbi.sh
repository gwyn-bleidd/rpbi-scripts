#!/bin/bash


# Raspberry init script Grafana Dashboards
# run with sudo
# last modified: 17.01.2025


# check for root user

if [ "$EUID" -ne 0 ]
  then echo "Only root user script"
  exit
fi


# STEP 1 install libs

apt-get install -y openconnect x11-xserver-utils unclutter xxd


#STEP 2 enter credentials for vpn

# Prompt for user input
read -p "Enter vpn server: " vpnserver
read -p "Enter your username: " user
read -sp "Enter your password: " password
echo
read -p "Enter your OTP(hex): " otp

# convert otp from hex to base32

decoded_string=$(echo -n "$otp" | xxd -r -p)

base32_otp=$(echo -n "$decoded_string" | base32)

# Test the connection using openconnect
echo "Testing connection..."
echo "$password" | sudo openconnect $vpnserver -u "$user" --token-mode=totp --token-secret="base32:$base32_otp" --background --pid-file=/tmp/openconnect.pid


if [ $? -eq 0 ]; then
    echo "Connection successful!"

    # Create the systemd service file
    service_file="/etc/systemd/system/init_vpn.service"

    echo "Creating systemd service file at $service_file..."


template="[Unit]
Description=Connect to VPN
After=network.target

[Service]
Type=simple
ExecStart=/bin/sh -c \"echo '$password' | sudo openconnect $vpnserver -u $user --token-mode=totp --token-secret=base32:$base32_otp\"
Restart=always
RestartSec=15

[Install]
WantedBy=multi-user.target"


    printf "%s\n" "$template" > "$service_file"

    echo "Service file created successfully."

    sudo systemctl daemon-reload
    sudo systemctl enable init_vpn
    sudo systemctl start init_vpn
    echo "VPN daemon started"
else
    echo "Connection failed. Please check your credentials and try again."
    # exit 1
fi

# Clean up vpn connect process
if [ -f /tmp/openconnect.pid ]; then
    sudo kill -9 $(cat /tmp/openconnect.pid)
    cat /tmp/openconnect.pid
    rm /tmp/openconnect.pid
fi

echo "next_steps"



# STEP 3 check session type


#echo $XDG_SESSION_TYPE

#if [ "$XDG_SESSION_TYPE" = "wayland" ]; then
#    echo "Session type is Wayland. Everything OK"
#else
#    echo "Session type is not Wayland"
#    exit 1
#fi


# STEP 4  turn off sleep mode


lightdm_file="/etc/lightdm/lightdm.conf"

template="[LightDM]
#start-default-seat=true
#
[Seat:*]
xserver-backend=wayland
xserver-command= X -s 0 -dpms
greeter-session=pi-greeter-labwc
greeter-hide-users=false
user-session=LXDE-pi-labwc
display-setup-script=/usr/share/dispsetup.sh
autologin-user=ops
autologin-session=LXDE-pi-labwc
[XDMCPServer]

[VNCServer]
#enabled=false"


printf "%s\n" "$template" > "$lightdm_file"

echo "LightDM configured."





# STEP 5 configure start script

xdg_file="/etc/xdg/lxsession/LXDE-pi/autostart"

template="
#@lxpanel --profile LXDE-pi
#@pcmanfm --desktop --profile LXDE-pi
#@xscreensaver -no-splash
@xset s off
@xset -dpms
@xset s noblank
@chromium --kiosk https://watch.sca.ad-tech.ru"


printf "%s\n" "$template" > "$xdg_file"

echo "Autostart script configured."

