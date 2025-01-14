import NameRegistry "canister:name_registry";
import IcpTldOperator "canister:tld_operator";
import Debug "mo:base/Debug";
import Option "mo:base/Option";
import Text "mo:base/Text";

actor {
  type DomainRecord = NameRegistry.DomainRecord;

  public func runTests() : async () {
    await shouldNotLookupNonregisteredIcpDomain();
    await shouldRegisterAndLookupIcpDomain();
    await shouldNotRegisterNonIcpDomain();
    await shouldNotRegisterIfInconsistentDomainRecord();
  };

  public func runTestsIfNotController() : async () {
    await shouldNotRegisterDomainIfNotController();
  };

  func asText(maybe_text : ?Text) : Text {
    return Option.get(maybe_text, "");
  };

  func isEqualInt(actual : Int, expected : Int, errMsg : Text) : Bool {
    let isEq = actual == expected;
    if (not isEq) {
      Debug.print("Expected Int: " # debug_show (expected) # ", got: " # debug_show (actual) # "; error: " # errMsg);
    };
    return isEq;
  };

  func textContains(text : Text, subText : Text, errMsg : Text) : Bool {
    let contains = Text.contains(text, #text subText);
    if (not contains) {
      Debug.print("Expected text '" # text # "' to contain '" # subText # "', error: " # errMsg);
    };
    return contains;
  };

  func isTrue(actual : Bool, errMsg : Text) : Bool {
    if (not actual) {
      Debug.print("Expected Bool to be true, error: " # errMsg);
    };
    return actual;
  };

  func shouldNotLookupNonregisteredIcpDomain() : async () {
    for (
      (domain, recordType) in [
        ("first.example.icp", "CID"),
        ("another.example.ICP", "CID"),
        ("other.domain.com", "CID"),
      ].vals()
    ) {
      let response = await IcpTldOperator.lookup(domain, recordType);
      let errMsg = "shouldNotLookupNonregisteredIcpDomain() failed for domain: " # domain # ", recordType: " # recordType # ", size of ";
      assert isEqualInt(response.answers.size(), 0, errMsg # "answers");
      assert isEqualInt(response.additionals.size(), 0, errMsg # "additionals");
      assert isEqualInt(response.authorities.size(), 0, errMsg # "authorities");
    };
  };

  func shouldRegisterAndLookupIcpDomain() : async () {
    for (
      (domain, recordType) in [
        ("my_domain.icp", "CID"),
        ("example.icp", "Cid"),
        ("another.ICP", "cid"),
        ("one.more.Icp", "CId"),
      ].vals()
    ) {
      let domainRecord : DomainRecord = {
        name = domain;
        record_type = "CID";
        ttl = 3600;
        data = "aaa-aaaa";
      };
      let registrationRecords = {
        controller = [];
        records = ?[domainRecord];
      };
      let registerResponse = await IcpTldOperator.register(domain, registrationRecords);
      assert isTrue(registerResponse.success, asText(registerResponse.message));

      let lookupResponse = await IcpTldOperator.lookup(domain, recordType);
      let errMsg = "shouldRegisterAndLookupIcpDomain() failed for domain: " # domain # ", recordType: " # recordType # ", size of ";
      assert isEqualInt(lookupResponse.answers.size(), 1, errMsg # "answers");
      assert isEqualInt(lookupResponse.additionals.size(), 0, errMsg # "additionals");
      assert isEqualInt(lookupResponse.authorities.size(), 0, errMsg # "authorities");

      let responseDomainRecord = lookupResponse.answers[0];
      assert (responseDomainRecord == domainRecord);
    };
  };

  func shouldNotRegisterNonIcpDomain() : async () {
    for (
      (domain) in [
        (".fun"),
        ("example.com"),
        ("another.dfn"),
        (""),
        ("one.more.dfn"),
      ].vals()
    ) {
      let domainRecord : DomainRecord = {
        name = domain;
        record_type = "CID";
        ttl = 3600;
        data = "aaa-aaaa";
      };
      let registrationRecords = {
        controller = [];
        records = ?[domainRecord];
      };
      let response = await IcpTldOperator.register(domain, registrationRecords);
      let errMsg = "shouldNotRegisterNonIcpDomain() failed for domain: " # domain;
      assert isTrue(not response.success, errMsg);
    };
  };

  func shouldNotRegisterIfInconsistentDomainRecord() : async () {
    for (
      (domain, record_name) in [
        ("some.name.icp", "other.domain.icp"),
        ("valid.subdomain.icp", "subdomain.icp"),
      ].vals()
    ) {
      let domainRecord : DomainRecord = {
        name = record_name;
        record_type = "CID";
        ttl = 3600;
        data = "aaa-aaaa";
      };
      let registrationRecords = {
        controller = [];
        records = ?[domainRecord];
      };
      let response = await IcpTldOperator.register(domain, registrationRecords);
      let errMsg = "shouldNotRegisterIfInconsistentDomainRecord() failed for domain: " # domain;
      assert isTrue(not response.success, errMsg);
      assert textContains(asText(response.message), "Inconsistent domain record", errMsg);
    };
  };

  func shouldNotRegisterDomainIfNotController() : async () {
    for (
      (domain) in [
        ("my_domain.icp"),
        ("example.icp"),
      ].vals()
    ) {
      let domainRecord : DomainRecord = {
        name = domain;
        record_type = "CID";
        ttl = 3600;
        data = "aaa-aaaa";
      };
      let registrationRecords = {
        controller = [];
        records = ?[domainRecord];
      };
      let response = await IcpTldOperator.register(domain, registrationRecords);
      let errMsg = "shouldNotRegisterDomainIfNotController() failed for domain: " # domain;
      assert isTrue(not response.success, errMsg);
      assert textContains(asText(response.message), "only a canister controller can register", errMsg);
    };
  };

};
