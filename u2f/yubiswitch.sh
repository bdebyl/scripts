#!/bin/sh
{ usage="$(cat)"; }<<'EOF'
USAGE
    yubiswitch.sh [OPTION]

DESCRIPTION
    Script for enabling, disabling, or toggling your Yubikey using xinput to
    control device state.

OPTIONS
    -h, --help          Shows this usage prompt
    -t, --toggle        Toggles the Yubikey enabled state
    -d, --disable       Disables the Yubikey device
    -e, --enable        Enables the Yubikey device
EOF

die() {
    printf '%s\n' "$1" >&2
    exit 1
}

show_help() {
    printf '%s\n' "$usage"
    exit
}

# Check prerequisites
if [ ! "$(command -v perl)" ]; then
    die 'perl not installed -- exiting'
fi

if [ ! "$(command -v xinput)" ]; then
    die 'xinput not installed -- exiting'
fi

get_yubikey_id() {
    printf '%s' \
      "$(xinput --list | perl -lne 'print $1 if /[Yy]ubikey.*id=(\d+)/')"
}

get_yubikey_state() {
    id="$(get_yubikey_id)"
    printf '%s' "$(xinput --list-props "$id" | perl -lne 'print $1 if /Device Enabled.*(\d)$/')"
}

set_yubikey() {
    if [ -z "$1" ]; then
       die 'ERROR: no value provided to set_yubikey'
    fi

    xinput --set-prop "$(get_yubikey_id)" 'Device Enabled' "$1"
}

toggle_yubikey() {
    case "$(get_yubikey_state)" in
        '1')
            set_yubikey 0
            ;;
        '0')
            set_yubikey 1
            ;;
        *)
            die 'ERROR: Yubikey state unknown!'
            ;;
    esac
}

case $1 in
    -h|-\?|--help)
        show_help
        ;;
    -e|--enable)
        printf 'Enabling Yubikey\n'
        set_yubikey '1'
        ;;
    -d|--disable)
        printf 'Disabling Yubikey\n'
        set_yubikey '0'
        ;;
    -t|--toggle)
        printf 'Toggling Yubikey\n'
        toggle_yubikey
        ;;
    -?*)
        printf 'ERROR: Unknown option (ignored): %s\n' "$1" >&2
        ;;
    *)
        show_help
        ;;
esac
