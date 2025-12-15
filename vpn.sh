#!/usr/bin/env zsh

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 connect|disconnect"
    exit 1
fi

case "$1" in
    connect)
        echo "Connecting to VPN..."
        sudo wg-quick up wg0
        ;;
    disconnect)
        echo "Disconnecting from VPN..."
        sudo wg-quick down wg0
        ;;
    *)
        echo "Invalid argument: $1"
        echo "Usage: $0 connect|disconnect"
        exit 1
        ;;
esac
