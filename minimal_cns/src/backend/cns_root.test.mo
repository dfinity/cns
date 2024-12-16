import CnsRoot "canister:cns_root";

actor {
  public func runTests() : async () {
    await shouldGetIcpTldOperatorForNcIcpLookups();
    await shouldGetIcpTldOperatorForOtherIcpLookups();
    await shouldNotGetOtherTldOperator();
  };

  let icpTldCanisterId = "qoctq-giaaa-aaaaa-aaaea-cai";

  func shouldGetIcpTldOperatorForNcIcpLookups() : async () {
    for (
      (domain, recordType) in [
        (".icp", "NC"),
        ("example.icp", "NC"),
        ("another.ICP", "nc"),
        ("one.more.Icp", "Nc"),
      ].vals()
    ) {
      let response = await CnsRoot.lookup(domain, recordType);
      assert (response.answers.size() == 1);
      assert (response.additionals.size() == 0);
      assert (response.authorities.size() == 0);
      let domainRecord = response.answers[0];
      assert (domainRecord.name == ".icp.");
      assert (domainRecord.record_type == "NC");
      assert (domainRecord.ttl == 3600);
      assert (domainRecord.data == icpTldCanisterId);
    };
  };

  func shouldGetIcpTldOperatorForOtherIcpLookups() : async () {
    for (
      (domain, recordType) in [
        (".icp", "CID"),
        ("example.icp", "Cid"),
        ("another.ICP", "cid"),
        ("one.more.Icp", "CId"),
        ("another.example.icp", "NS"),
        ("yet.another.one.icp", "WeirdReordType"),
      ].vals()
    ) {
      let response = await CnsRoot.lookup(domain, recordType);
      assert (response.answers.size() == 0);
      assert (response.additionals.size() == 0);
      assert (response.authorities.size() == 1);
      let domainRecord = response.authorities[0];
      assert (domainRecord.name == ".icp.");
      assert (domainRecord.record_type == "NC");
      assert (domainRecord.ttl == 3600);
      assert (domainRecord.data == icpTldCanisterId);
    };
  };

  func shouldNotGetOtherTldOperator() : async () {
    for (
      (domain, recordType) in [
        (".fun", "NC"),
        ("example.com", "NC"),
        ("another.dfn", "NS"),
        ("", "NC"),
        ("one.more.dfn", "CID"),
      ].vals()
    ) {
      let response = await CnsRoot.lookup(domain, recordType);
      assert (response.answers.size() == 0);
      assert (response.additionals.size() == 0);
      assert (response.authorities.size() == 0);
    };
  };

};
