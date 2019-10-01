#!/usr/bin/env bash
EXITCODE=0
PASSDIR=$HOME/.password-store

declare -A pws
declare -A pwdupes
declare -A pwunsafe

CRACKLIB=$(command -v cracklib-check)
declare -A pwscracklib

# Colorized printf macro
colprintf()
{
    printf "%s%s%s" "$(tput setaf "$1")" "$2" "$(tput sgr0)"
}

# Formatted colprintf macro
colblurb()
{
    printf "%s %s\n" "$(colprintf "$1" "$2")" "$3"
}

# Indented printf macro
indentblurb()
{
    printf "\t%s %s %s\n" "$2" "$1" "$3"
}

# Checks for duplicate sha1sums of passwords in the associative array
checkdupes()
{
    for i in "${!pws[@]}"; do
        if [[ "$2" == "${pws[$i]}" ]]; then
            pwdupes["$1"]="$i"
        fi
    done
}

# Fetches all passwords in $PASSDIR and checks for duplicates (base check)
getpws()
{
    # Loop over the find (newline-in-filename safe)
    while read -r -d '' p; do
        # Remove the root directory, and file extension
        p=$(printf "%s" "$p" | sed "s|^$PASSDIR/||" | sed "s/.gpg//")
        # Collect the trimmed, sha1 passwords
        pwsha=$(pass "$p" | awk 'FNR==1 {printf "%s", $0}' | sha1sum | awk '{printf "%s", toupper($1)}')
        checkdupes "$p" "$pwsha"
        pws["$p"]="$pwsha"
    done < <(find "$PASSDIR" -name "*.gpg" -type f -print0)
}

# Run through the global pws associative array and check for suggestions
checkcracklib()
{
    for i in "${!pws[@]}"; do
        msg=$(pass "$i" | awk 'FNR==1 {printf "%s", $0}' | $CRACKLIB | sed s/^.*:[\ \\t]*//)

        if [[ ! "$msg" =~ "OK" ]]; then
            pwscracklib["$i"]="$msg"
        fi
    done
}

# Check passwords against the HIBP password API (requires internet)
checkpwnapi()
{
    for i in "${!pws[@]}"; do
        # Check the pwnedpasswords API via hashing
        pwsha="${pws[$i]}"
        url="https://api.pwnedpasswords.com/range/${pwsha:0:5}"
        res=$(curl -s "$url" | grep "${pwsha:5}")
        if [ "$res" ]; then
            pwunsafe["$i"]=$(printf "%s" "$res" | awk -F ':' '{printf "%d", $2}')
        fi
    done
}

main()
{
    indentblurb "Fetching passwords and checking for duplicates" ">" "..."
    getpws
    if [[ "$CRACKLIB" ]]; then
        indentblurb "Checking passwords using cracklib" ">" "..."
        checkcracklib
    else
        indentblurb "Skipped cracklib check (missing dependency: cracklib)" ">" "..."
    fi
    indentblurb "Checking for compromised passwords" ">" "..."
    checkpwnapi
}


#  _ __ _   _ _ __
# | '__| | | | '_ \
# | |  | |_| | | | |
# |_|   \__,_|_| |_|
#
colblurb 4 "[INFO]" "Beginning password checks"
main

# Report duplicate password(s)
if [ "${pwdupes[@]}" ]; then
    colblurb 1 "[WARN]" "Duplicate passwords found:"
    for i in "${!pwdupes[@]}"; do indentblurb "MATCHES" "$i" "${pwdupes[$i]}"; done
    EXITCODE=1
else
    colblurb 2 "[GOOD]" "No duplicate passwords"
fi

# Report unsafe/compromised password(s)
if [ "${pwunsafe[@]}" ]; then
    colblurb 1 "[WARN]" "Compromised passwords:"
    for i in "${!pwunsafe[@]}"; do indentblurb "EXPOSED COUNT" "$i" "${pwunsafe[$i]}"; done
    EXITCODE=1
else
    colblurb 2 "[GOOD]" "No compromised passwords"
fi

# Report weak password(s) if cracklib is installed
if [[ "$CRACKLIB" ]]; then
    if [ "${pwscracklib[@]}" ]; then
        colblurb 4 "[INFO]" "Passwords that should be improved:"
        for i in "${!pwscracklib[@]}"; do indentblurb "suggested change:" "$i" "${pwscracklib[$i]}"; done
    else
        colblurb 2 "[GOOD]" "No passwords to improve"
    fi
fi

exit $EXITCODE
