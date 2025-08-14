#!/usr/bin/env bash
# Registers canisters with the CNS (Canister Naming Service).
set -euo pipefail
source "$(dirname "$0")/common.sh"

data_file="${1:-$(dirname "$0")/known_subnets.csv}"
echo ... reading known subnets from $data_file

exec < $data_file
read header
while read line
do
    print_green "    read line: $line"
    subnet_name=$(echo $line | cut -d, -f1)
        if [[ $subnet_name != *. ]] ; then
        subnet_name="$subnet_name."   # Add a trailing dot if missing
    fi
    subnet_id=$(echo $line | cut -d, -f2)
    log "... Registering subnet $subnet_name with ID $subnet_id"

    record_type="SID"
    registration_record=$(registration_records_did $subnet_name $record_type $subnet_id)
    # echo ... ${registration_record}
    # ~/bin/didc encode -d spec.did --types "(text, RegistrationRecords)"  '("'$subnet_name'", '"$registration_record"')'

    dfx canister call tld_operator register '("'$subnet_name'", '"$registration_record"')'
done
