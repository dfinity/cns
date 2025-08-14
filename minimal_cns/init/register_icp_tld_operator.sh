#!/usr/bin/env bash

source "$(dirname "$0")/common.sh"

controller_id=$(dfx identity get-principal)
domain_name=".icp."
record_type="NC"
tld_operator_id=$(dfx canister id tld_operator)

registration_record=$(registration_records_did $domain_name $record_type $tld_operator_id)
# echo ... ${registration_record}
# ~/bin/didc encode -d spec.did --types "(text, RegistrationRecords)"  '("'$domain_name'", '"$registration_record"')'
log "--- calling cns_root.register: "
dfx canister call cns_root register '("'$domain_name'", '"$registration_record"')'
