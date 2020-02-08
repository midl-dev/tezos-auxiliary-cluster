#!/bin/sh
# is the number of tezos peer to peer network connections greater than zero ?
[ "$(wget -qO - http://localhost:8732/network/connections | jq '. | length')" -gt 0 ]
