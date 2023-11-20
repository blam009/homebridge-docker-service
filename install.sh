#!/usr/bin/env bash

help() {
    echo "usage: $0 [OPTIONS]"
    echo "       $0 --uninstall"
    echo "       $0 --help"
    echo
    echo "OPTIONS:"
    echo "  -H,--homebridge <HOMEBRIDGE>        Homebridge stoarge path. Default is"
    echo "                                      /var/lib/homebridge."
    echo "  -n,--network <host|novpn-docker>    Docker network to use. Default is host."
    echo "  -u,--uninstall                      Uninstall the files and reload the system."
    echo "  -h,--help                           Print this help menu."
}

HOMEBRIDGE="/var/lib/homebridge"
NETWORK="host"
UNINSTALL=false
VALID_ARGS=$(getopt -o H:n:uh --long homebridge:,network:,uninstall,help -- "$@")
eval set -- "$VALID_ARGS"
while true; do
    case "$1" in
        -H | --homebridge)
            HOMEBRIDGE="$2"
            shift 2
            ;;
        -n | --network)
            NETWORK="$2"
            shift 2
            ;;
        -u | --uninstall)
            UNINSTALL=true
            shift
            ;;
        -h | --help)
            help
            shift
            exit 0
            ;;
        --) shift;
            break
            ;;
    esac
done

if [[ "$NETWORK" != "host" && "$NETWORK" != "novpn-docker" ]]; then
    echo "Error: Invalid network set: $NETWORK"
    help
    exit 1
fi

if [[ ! -d "$HOMEBRIDGE" ]]; then
    echo "Error: Invalid homebridge directory: $HOMEBRIDGE"
    help
    exit 1
fi

SYSTEMD="/etc/systemd/system"
IMAGE="homebridge-docker"
SERVICE="$IMAGE.service"
SERVICE_DEST_PATH="$SYSTEMD/$SERVICE"
if systemctl is-active "$SERVICE" --quiet; then
    echo "Stopping $SERVICE..."
    sudo systemctl stop "$SERVICE"
fi
if [[ "$(systemctl is-enabled "$SERVICE")" = "enabled" ]]; then
    echo "Disabling $SERVICE..."
    sudo systemctl disable "$SERVICE"
fi
if [ -f "$SERVICE_DEST_PATH" ]; then
    echo "Removing $SERVICE..."
    sudo rm -rf "$SERVICE_DEST_PATH"
fi
if ! "$UNINSTALL"; then
    echo "Pulling latest homebridge docker image..."
    docker pull homebridge/homebridge:latest
    echo "Installing $SERVICE..."

    SERVICE_TMP_PATH="/tmp/$SERVICE"
    cp "$SERVICE" "$SERVICE_TMP_PATH"

    echo "...Using homebridge path: $HOMEBRIDGE"
    sed "s#{{HOMEBRIDGE}}#$HOMEBRIDGE#g" -i "$SERVICE_TMP_PATH"

    echo "...Using network: $NETWORK"
    sed "s#{{NETWORK}}#$NETWORK#g" -i "$SERVICE_TMP_PATH"

    if [[ "$NETWORK" == "host" ]]; then
        sed "/NOVPN/d" -i "$SERVICE_TMP_PATH"
        printf "\n[Install]\nWantedBy=multi-user.target\n" >> "$SERVICE_TMP_PATH"
    elif [[ "$NETWORK" == "novpn-docker" ]]; then
        sed "s|{{NOVPN_RUNTIME_ENV}}|/var/run/novpn/env|g" -i "$SERVICE_TMP_PATH"
    fi

    sudo install -m644 "$SERVICE_TMP_PATH" "$SERVICE_DEST_PATH"
fi

sudo systemctl daemon-reload

if ! "$UNINSTALL" && grep -q '\[Install\]' "$SERVICE_DEST_PATH"; then
    echo "Enabling $SERVICE..."
    sudo systemctl enable "$SERVICE"
fi

echo "...Done!"
