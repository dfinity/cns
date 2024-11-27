import NameRegistry "canister:name_registry";
import Text "mo:base/Text";

shared ({ caller = initializer }) actor class () {
    public shared func lookup(domain : Text, record_type : Text) : async NameRegistry.DomainLookup {
        let icp_tld : Text.Pattern = #text ".icp";
        let icp_tld_canister_id = "qoctq-giaaa-aaaaa-aaaea-cai";

        var answers : [NameRegistry.DomainRecord] = [];
        let domain_lowercase = Text.toLowercase(domain);
        let record_type_uppercase = Text.toUppercase(record_type);
        if (record_type_uppercase == "NC" and Text.endsWith(domain_lowercase, icp_tld)) {
            answers := [{
                name = ".icp.";
                record_type = "NC";
                ttl = 3600;
                data = icp_tld_canister_id;
            }];
        };

        {
            answers = answers;
            additionals = [];
            authorities = [];
        };
    };
};
