#!/usr/bin/env bash

help() {
    echo "usage: $0 [OPTIONS]"
    echo "       $0 --uninstall"
    echo "       $0 --help"
    echo
    echo "OPTIONS:"
    echo "  -H,--homebridge <HOMEBRIDGE>    Homebridge stoarge path. Default is"
    echo "                                  /var/lib/homebridge."
    echo "  -n,--network <NETWORK>          Docker network to use. Default is host."
    echo "  -u,--uninstall                  Uninstall the files and reload the system."
    echo "  -h,--help                       Print this help menu."
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

SYSTEMD="/etc/systemd/system"
DOCKER_IMAGE="homebridge-docker"
DOCKER_SERVICE="$DOCKER_IMAGE@.service"
UNIT_DEST_PATH="$SYSTEMD/$DOCKER_SERVICE"
if [ -f UNIT_DEST_PATH ]; then
    echo "Stopping $DOCKER_SERVICE..."
    sudo systemctl stop "$DOCKER_IMAGE@*" --all
fi
echo "Removing $DOCKER_SERVICE..."
sudo rm -rf "$UNIT_DEST_PATH"

if ! "$UNINSTALL"; then
    echo "Installing $DOCKER_SERVICE.."
    sed "s#{{HOMEBRIDGE}}#$HOMEBRIDGE#g;s#{{NETWORK}}#$NETWORK#g" \
        "$DOCKER_SERVICE" | sudo tee "$UNIT_DEST_PATH" >/dev/null
fi

sudo systemctl daemon-reload

echo "...Done!"
