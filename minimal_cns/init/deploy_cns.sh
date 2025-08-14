#!/usr/bin/env bash
DFX_NETWORK=${DFX_NETWORK:-local}

MY_DIR=$(dirname "$0")
source "$MY_DIR/common.sh"

identity=$(dfx identity get-principal)
log "INFO: Deploying CNS and TLD operator canisters to network '${DFX_NETWORK}'"
log "INFO: Using identity: $identity"
do_you_want_to_continue
log "----- deploying cns_root"
dfx deploy --no-wallet --network ${DFX_NETWORK} cns_root
log "----- deploying tld_operator"
dfx deploy --no-wallet --network ${DFX_NETWORK} tld_operator

log "----- registering tld_operator with cns_root"
"$MY_DIR/register_icp_tld_operator.sh"
log "----- registering known canisters"
"$MY_DIR/register_canisters.sh"
log "----- registering known subnets"
"$MY_DIR/register_subnets.sh"
log "DONE deploying CNS and registering canisters and subnets."


