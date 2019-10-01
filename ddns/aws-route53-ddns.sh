#!/bin/bash
LOGGER_TAG="[AWS Route 53 DDNS]"

CHECKIP_HOST="checkip.dyndns.org"
CHECKIP_RE="[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+"

# Check prerequisites
if [ ! "$(command -v jq)" ]; then
    logger -t "$LOGGER_TAG" "q'jq' not installed -- exiting"
    exit 1
fi

if [ ! "$(command -v aws)" ]; then
    logger -t "$LOGGER_TAG" "'awscli' python package not installed -- exiting"
    exit 1
fi

# Check expected env vars present
if [ -z "$ZONE_ID" ]; then
    logger -t "$LOGGER_TAG" "ZONE_ID not provided -- exiting"
    exit 1
fi

if [ -z "$DDNS_HOSTNAME" ]; then
    logger -t "$LOGGER_TAG" "DDNS_HOSTNAME not provided -- exiting"
    exit 1
fi

CHECKIP="$(curl --silent "$CHECKIP_HOST" 2>&1 | grep -Eo "$CHECKIP_RE")"
ROUTE53_TEST="$(aws route53 test-dns-answer --hosted-zone-id "$ZONE_ID" --record-name "$DDNS_HOSTNAME" --record-type "A")"
ROUTE53_IP="$(echo $ROUTE53_TEST | jq '.RecordData[0]' | sed 's/"//g')"

UPDATE_FILE="/tmp/aws-route53-ddns-update.json"

UPDATE_CMD=$(cat <<EOF
{
  "Comment": "Update DDNS home A record",
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "$DDNS_HOSTNAME",
        "Type": "A",
        "TTL": 3600,
        "ResourceRecords": [
          {
            "Value": "$CHECKIP"
          }
        ]
      }
    }
  ]
}
EOF
)

if [ "$CHECKIP" != "$ROUTE53_IP" ]; then
    logger -t "$LOGGER_TAG" "Record out of date -- attempting update"
    echo "$UPDATE_CMD" > "$UPDATE_FILE"
    aws route53 change-resource-record-sets --hosted-zone-id "$ZONE_ID" --change-batch "file://$UPDATE_FILE"
    if [ $? -eq 0 ]; then
        logger -t "$LOGGER_TAG" "Record updated succesfully!"
        exit 0
    else
        logger -t "$LOGGER_TAG" "Error encountered during update attempt!"
        exit 1
    fi
else
    logger -t "$LOGGER_TAG" "Record up to date --nothing to do"
    exit 0
fi
