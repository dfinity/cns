import CnsRoot "canister:cns_root";
import Nat32 "mo:base/Nat32";
import Option "mo:base/Option";
import Test "../test_utils";
import Types "cns_types";

actor {
  public func runTests() : async () {
    // The order of tests matters.
    await shouldNotGetIcpTldOperatorBeforeRegistration();
    await shouldRegisterIcpTldOperator();
    await shouldGetIcpTldOperatorForNcIcpLookupsAfterRegistration();
    await shouldGetIcpTldOperatorForOtherIcpLookupsAfterRegistration();
    // shouldRegisterAndLookupIcpTld() overwrites the previously registered operator.
    await shouldRegisterAndLookupIcpTld();
    await shouldNotGetOtherTldOperator();
    await shouldNotRegisterTldIfDomainNotTld();
    await shouldNotRegisterTldIfNotDotIcpDot();
    await shouldNotRegisterTldIfMissingDomainRecord();
    await shouldNotRegisterTldIfMultipleDomainRecords();
  };

  public func runTestsIfNotController() : async () {
    await shouldNotRegisterTldIfNotController();
  };

  func asText(maybeText : ?Text) : Text {
    return Option.get(maybeText, "");
  };

  let dummyIcpTldCanisterId = "qoctq-giaaa-aaaaa-aaaea-cai";

  func shouldNotGetIcpTldOperatorBeforeRegistration() : async () {
    let response = await CnsRoot.lookup(".icp", "NC");
    let errMsg = "shouldNotGetIcpTldOperatorBeforeRegistration() failed checking the size of response.";
    assert Test.isEqualInt(response.answers.size(), 0, errMsg # "answers");
    assert Test.isEqualInt(response.additionals.size(), 0, errMsg # "additionals");
    assert Test.isEqualInt(response.authorities.size(), 0, errMsg # "authorities");
  };

  func shouldRegisterIcpTldOperator() : async () {
    let domainRecord : Types.DomainRecord = {
      name = ".icp.";
      record_type = "NC";
      ttl = 3600;
      data = dummyIcpTldCanisterId;
    };
    let registrationRecords = {
      controller = [];
      records = ?[domainRecord];
    };
    let registerResponse = await CnsRoot.register(".icp.", registrationRecords);
    assert Test.isTrue(registerResponse.success, asText(registerResponse.message));
  };

  func shouldGetIcpTldOperatorForNcIcpLookupsAfterRegistration() : async () {
    for (
      (domain, recordType) in [
        (".icp.", "NC"),
        ("example.icp.", "NC"),
        ("another.ICP.", "nc"),
        ("one.more.Icp.", "Nc"),
      ].vals()
    ) {
      let response = await CnsRoot.lookup(domain, recordType);
      let errMsg = "shouldGetIcpTldOperatorForNcIcpLookupsAfterRegistration() failed for domain: " # domain # ", recordType: " # recordType # "; ";
      assert Test.isEqualInt(response.answers.size(), 1, errMsg # "size of response.answers");
      assert Test.isEqualInt(response.additionals.size(), 0, errMsg # "size of response.additionals");
      assert Test.isEqualInt(response.authorities.size(), 0, errMsg # "size of response.authorities");
      let domainRecord = response.answers[0];
      assert Test.isEqualText(domainRecord.name, ".icp.", errMsg # "field: DomainRecord.name");
      assert Test.isEqualText(domainRecord.record_type, "NC", errMsg # "field: DomainRecord.record_type");
      assert Test.isEqualInt(Nat32.toNat(domainRecord.ttl), 3600, errMsg # "field: DomainRecord.ttl");
      assert Test.isEqualText(domainRecord.data, dummyIcpTldCanisterId, errMsg # "field: DomainRecord.data");
    };
  };

  func shouldGetIcpTldOperatorForOtherIcpLookupsAfterRegistration() : async () {
    for (
      (domain, recordType) in [
        (".icp.", "CID"),
        ("example.icp.", "Cid"),
        ("another.ICP.", "cid"),
        ("one.more.Icp.", "CId"),
        ("another.example.icp.", "NS"),
        ("yet.another.one.icp.", "WeirdReordType"),
      ].vals()
    ) {
      let response = await CnsRoot.lookup(domain, recordType);
      let errMsg = "shouldGetIcpTldOperatorForOtherIcpLookupsAfterRegistration() failed for domain: " # domain # ", recordType: " # recordType # "; ";
      assert Test.isEqualInt(response.answers.size(), 0, errMsg # "size of response.answers");
      assert Test.isEqualInt(response.additionals.size(), 0, errMsg # "size of response.additionals");
      assert Test.isEqualInt(response.authorities.size(), 1, errMsg # "size of response.authorities");
      let domainRecord = response.authorities[0];
      assert Test.isEqualText(domainRecord.name, ".icp.", errMsg # "field: DomainRecord.name");
      assert Test.isEqualText(domainRecord.record_type, "NC", errMsg # "field: DomainRecord.record_type");
      assert Test.isEqualInt(Nat32.toNat(domainRecord.ttl), 3600, errMsg # "field: DomainRecord.ttl");
      assert Test.isEqualText(domainRecord.data, dummyIcpTldCanisterId, errMsg # "field: DomainRecord.data");
    };
  };

  func shouldNotGetOtherTldOperator() : async () {
    for (
      (domain, recordType) in [
        (".fun.", "NC"),
        ("example.com.", "NC"),
        ("another.dfn.", "NS"),
        ("", "NC"),
        (".", "CID"),
        ("one.more.dfn.", "CID"),
      ].vals()
    ) {
      let response = await CnsRoot.lookup(domain, recordType);
      let errMsg = "shouldNotGetOtherTldOperator() failed for domain: " # domain # ", recordType: " # recordType # "; size of response.";
      assert Test.isEqualInt(response.answers.size(), 0, errMsg # "answers");
      assert Test.isEqualInt(response.additionals.size(), 0, errMsg # "additionals");
      assert Test.isEqualInt(response.authorities.size(), 0, errMsg # "sauthorities");
    };
  };

  func shouldRegisterAndLookupIcpTld() : async () {
    for (
      (tld, recordType) in [
        (".icp.", "NC"),
        (".ICP.", "Nc"),
        (".iCP.", "nC"),
        (".Icp.", "nc"),
      ].vals()
    ) {
      let someData = "canister-id-for-" # tld # "-" # recordType;
      let domainRecord : Types.DomainRecord = {
        name = tld;
        record_type = recordType;
        ttl = 3600;
        data = someData;
      };
      let registrationRecords = {
        controller = [];
        records = ?[domainRecord];
      };
      let registerResponse = await CnsRoot.register(tld, registrationRecords);
      assert Test.isTrue(registerResponse.success, asText(registerResponse.message));

      let lookupResponse = await CnsRoot.lookup(tld, recordType);
      let errMsg = "shouldRegisterAndLookupIcpTld() failed for TLD: " # tld # ", recordType: " # recordType # ", size of response.";
      assert Test.isEqualInt(lookupResponse.answers.size(), 1, errMsg # "answers");
      assert Test.isEqualInt(lookupResponse.additionals.size(), 0, errMsg # "additionals");
      assert Test.isEqualInt(lookupResponse.authorities.size(), 0, errMsg # "authorities");

      let responseDomainRecord = lookupResponse.answers[0];
      assert (responseDomainRecord == domainRecord);
    };
  };

  func shouldNotRegisterTldIfNotController() : async () {
    for (
      (tld) in [
        (".icp."),
        (".com."),
        ("my_domain.icp."),
        ("example.org."),
      ].vals()
    ) {
      let domainRecord : Types.DomainRecord = {
        name = tld;
        record_type = "NC";
        ttl = 3600;
        data = "aaa-aaaa";
      };
      let registrationRecords = {
        controller = [];
        records = ?[domainRecord];
      };
      let response = await CnsRoot.register(tld, registrationRecords);
      let errMsg = "shouldNotRegisterTldIfNotController() failed for domain: " # tld;
      assert Test.isTrue(not response.success, errMsg);
      assert Test.textContains(asText(response.message), "only a canister controller can register", errMsg);
    };
  };

  func shouldNotRegisterTldIfDomainNotTld() : async () {
    for (
      (domain) in [
        ("example.icp."),
        ("longer.domain.com."),
      ].vals()
    ) {
      let domainRecord : Types.DomainRecord = {
        name = domain;
        record_type = "NC";
        ttl = 3600;
        data = "aaa-aaaa";
      };
      let registrationRecords = {
        controller = [];
        records = ?[domainRecord];
      };
      let response = await CnsRoot.register(domain, registrationRecords);
      let errMsg = "shouldNotRegisterTldIfDomainNotTld() failed for domain: " # domain;
      assert Test.isTrue(not response.success, errMsg);
      assert Test.textContains(asText(response.message), "is not a TLD", errMsg);
    };
  };

  func shouldNotRegisterTldIfNotDotIcpDot() : async () {
    for (
      (tld) in [
        (".fun."),
        (".com."),
        (".org."),
      ].vals()
    ) {
      let domainRecord : Types.DomainRecord = {
        name = tld # ".";
        record_type = "NC";
        ttl = 3600;
        data = "aaa-aaaa";
      };
      let registrationRecords = {
        controller = [];
        records = ?[domainRecord];
      };
      let response = await CnsRoot.register(tld, registrationRecords);
      let errMsg = "shouldNotRegisterTldIfNotDotIcpDot() failed for TLD: " # tld;
      assert Test.isTrue(not response.success, errMsg);
      assert Test.textContains(asText(response.message), "only .icp.-TLD is supported", errMsg);
    };
  };

  func shouldNotRegisterTldIfMissingDomainRecord() : async () {
    let response = await CnsRoot.register(".icp.", { controller = []; records = null });
    let errMsg = "shouldNotRegisterTldIfMissingDomainRecord() failed";
    assert Test.isTrue(not response.success, errMsg);
    assert Test.textContains(asText(response.message), "exactly one domain record", errMsg);
  };

  func shouldNotRegisterTldIfMultipleDomainRecords() : async () {
    let domainRecord : Types.DomainRecord = {
      name = ".icp.";
      record_type = "NC";
      ttl = 3600;
      data = "aaa-aaaa";
    };
    let registrationRecords = {
      controller = [];
      records = ?[domainRecord, domainRecord];
    };
    let response = await CnsRoot.register(".icp.", registrationRecords);
    let errMsg = "shouldNotRegisterTldIfMultipleDomainRecords() failed for two DomainRecords";
    assert Test.isTrue(not response.success, errMsg);
    assert Test.textContains(asText(response.message), "exactly one domain record", errMsg);
  };
};
