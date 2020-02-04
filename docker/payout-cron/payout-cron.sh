#!/bin/sh

set -e
set -x

current_cycle_num=$(curl "https://api.tzstats.com/explorer/cycle/head" | jq -r '.cycle')
current_cycle_start_height=$(curl "https://api.tzstats.com/explorer/cycle/head" | jq -r '.start_height')

#look for payment to self
# for hodl.farm, we delegate the payout address to ourselves so it makes sense
# TODO: make it pick a random delegate address instead
number_of_payments=$(curl "https://api.tzstats.com/explorer/account/$HOT_WALLET_PUBLIC_KEY/op?type=transaction&since=$current_cycle_start_height" | jq --arg payout_address $HOT_WALLET_PUBLIC_KEY -r ' [ .ops | .[] | select(.receiver == $payout_address and .sender == $payout_address) ] | length ')

if [ "$number_of_payments" -ne 0 ]; then
    printf "We checked the blockchain using tzstats and already found a payment\n"
    printf "Payout for cycle $current_cycle_num appears to have already been done, exiting\n"
    exit 0

else
    printf "No payment operation found in current cycle, launching backerei in no-dry-run mode for current cycle $current_cycle_num\n"

fi

# configure tezos client connectivity to tezos node
/usr/local/bin/tezos-client -p $PROTOCOL_SHORT -d /var/run/tezos/client -A tezos-public-node-rpc -P 8732 config init -o /var/run/tezos/client/config

# import payout key into tezos-client
/usr/local/bin/tezos-client -p $PROTOCOL_SHORT -c /var/run/tezos/client/config import secret key k8s-payer unencrypted:$HOT_WALLET_PRIVATE_KEY -f

/usr/local/bin/backerei --config /var/run/backerei/config/backerei.yaml init \
--host tezos-public-node-rpc \
--tz1 $PUBLIC_BAKING_KEY \
--from $HOT_WALLET_PUBLIC_KEY \
--from-name k8s-payer \
--database-path /var/run/backerei/payouts/payouts.json \
--client-path /usr/local/bin/tezos-client \
--client-config-file /var/run/tezos/client/config \
--starting-cycle $current_cycle_num \
--cycle-length $CYCLE_LENGTH \
--snapshot-interval $SNAPSHOT_INTERVAL \
--preserved-cycles $PRESERVED_CYCLES \
--payout-delay $PAYOUT_DELAY \
--pay-estimated-rewards \
--fee $PAYOUT_FEE

/usr/local/bin/backerei --config /var/run/backerei/config/backerei.yaml payout --no-password
