import CnsRoot "canister:cns_root";

actor {
    public func runTests() : async () {
        await shouldGetIcpTldOperator();
        await shouldNotGetOtherTldOperator();
    };

    let icp_tld_canister_id = "qoctq-giaaa-aaaaa-aaaea-cai";

    func shouldGetIcpTldOperator() : async () {
        for ((domain, record_type) in [(".icp", "NC"), ("example.icp", "NC"), ("another.ICP", "nc")].vals()) {
            let response = await CnsRoot.lookup(domain, record_type);
            assert (response.answers.size() == 1);
            let domain_record = response.answers[0];
            assert (domain_record.name == ".icp.");
            assert (domain_record.record_type == "NC");
            assert (domain_record.ttl == 3600);
            assert (domain_record.data == icp_tld_canister_id);
        };
    };

    func shouldNotGetOtherTldOperator() : async () {
        for ((domain, record_type) in [(".fun", "NC"), ("example.com", "NC"), ("another.dfn", "NS"), ("", "NC")].vals()) {
            let response = await CnsRoot.lookup(domain, record_type);
            assert (response.answers.size() == 0);
        };
    };

};
