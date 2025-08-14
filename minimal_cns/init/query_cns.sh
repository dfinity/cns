#!/usr/bin/env bash
# Queries CNS (Canister Naming Service) and verifies the responses.
set -euo pipefail
source "$(dirname "$0")/common.sh"


log ... metrics  before lookup calls:
dfx canister call tld_operator get_metrics '("hour")'

data_file="${1:-$(dirname "$0")/known_canisters.csv}"
log ... reading known canisters from $data_file

exec < $data_file
read header
while read line
do
    print_green "... read line : $line"
    domain_name=$(echo $line | cut -d, -f1)
    if [[ $domain_name != *. ]] ; then
        domain_name="$domain_name."   # Add a trailing dot if missing
    fi
    canister_id=$(echo $line | cut -d, -f2)
    log "    Querying .icp-operator for domain $domain_name ..."

    record_type="CID"
    response=`dfx canister call tld_operator lookup '("'$domain_name'", "'$record_type'")'`
    if [[ "$response" == *"$canister_id"* ]]; then
        log "    Found matching canister ID $canister_id for $domain_name"
    else
        err "    Did not find matching canister ID for $domain_name"
    fi

    log "    Querying .icp-operator with reverse-lookup for canister with id $canister_id ..."

    record_type="PTR"
    response=`dfx canister call tld_operator lookup '("'$canister_id.reverse.icp.'", "'$record_type'")'`
    if [[ "$response" == *"$domain_name"* ]]; then
        log "    Found matching domain name $domain_name for canister $canister_id"
    else
        err "    Did not find matching domain name for canister $canister_id"
    fi
done

log ... metrics after canister lookup calls:
dfx canister call tld_operator get_metrics '("hour")'

data_file="${1:-$(dirname "$0")/known_subnets.csv}"
log ... reading known subnets from $data_file

exec < $data_file
read header
while read line
do
    print_green "... read line : $line"
    domain_name=$(echo $line | cut -d, -f1)
    if [[ $domain_name != *. ]] ; then
        domain_name="$domain_name."   # Add a trailing dot if missing
    fi
    subnet_id=$(echo $line | cut -d, -f2)
    log "    Querying .icp-operator for subnet $domain_name ..."

    record_type="SID"
    response=`dfx canister call tld_operator lookup '("'$domain_name'", "'$record_type'")'`
    if [[ "$response" == *"$subnet_id"* ]]; then
        log "    Found matching subnet ID $subnet_id for $domain_name"
    else
        err "    Did not find matching subnet ID for $domain_name"
    fi

    log "    Querying .icp-operator with reverse-lookup for subnet with id $subnet_id ..."

    record_type="PTR"
    response=`dfx canister call tld_operator lookup '("'$subnet_id.reverse.icp.'", "'$record_type'")'`
    if [[ "$response" == *"$domain_name"* ]]; then
        log "    Found matching domain name $domain_name for subnet ID $subnet_id"
    else
        err "    Did not find matching domain name for subnet ID $subnet_id"
    fi
done

log ... metrics after subnet lookup calls:
dfx canister call tld_operator get_metrics '("hour")'