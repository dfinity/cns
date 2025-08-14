#! /usr/bin/env bash


print_red() {
    echo -e "\033[0;31m$*\033[0m" 1>&2
}

print_green() {
    echo -e "\033[0;32m$*\033[0m" 1>&2
}

print_blue() {
    echo -e "\033[0;34m$*\033[0m" 1>&2
}

log() {
    print_blue "$@"
}

err() {
    print_red "$@"
}

do_you_want_to_continue() {
    echo ""
    read -r -p "Do you want to continue? [y/N] " response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        print_green "continuing..."
    else
        print_red "aborting..."
        exit 1
    fi
}

registration_records_with_controllers_did() {
    local controller_id=$1
    local domain_name=$2
    local record_type=$3
    local data=$4

    echo  'record { controllers = vec {
            record {
                controller_id = principal "'$controller_id'"; 
                roles = vec { variant {registrant} }
            }
        };
        records = opt vec { 
            record {
                name = "'$domain_name'";
                record_type = "'$record_type'";
                ttl = 86400;
                data = "'$data'"
            } 
        } 
    }'
}

registration_records_did() {
    local domain_name=$1
    local record_type=$2
    local data=$3

    echo  'record { controllers = vec {
        };
        records = opt vec { 
            record {
                name = "'$domain_name'";
                record_type = "'$record_type'";
                ttl = 86400;
                data = "'$data'"
            } 
        } 
    }'
}