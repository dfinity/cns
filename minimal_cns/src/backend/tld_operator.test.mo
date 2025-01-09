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

  func as_text(maybe_text : ?Text) : Text {
    return Option.get(maybe_text, "");
  };

  func is_eq_int(actual : Int, expected : Int, errMsg : ?Text) : Bool {
    let is_eq = actual == expected;
    if (not is_eq) {
      Debug.print("Values not equal: actual " # debug_show (actual) # ", expected: " # debug_show (expected) # "; error: " # as_text(errMsg));
    };
    return is_eq;
  };

  func msg_has_substr(msg : Text, substr : Text, errMsg : ?Text) : Bool {
    let has_substr = Text.contains(msg, #text substr);
    if (not has_substr) {
      Debug.print("Expected substing '" # substr # "' not found in message '" # msg # "', error: " # as_text(errMsg));
    };
    return has_substr;
  };

  func is_true(actual : Bool, errMsg : ?Text) : Bool {
    if (not actual) {
      Debug.print("Unexpected false value, error: " # as_text(errMsg));
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
      let errMsg = ?("shouldNotLookupNonregisteredIcpDomain() failed for domain: " # domain # ", recordType: " # recordType);
      assert is_eq_int(response.answers.size(), 0, errMsg);
      assert is_eq_int(response.additionals.size(), 0, errMsg);
      assert is_eq_int(response.authorities.size(), 0, errMsg);
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
      assert is_true(registerResponse.success, registerResponse.message);

      let lookupResponse = await IcpTldOperator.lookup(domain, recordType);
      let errMsg = ?("shouldRegisterAndLookupIcpDomain() failed for domain: " # domain # ", recordType: " # recordType);
      assert is_eq_int(lookupResponse.answers.size(), 1, errMsg);
      assert is_eq_int(lookupResponse.additionals.size(), 0, errMsg);
      assert is_eq_int(lookupResponse.authorities.size(), 0, errMsg);

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
      let errMsg = ?("shouldNotRegisterNonIcpDomain() failed for domain: " # domain);
      assert is_true(not response.success, errMsg);
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
      let errMsg = ?("shouldNotRegisterIfInconsistentDomainRecord() failed for domain: " # domain);
      assert is_true(not response.success, errMsg);
      assert msg_has_substr(as_text(response.message), "Inconsistent domain record", errMsg);
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
      let errMsg = ?("shouldNotRegisterDomainIfNotController() failed for domain: " # domain);
      assert is_true(not response.success, errMsg);
      assert msg_has_substr(as_text(response.message), "only a canister controller can register", errMsg);
    };
  };

};
