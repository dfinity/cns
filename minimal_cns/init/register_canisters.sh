#!/usr/bin/env bash
# Registers canisters with the CNS (Canister Naming Service).
set -euo pipefail
source "$(dirname "$0")/common.sh"

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
    log "... Registering $domain_name with canister ID $canister_id"

    record_type="CID"
    registration_record=$(registration_records_did $domain_name $record_type $canister_id)
    # echo ... ${registration_record}
    # ~/bin/didc encode -d spec.did --types "(text, RegistrationRecords)"  '("'$domain_name'", '"$registration_record"')'

    dfx canister call tld_operator register '("'$domain_name'", '"$registration_record"')'
done
