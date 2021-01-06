#!/bin/sh

#         DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE 
#                     Version 2, December 2004 
# 
#  Copyright (C) 2004 Sam Hocevar <sam@hocevar.net> 
# 
#  Everyone is permitted to copy and distribute verbatim or modified 
#  copies of this license document, and changing it is allowed as long 
#  as the name is changed. 
# 
#             DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE 
#    TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION 
# 
#   0. You just DO WHAT THE FUCK YOU WANT TO.

# Author: Albakham <dev@geber.ga>
# Dependencies: curl

REPO="deluan/navidrome"
DIRECTORY="/opt/navidrome/"
USER="navidrome"

help() {
    EXIT=${1:-1}

    cat<<EOF
Simple navidrome installer and updater

Usage: $0 [option]
  -h|--help     Print this help
EOF

    exit ${EXIT}
}

new_version() {
    actual_version=v$(/opt/navidrome/navidrome -v | sed 's/ .*//')

    [ "$latest_version" = "$actual_version" ] && {
        echo "ERROR: Already to latest version, exiting..."
        exit 1
    }
}

install() {
    curl -LO "https://github.com/deluan/navidrome/releases/download/$latest_version/navidrome_${latest_version#?}_Linux_x86_64.tar.gz"

    source_sum=$(curl -L "https://github.com/deluan/navidrome/releases/download/$latest_version/navidrome_checksums.txt" |
        grep "navidrome_${latest_version#?}_Linux_x86_64.tar.gz")
    download_sum=$(sha256sum "navidrome_${latest_version#?}_Linux_x86_64.tar.gz")

    [ "$source_sum" = "$download_sum" ] && echo "Checksum match!" || {
        echo "ERROR: Hash mismatch, exiting..."
	exit 1
    }

    [ $(getent passwd "$USER") ] || useradd --system "$USER" --home-dir "$DIRECTORY" --shell /usr/sbin/nologin/

    tar -xvzf "navidrome_${latest_version#?}_Linux_x86_64.tar.gz" -C "$DIRECTORY"
    chown -R "$USER". "$DIRECTORY"
}


systemd() {
    [ -f /etc/systemd/system/navidrome.service ] && systemctl restart navidrome || {
        cat > /etc/systemd/system/navidrome.service <<EOF
[Unit]
Description=Navidrome Music Server and Streamer compatible with Subsonic/Airsonic
After=remote-fs.target network.target
AssertPathExists=/opt/navidrome
[Install]
WantedBy=multi-user.target
[Service]
User=navidrome
Group=navidrome
Type=simple
ExecStart=/opt/navidrome/navidrome --configfile "/var/lib/navidrome/navidrome.toml"
WorkingDirectory=/var/lib/navidrome
TimeoutStopSec=20
KillMode=process
Restart=on-failure
DevicePolicy=closed
NoNewPrivileges=yes
PrivateTmp=yes
PrivateUsers=yes
ProtectControlGroups=yes
ProtectKernelModules=yes
ProtectKernelTunables=yes
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6
RestrictNamespaces=yes
RestrictRealtime=yes
SystemCallFilter=~@clock @debug @module @mount @obsolete @privileged @reboot @setuid @swap
ReadWritePaths=/var/lib/navidrome
ProtectSystem=strict
ProtectHome=true
EOF
        systemctl daemon-reload
	systemctl enable navidrome --now
    }
    systemctl status navidrome
}

latest_version=$(curl --silent "https://api.github.com/repos/$REPO/releases/latest" |
    grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' )

[ -f "$DIRECTORY/navidrome" ] && new_version
[ -d "$DIRECTORY" ] && rm -Rf "$DIRECTORY"
mkdir -p "$DIRECTORY"

install
systemd
