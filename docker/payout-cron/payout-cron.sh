#!/bin/sh
# Copyright 2021 - MIDL.dev

set -e
set -x

printf "Starting payout cronjob\n"
current_cycle_num=$(curl "https://api.tzstats.com/explorer/cycle/head" | jq -r '.cycle')
current_cycle_start_height=$(curl "https://api.tzstats.com/explorer/cycle/head" | jq -r '.start_height')

if [ -z "${EXTERNAL_NODE_RPC}" ]; then
    NODE_RPC="${KUBERNETES_NAME_PREFIX}-tezos-public-node-0.${KUBERNETES_NAME_PREFIX}-tezos-public-node"
    NODE_RPC_PORT=8732
else
    # terminate https locally since backerei does not support https d'oh!
    socat tcp-listen:8733,reuseaddr,fork ssl:mainnet-tezos.giganode.io:443 &
    NODE_RPC="localhost"
    NODE_RPC_PORT=8733
fi

printf "configure tezos client connectivity to tezos node\n"
/usr/local/bin/tezos-client -p $PROTOCOL_SHORT -d /var/run/tezos/client --endpoint "http://${NODE_RPC}:${NODE_RPC_PORT}" config init -o /var/run/tezos/client/config

printf "import payout key into tezos-client\n"
/usr/local/bin/tezos-client -p $PROTOCOL_SHORT -c /var/run/tezos/client/config import secret key k8s-payer unencrypted:$HOT_WALLET_PRIVATE_KEY -f

config_backerei() {
  if [ "${PAYOUT_STARTING_CYCLE}" -gt "$1" ]; then
      printf "Configured starting cycle higher than requested cycle, adjusting for that\n"
      backerei_starting_cycle=${PAYOUT_STARTING_CYCLE}
  else
      backerei_starting_cycle=$1
  fi
  printf "configuring backerei with starting-cycle $backerei_starting_cycle\n"
  /home/tezos/backerei --config /var/run/backerei/config/backerei.yaml init \
  --host ${NODE_RPC} \
  --port ${NODE_RPC_PORT} \
  --tz1 $PUBLIC_BAKING_KEY \
  --from $HOT_WALLET_PUBLIC_KEY \
  --from-name k8s-payer \
  --database-path /var/run/backerei/payouts/payouts.json \
  --client-path /usr/local/bin/tezos-client \
  --client-config-file /var/run/tezos/client/config \
  --starting-cycle $backerei_starting_cycle \
  --cycle-length $CYCLE_LENGTH \
  --snapshot-interval $SNAPSHOT_INTERVAL \
  --preserved-cycles $PRESERVED_CYCLES \
  --payout-delay $PAYOUT_DELAY \
  --pay-estimated-rewards \
  --fee "$PAYOUT_FEE"
}

printf "For dry-run, set starting-cycle to just finalized cycle - no risk of accidental payout\n"
config_backerei $((current_cycle_num - 1))

printf "wait for node to be bootstrapped\n"
/usr/local/bin/tezos-client -d /var/run/tezos/client bootstrapped

printf "Launching in dry-run mode to perform calculations\n"
/home/tezos/backerei --config /var/run/backerei/config/backerei.yaml payout --no-password

if ! curl -f "https://api.tzstats.com/explorer/account/$HOT_WALLET_PUBLIC_KEY"
then
    printf "Hot wallet does not exist on-chain yet, not performing actual payout operation.\n"
    exit 0
fi

# Check whether payment has been done already.
# Search for any payout from the payout address to the witness address.
# Do not set the payout address and the witness address as the same address. Backerei indeed sends a payment to the payout address itself but there is no guarantee that tzstats api will see it as such.
number_of_payments=$(curl "https://api.tzstats.com/explorer/account/$WITNESS_PAYOUT_ADDRESS/operations?type=transaction&since=$current_cycle_start_height" | jq --arg sender_address $HOT_WALLET_PUBLIC_KEY --arg receiver_address $WITNESS_PAYOUT_ADDRESS -r ' [ .[] | select(.receiver == $receiver_address and .sender == $sender_address) ] | length ')

if [ "$number_of_payments" -ne 0 ]; then
    printf "We checked the blockchain using tzstats and already found a payment from the payout address $HOT_WALLET_PUBLIC_KEY to the witness address $WITNESS_PAYOUT_ADDRESS after height $current_cycle_start_height\n"
    printf "We conclude that the payout supposed to happen during cycle $current_cycle_num appears to have already been done, exiting\n"
    exit 0

else

    printf "No payment operation found in current cycle from the payout address $HOT_WALLET_PUBLIC_KEY to the witness address $WITNESS_PAYOUT_ADDRESS, launching backerei in no-dry-run mode for current cycle $current_cycle_num (if DRY_RUN env var is set to false)\n"

fi

# Note: this was a secondary check. Even if we proceed, backerei is supposed to have recorded its payouts in its database and will just exit.
# But it has shown to not be 100% effective in a k8s environment.

printf "For actual payout, reconfigure backerei with a starting-cycle equal to the cycle for which we are doing payouts to prevent accidental payout of old cycles\n"
config_backerei $(($current_cycle_num - 6 - $PAYOUT_DELAY))

if [ "${DRY_RUN}" == "false" ]; then
    printf "Actually sending payout\n"
    /home/tezos/backerei --config /var/run/backerei/config/backerei.yaml payout --no-password --no-dry-run
else
    printf "Would have sent payout here if \$DRY_RUN was false"
fi

printf "Payout cronjob complete\n"
