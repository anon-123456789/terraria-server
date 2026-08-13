#!/bin/bash
set -euo pipefail

SERVER_FIFO=$(mktemp -u)

stop() {
    echo "SIGTERM requested, Sending exit command to server..."
    echo -e "\nexit" > "${SERVER_FIFO}"
}

CMD="./TerrariaServer -x64 -config /config/serverconfig.txt -banlist /config/banlist.txt"

# Create default config files if they don't exist
if [ ! -f "/config/serverconfig.txt" ]; then
    cp ./serverconfig-default.txt /config/serverconfig.txt
fi

if [ ! -f "/config/banlist.txt" ]; then
    touch /config/banlist.txt
fi

# Link Worlds folder to /config so it will save to the correct location
if [ ! -s "/root/.local/share/Terraria/Worlds" ]; then
    mkdir -p /root/.local/share/Terraria
    ln -sT /config /root/.local/share/Terraria/Worlds
fi

# Pass in world if set
if [ "${world:-null}" != null ]; then
    if [ ! -f "/config/$world" ]; then
        echo "World file does not exist! Quitting..."
        exit 1
    fi
    CMD="$CMD -world /config/$world"
fi

# Create a fifo that we can write to send commands to the server
mkfifo "${SERVER_FIFO}"
echo "Server fifo is set to ${SERVER_FIFO}"

# Docker sends us a SIGTERM when the container stops, so trap it to actually shutdown the server cleanly
echo "Trapping SIGTERM..."
trap "stop" SIGTERM

echo "Starting container, CMD: $CMD $@"
exec $CMD $@ < <(tail -f "${SERVER_FIFO}" & cat /dev/tty)

echo "Removing server fifo ${SERVER_FIFO}"
rm -f "${SERVER_FIFO}"
