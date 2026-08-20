#!/bin/bash
set -euo pipefail

SERVER_PID=" "

echo "Removing server fifo /tmp/server.fifo"
rm -f "/tmp/server.fifo"

stop() {
    echo "SIGTERM requested, Sending exit command to server (PID ${SERVER_PID})..."
    echo -e "\nsay Server is going down NOW!\nexit" > "/tmp/server.fifo"
    wait ${SERVER_PID}
    echo "Server stopped successfully."
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
mkfifo "/tmp/server.fifo"
echo "Server fifo is set to /tmp/server.fifo"

# Docker sends us a SIGTERM when the container stops, so trap it to actually shutdown the server cleanly
echo "Trapping SIGTERM..."
trap "stop" SIGTERM

echo "Starting container, CMD: $CMD $@"
exec $CMD $@ < <(tail -f "/tmp/server.fifo" & cat /dev/tty) &
SERVER_PID=$(pgrep TerrariaServer)
echo "Server PID is ${SERVER_PID}"
wait ${SERVER_PID}
