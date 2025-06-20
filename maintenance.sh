#!/bin/bash

# set -e

# Function: List nonessential, manually installed packages
list_nonessential_packages() {
    echo "Scanning for nonessential manually installed packages..."
    echo ""

    comm -23 \
      <(apt-mark showmanual | sort) \
      <(grep -E "^(Essential: yes|Priority: (required|important|standard))" -B1 /var/lib/dpkg/status | grep "^Package:" | cut -d " " -f 2 | sort) \
      | while read -r pkg; do
          desc=$(dpkg -s "$pkg" 2>/dev/null | grep -i "^Description:" | cut -d ":" -f2-)
          printf "%-40s %s\n" "$pkg" "$desc"
      done
}

# Function: Estimate package size
estimate_package_size() {
    apt-cache show "$1" 2>/dev/null | grep "^Installed-Size:" | awk '{print $2 " KB"}'
}

# --- Maintenance section ---
echo "Performing system cleanup and upgrades..."
sudo apt update -y
sudo apt upgrade -y
sudo apt full-upgrade -y
sudo apt --fix-broken install -y
sudo apt autoremove -y
sudo apt autoclean -y
sudo apt clean -y
sudo updatedb
sudo dpkg-reconfigure --priority=low unattended-upgrades

# --- Show nonessential packages ---
clear
echo "Nonessential packages that may be safely removed:"
echo ""
list_nonessential_packages

# --- Interactive removal loop ---
while true; do
    echo ""
    read -rp "Enter package name to remove (leave blank to exit): " PACKAGE_REMOVE
    [ -z "$PACKAGE_REMOVE" ] && break

    MATCHED=$(apt list --installed 2>/dev/null | grep "^$PACKAGE_REMOVE/" | cut -d "/" -f 1)
    if [ -z "$MATCHED" ]; then
        echo "Package '$PACKAGE_REMOVE' is not installed."
    else
        SIZE=$(estimate_package_size "$MATCHED")
        echo "Package: $MATCHED"
        echo "Estimated size to free: $SIZE"
        read -rp "Are you sure you want to remove it? [y/N]: " CONFIRM
        if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
            echo "Removing $MATCHED..."
            sudo apt purge -y "$MATCHED"
            sudo apt autoremove -y
        else
            echo "Skipped."
        fi
    fi

    echo ""
    echo "Remaining nonessential packages:"
    list_nonessential_packages
done

echo "Maintenance complete."
