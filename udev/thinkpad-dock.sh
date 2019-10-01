#!/bin/sh -e
username="bdebyl"

read -r cmd_mobile <<EOF
/usr/bin/xrandr \
    --output HDMI-3 --off \
    --output LVDS-1 --auto --primary
EOF

read -r cmd_docked <<EOF
/usr/bin/xrandr \
    --output LVDS-1 --off \
    --output HDMI-3 --auto --primary --pos 0x0
EOF

if [ "$ACTION" = "add" ]; then
    DOCKED=1 && logger -t DOCKING "Detected condition: docked"
elif [ "$ACTION" = "remove" ]; then
    DOCKED=0 && logger -t DOCKING "Detected condition: un-docked"
else
    logger -t DOCKING "Detected condition: unknown"
    printf "Please set env var %s to 'add' or 'remove'" "$ACTION"
    exit 1
fi

switch_to_local()
{
    export DISPLAY=$1
    logger -t DOCKING "Switching off HDMI and switching on LVDS"
    su "$username" -c "$cmd_mobile"
}

switch_to_external()
{
    export DISPLAY=$1
    if [ "$(su "$username" -c '/usr/bin/xrandr' | awk '/ connected / && ! /LVDS/ { print $0 }')" ]; then
        logger -t DOCKING "Switching off LVDS and switching on HDMI"
        su "$username" -c "$cmd_docked"
    else
        logger -t DOCKING "No external display detected; leaving LVDS display on"
    fi
}

case "$DOCKED" in
    "0")
        switch_to_local :0 ;;
    "1")
        switch_to_external :0 ;;
esac
