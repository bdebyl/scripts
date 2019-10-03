#!/bin/sh
{ usage="$(cat)" ; } <<'EOF'
USAGE
    ACTION=[add|remove] thinkpad-dock.sh [OPTIONS]
DESCRIPTION
    This script is to be run as part of a udev rule for when docking the
    laptop. Switches to the next available external display that is not the
    native display (defaults to LVDS-1 if not modified).

    User defaults to first active user listed for '$(users)'

    The udev rule should be placed in /etc/udev/rules.d/ with a higher priority
    number prefix (e.g. 71-thinkpad-dock.rules)

OPTIONS
    -h, --help         Show this help prompt

EXAMPLE UDEV RULE
    SUBSYSTEM=="usb", ACTION=="add", ENV{ID_MODEL}=="100a",
                      ENV{ID_VENDOR}=="17ef",
                      RUN+="/usr/local/bin/thinkpad-dock.sh"
    SUBSYSTEM=="usb", ACTION=="remove", ENV{DEVTYPE}=="usb_interface",
                      ENV{PRODUCT}=="17ef/100a/0",
                      RUN+="/usr/local/bin/thinkpad-dock.sh"
EOF

die() {
    printf '%s\n' "$1" >&2
    exit 1
}

show_help() {
    printf '%s\n' "$usage"
    exit
}

username="$(users | awk '{print $1;exit;}')"

disp_native='LVDS-1'
while :; do
    case $1 in
        -h|-\?|--help)
            show_help
            exit
            ;;
        --)
            shift
            break
            ;;
        -?*)
            printf 'WARN: Unknown option (ignored): %s\n' "$1" >&2
            ;;
        *)
            break
            ;;
    esac

    shift
done

if [ -z "$username" ]; then
    die 'ERROR: username undefined (are any users logged in?)'
fi

switchdisp() {
    # Allow some time for the interface to fully switch over
    sleep 1

    DISPLAY=:0 su "$username" -c \
           "xrandr --output $1 --auto --primary --output $2 --off"
}

disp_extern="$(xrandr | awk '(!/LVDS/ && / connected/){print $1;exit;}')"

case $ACTION in
    'add')
        switchdisp "$disp_extern" "$disp_native"
        ;;
    'remove')
        switchdisp "$disp_native" "$disp_extern"
        ;;
    *)
        printf 'ERROR: Unknown, or no value for ACTION passed\n'
        show_help
        ;;
esac
