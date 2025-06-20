#!/bin/sh

# System Maintenance
echo "🔧 Performing system cleanup and upgrades..."
sudo apt update -y && \
sudo apt upgrade -y && \
sudo apt full-upgrade -y && \
sudo apt --fix-broken install -y && \
sudo apt autoremove -y && \
sudo apt autoclean -y && \
sudo apt clean -y && \
sudo updatedb

# Reconfigure unattended upgrades
sudo dpkg-reconfigure --priority=low unattended-upgrades

# Show installed packages
clear
echo "📦 Installed packages:"
echo ""
apt list --installed

# Package removal loop
while true; do
    echo ""
    read -p "❓ Enter package name to remove (leave blank to exit): " PACKAGE_REMOVE
    [ -z "$PACKAGE_REMOVE" ] && break

    # Match and purge matching packages
    MATCHED=$(apt list --installed 2>/dev/null | grep "^$PACKAGE_REMOVE/" | cut -d "/" -f 1)
    if [ -z "$MATCHED" ]; then
        echo "⚠️  Package '$PACKAGE_REMOVE' not found."
    else
        echo "🔥 Removing package: $MATCHED"
        sudo apt purge -y "$MATCHED"
    fi

    echo ""
    apt list --installed
done

echo "Done."
