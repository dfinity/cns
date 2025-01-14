import CnsRoot "canister:cns_root";
import Test "../test_utils"

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
      let errMsg = "shouldGetIcpTldOperatorForNcIcpLookups() failed for domain: " # domain # ", recordType: " # recordType # "; ";
      assert Test.isEqualInt(response.answers.size(), 1, errMsg # "size of response.answers");
      assert Test.isEqualInt(response.additionals.size(), 0, errMsg # "size of response.additionals");
      assert Test.isEqualInt(response.authorities.size(), 0, errMsg # "size of response.authorities");
      let domainRecord = response.answers[0];
      assert Test.isEqualText(domainRecord.name, ".icp.", errMsg # "field: DomainRecord.name");
      assert Test.isEqualText(domainRecord.record_type, "NC", errMsg # "field: DomainRecord.record_type");
      assert Test.isEqualInt(domainRecord.ttl, 3600, errMsg # "field: DomainRecord.ttl");
      assert Test.isEqualText(domainRecord.data, icpTldCanisterId, errMsg # "field: DomainRecord.data");
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
      let errMsg = "shouldGetIcpTldOperatorForOtherIcpLookups() failed for domain: " # domain # ", recordType: " # recordType # "; ";
      assert Test.isEqualInt(response.answers.size(), 0, errMsg # "size of response.answers");
      assert Test.isEqualInt(response.additionals.size(), 0, errMsg # "size of response.additionals");
      assert Test.isEqualInt(response.authorities.size(), 1, errMsg # "size of response.authorities");
      let domainRecord = response.authorities[0];
      assert Test.isEqualText(domainRecord.name, ".icp.", errMsg # "field: DomainRecord.name");
      assert Test.isEqualText(domainRecord.record_type, "NC", errMsg # "field: DomainRecord.record_type");
      assert Test.isEqualInt(domainRecord.ttl, 3600, errMsg # "field: DomainRecord.ttl");
      assert Test.isEqualText(domainRecord.data, icpTldCanisterId, errMsg # "field: DomainRecord.data");
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
      let errMsg = "shouldNotGetOtherTldOperator() failed for domain: " # domain # ", recordType: " # recordType # "; size of response.";
      assert Test.isEqualInt(response.answers.size(), 0, errMsg # "answers");
      assert Test.isEqualInt(response.additionals.size(), 0, errMsg # "additionals");
      assert Test.isEqualInt(response.authorities.size(), 0, errMsg # "sauthorities");
    };
  };

};
