import NameRegistry "canister:name_registry";
import IcpTldOperator "canister:tld_operator";
import Option "mo:base/Option";
import Text "mo:base/Text";
import Test "../test_utils"

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

  func asText(maybeText : ?Text) : Text {
    return Option.get(maybeText, "");
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
      let errMsg = "shouldNotLookupNonregisteredIcpDomain() failed for domain: " # domain # ", recordType: " # recordType # ", size of response.";
      assert Test.isEqualInt(response.answers.size(), 0, errMsg # "answers");
      assert Test.isEqualInt(response.additionals.size(), 0, errMsg # "additionals");
      assert Test.isEqualInt(response.authorities.size(), 0, errMsg # "authorities");
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
      assert Test.isTrue(registerResponse.success, asText(registerResponse.message));

      let lookupResponse = await IcpTldOperator.lookup(domain, recordType);
      let errMsg = "shouldRegisterAndLookupIcpDomain() failed for domain: " # domain # ", recordType: " # recordType # ", size of response.";
      assert Test.isEqualInt(lookupResponse.answers.size(), 1, errMsg # "answers");
      assert Test.isEqualInt(lookupResponse.additionals.size(), 0, errMsg # "additionals");
      assert Test.isEqualInt(lookupResponse.authorities.size(), 0, errMsg # "authorities");

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
      assert Test.isTrue(not response.success, errMsg);
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
      assert Test.isTrue(not response.success, errMsg);
      assert Test.textContains(asText(response.message), "Inconsistent domain record", errMsg);
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
      assert Test.isTrue(not response.success, errMsg);
      assert Test.textContains(asText(response.message), "only a canister controller can register", errMsg);
    };
  };

};
