#!/bin/sh
# Copyright 2020 - Hodl.farm

set -e
set -x

printf "Starting payout cronjob\n"
current_cycle_num=$(curl "https://api.tzstats.com/explorer/cycle/head" | jq -r '.cycle')
current_cycle_start_height=$(curl "https://api.tzstats.com/explorer/cycle/head" | jq -r '.start_height')

# Check whether payment has been done already.
# Search for any payout from the payout address to the witness address.
# It is fine if the payout address and the witness address are the same. Backerei will send a payment from and to the same address. The result will be 2.
number_of_payments=$(curl "https://api.tzstats.com/explorer/account/$HOT_WALLET_PUBLIC_KEY/op?type=transaction&since=$current_cycle_start_height" | jq --arg sender_address $HOT_WALLET_PUBLIC_KEY --arg receiver_address $WITNESS_PAYOUT_ADDRESS -r ' [ .ops | .[] | select(.receiver == $receiver_address and .sender == $sender_address) ] | length ')

if [ "$number_of_payments" -ne 0 ]; then
    printf "We checked the blockchain using tzstats and already found a payment from the payout address $HOT_WALLET_PUBLIC_KEY to the witness address $WITNESS_PAYOUT_ADDRESS\n"
    printf "We conclude that the payout supposed to happen during cycle $current_cycle_num appears to have already been done, exiting\n"
    exit 0

else

    printf "No payment operation found in current cycle from the payout address $HOT_WALLET_PUBLIC_KEY to the witness address $WITNESS_PAYOUT_ADDRESS, launching backerei in no-dry-run mode for current cycle $current_cycle_num\n"

fi

# Note: this was a secondary check. Even if we proceed, backerei is supposed to have recorded its payouts in its database and will just exit.
# But it has shown to not be 100% effective in a k8s environment.

printf "configure tezos client connectivity to tezos node\n"
/usr/local/bin/tezos-client -p $PROTOCOL_SHORT -d /var/run/tezos/client -A tezos-public-node-rpc -P 8732 config init -o /var/run/tezos/client/config

printf "import payout key into tezos-client\n"
/usr/local/bin/tezos-client -p $PROTOCOL_SHORT -c /var/run/tezos/client/config import secret key k8s-payer unencrypted:$HOT_WALLET_PRIVATE_KEY -f

printf "configuring backerei\n"
/home/tezos/backerei --config /var/run/backerei/config/backerei.yaml init \
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
--fee "$PAYOUT_FEE"

printf "wait for node to be bootstrapped\n"
/usr/local/bin/tezos-client -d /var/run/tezos/client bootstrapped

printf "Sending out payment\n"
/home/tezos/backerei --config /var/run/backerei/config/backerei.yaml payout --no-password

printf "Payout cronjob complete\n"
