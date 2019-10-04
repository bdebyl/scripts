#!/bin/sh
{ usage="$(cat)" ; }<<'EOF'
USAGE
    taglog.sh [-t|--tag] <tag> [OPTIONS]

DESCRIPTION
    Returns a formatted list of all git tags until the specified -t/--tag value
    is found.

OPTIONS
    -h, --help              Shows this usage prompt
    -t, --tag               Tag string to search for (e.g. '1.0.0')
    -P, --path              Path to git directory to search

EXAMPLE
    TODO
EOF

die() {
    printf '%s\n' "$1" >&2
    exit 1
}

show_help() {
    printf '%s\n' "$usage"
    exit
}

taglog() {
    tmplog="$(mktemp)"
    printf '%s' "$(git  -C "${gitdir:-"$(pwd)"}" log --no-walk --tags --oneline --pretty="%D %s")" > "$tmplog"
    while read -r line; do
        if printf '%s' "$line" | grep -q "$tag"; then
            break
        else
            printf '%s' "$line" | perl -nE '/tag: ([\w.]+).*from\s+\w+\/(\w+\-\d+|noticket)_(.*)/ && say "| $1 | $2 | $3 |"'
        fi
    done < "$tmplog"

    rm "$tmplog"
}

while :; do
    case $1 in
        -h|-\?|--help)
            show_help
            exit
            ;;
        -t|--tag)
            if [ "$2" ]; then
                tag=$2
                shift
            else
                die 'ERROR: tag requires a non-empty option argument!'
            fi
            ;;
        -P|--path)
            if [ "$2" ]; then
                gitdir=$2
                shift
            else
                die 'ERROR: path requires a non-empty option argument!'
            fi
            ;;
        --)
            shift
            break
            ;;
        -?*)
            printf 'WARN: Unknown option (ignore): %s\n' "$1" >&2
            ;;
        *)
            break
            ;;
    esac

    shift
done

if [ -z "$tag" ]; then
    printf 'ERROR: required tag option unspecified!'
    show_help
fi

taglog "$tag"
