#!/bin/sh
CHECKIP_RE="[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+"

{ usage="$(cat)"; }<<'EOF'
aws-route53-ddns.sh -z|--zone-id <value> -H|--host <value> [OPTIONS]

DESCRIPTION
    Shell script wrapper for AWS Route53 for use in updating a DNS
    record. Designed for the use case of a DDNS host to update a hostname for a
    non-static IP.

    For setting up AWS it is recommended you use a user with a limited policy:
        {
          "Version": "2012-10-17"
          "Statement": [
            {
              "Effect": Allow",
              "Action": [
                "route53:TestDNSAnswer",
                "route53:ChangeResourceRecordSets",
              ],
              "Resource": "*"
            }
          ]
        }

OPTIONS
    -d                 Debug flag; avoids reaching out to Route53
    -H, --host         Hostname to be updated (e.g. "myhome.example.net")
    -z, --zone-id      AWS Zone ID for where the hostname record exists
EOF

cleanup() {
    if [ -n "$tempfile" ]; then
        rm "$tempfile"
    fi
}

die() {
    printf '%s\n' "$1" >&2
    cleanup; exit 1
}

show_help() {
    printf '%s\n' "$usage"
    exit
}

# Check prerequisites
if [ ! "$(command -v jq)" ]; then
    die 'jq not installed -- exiting'
fi

if [ ! "$(command -v aws)" ]; then
    die 'awscli python package not installed -- exiting'
fi


while :; do
    case $1 in
        -h|-\?|--help)
            show_help
            exit
            ;;
        -H|--hostname)
            if [ "$2" ]; then
                ddns_hostname=$2
                shift
            else
                die 'ERROR: "--host" requires a non-empty option argument!'
            fi
            ;;
        -z|--zone-id)
            if [ "$2" ]; then
                zone_id=$2
                shift
            else
                die 'ERROR: "--zone-id" reuqires a non-empty option argument!'
            fi
            ;;
        -d|--debug)
            debug=1
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
if [ -z "$ddns_hostname" ]; then
    die 'ERROR: hostname not specified (see -h/--help)'
fi

if [ -z "$zone_id" ]; then
    die 'ERROR: zone id not specifieid (see -h/--help)'
fi

checkip_ans="$(curl --silent checkip.dyndns.org 2>&1 | grep -Eo "$CHECKIP_RE")"
if [ -z "$checkip_ans" ]; then
    die 'ERROR: received bad answer from checkip.dyndns.org (check connection?)'
fi

if [ "$debug" ]; then
    test_dns_ans="$checkip_ans"
else
    test_dns="$(aws route53 test-dns-answer --hosted-zone-id "$zone_id" \
                --record-name "$ddns_hostname" --record-type "A")"
    test_dns_ans="$(echo "$test_dns" | jq '.RecordData[0]' | sed 's/"//g')"
fi

if [ -z "$test_dns_ans" ]; then
    die 'ERROR: received bad ansewr from Route 53 (check aws config?)'
fi

tempfile="$(mktemp --suffix=.json)"

{ update_json="$(cat)"; } <<EOF
{
  "Comment": "Update DDNS home A record",
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "$ddns_hostname",
        "Type": "A",
        "TTL": 3600,
        "ResourceRecords": [
          {
            "Value": "$checkip_ans"
          }
        ]
      }
    }
  ]
}
EOF

if [ "$debug" ]; then
    printf 'DEBUG: json output\n%s\n' "$update_json"
fi

# Perform update
if [ "$checkip_ans" != "$test_dns_ans" ]; then
    printf 'Record out of date -- attempting update\n'
    if [ "$debug" ]; then
        echo 1
    else
        printf '%s' "$update_json" > "$tempfile"
        aws route53 change-resource-record-sets --hosted-zone-id "$zone_id" \
            --change-batch "file://$tempfile"
    fi

    # Directly checking exit code using 'if $(aws ...)' is invalid for python
    # based aws-cli
    # shellcheck disable=SC2181
    if [ "$?" -eq "0" ]; then
        printf 'Record updated succesfully!\n'
    else
        die 'ERROR: issue encountered during update attempt!'
    fi
else
    printf 'Record up to date -- nothing to do\n'
fi

cleanup
