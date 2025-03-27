import Array "mo:base/Array";
import Debug "mo:base/Debug";
import IcpTldOperator "canister:tld_operator";
import Metrics "metrics";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Test "../test_utils";
import Types "cns_types";

actor {
  type DomainRecord = Types.DomainRecord;

  public func runTestsIfController() : async () {
    Debug.print("--- starting runTestsIfController...");
    await shouldNotLookupNonregisteredIcpDomain();
    await shouldRegisterAndLookupIcpDomainIfController();
    await shouldGetMetrics();
    await shouldNotRegisterNonIcpDomain();
    await shouldNotRegisterIfInconsistentDomainRecord();
    await shouldNotRegisterIfMissingDomainRecord();
    await shouldNotRegisterIfMultipleDomainRecords();
    await shouldNotRegisterTestDomainIfBadCanisterId();
    await shouldNotRegisterTestDomainIfNotCid();
    await shouldNotRegisterTestDomainIfExplicitController();
    await shouldNotRegisterTestDomainIfInconsistentDomainRecord();
    await shouldNotRegisterTestDomainIfNotDotIcp();
    await shouldOverwriteTestDomainIfController();
  };

  public func runTestsIfNotController() : async () {
    Debug.print("--- starting runTestsIfNotController...");
    await shouldNotRegisterIcpDomainIfNotController();
    await shouldRegisterAndLookupIcpTestDomainIfNotController();
    await shouldNotReturnOrPurgeMetricsIfNotController();
    await shouldNotRegisterTestDomainIfBadCanisterId();
    await shouldNotRegisterTestDomainIfNotCid();
    await shouldNotRegisterTestDomainIfExplicitController();
    await shouldNotRegisterTestDomainIfInconsistentDomainRecord();
    await shouldNotRegisterTestDomainIfNotDotIcp();
  };

  public func runTestsIfOtherCallerNotController() : async () {
    Debug.print("--- starting runTestsIfNotController...");
    await shouldNotOverwriteTestDomainIfNotRegistrantOrController();
    await shouldRegisterTestDomainOtherCallerRegistrant();
  };

  func asText(maybeText : ?Text) : Text {
    return Option.get(maybeText, "");
  };

  func shouldNotLookupNonregisteredIcpDomain() : async () {
    Debug.print("    test shouldNotLookupNonregisteredIcpDomain...");
    for (
      (domain, recordType) in [
        ("first.example.icp.", "CID"),
        ("another.example.ICP.", "CID"),
        ("other.domain.com.", "CID"),
      ].vals()
    ) {
      let response = await IcpTldOperator.lookup(domain, recordType);
      let errMsg = "shouldNotLookupNonregisteredIcpDomain() failed for domain: " # domain # ", recordType: " # recordType # ", size of response.";
      assert Test.isEqualInt(response.answers.size(), 0, errMsg # "answers");
      assert Test.isEqualInt(response.additionals.size(), 0, errMsg # "additionals");
      assert Test.isEqualInt(response.authorities.size(), 0, errMsg # "authorities");
    };
  };

  func shouldRegisterAndLookupIcpDomainIfController() : async () {
    Debug.print("    test shouldRegisterAndLookupIcpDomainIfController...");
    for (
      (domain, recordType) in [
        ("my_domain.icp.", "CID"),
        ("example.icp.", "Cid"),
        ("another.ICP.", "cid"),
        ("one.more.Icp.", "CId"),
      ].vals()
    ) {
      let domainRecord : DomainRecord = {
        name = domain;
        record_type = "CID";
        ttl = 3600;
        data = "aaaaa-aa";
      };
      let registrationRecords = {
        controller = [];
        records = ?[domainRecord];
      };
      let registerResponse = await IcpTldOperator.register(domain, registrationRecords);
      assert Test.isTrue(registerResponse.success, asText(registerResponse.message));

      let lookupResponse = await IcpTldOperator.lookup(domain, recordType);
      let errMsg = "shouldRegisterAndLookupIcpDomainIfController() failed for domain: " # domain # ", recordType: " # recordType # ", size of response.";
      assert Test.isEqualInt(lookupResponse.answers.size(), 1, errMsg # "answers");
      assert Test.isEqualInt(lookupResponse.additionals.size(), 0, errMsg # "additionals");
      assert Test.isEqualInt(lookupResponse.authorities.size(), 0, errMsg # "authorities");

      let responseDomainRecord = lookupResponse.answers[0];
      assert Test.isEqualDomainRecord(responseDomainRecord, domainRecord);
    };
  };

  func shouldGetMetrics() : async () {
    Debug.print("    test shouldGetMetrics...");
    // Purge metrics to be independent of other tests
    let purgeResult = await IcpTldOperator.purge_metrics();
    Result.assertOk(purgeResult);

    // Try to register and lookup domains; some domains will not succeed.
    let testDomains = [
      ("my_domain.icp.", "CID"),
      ("example.icp.", "Cid"),
      ("another.ICP.", "cid"),
      ("one.more.Icp.", "CId"),
      ("bad.domain.com.", "CID"),
      ("another.bad.org.", "CID"),
    ];
    let badDomainCount : Nat = 2;
    let goodDomainCount : Nat = testDomains.size() - badDomainCount;
    var extraLookupsCount : Nat = 0;
    let extraGoodLookupsCount : Nat = 1; // only "my_domain.icp.";
    for (
      (domain, recordType) in testDomains.vals()
    ) {
      let domainRecord : DomainRecord = {
        name = domain;
        record_type = "CID";
        ttl = 3600;
        data = "aaaaa-aa";
      };
      let registrationRecords = {
        controller = [];
        records = ?[domainRecord];
      };
      let _ = await IcpTldOperator.register(domain, registrationRecords);
      let _ = await IcpTldOperator.lookup(domain, recordType);
      // Lookup some domains again to have different lookup counts.
      if (recordType == "CID") {
        let _ = await IcpTldOperator.lookup(domain, recordType);
        extraLookupsCount += 1;
      };
    };
    let extraBadLookupsCount : Nat = extraLookupsCount - extraGoodLookupsCount;

    // Check the metrics.
    let metricsData = switch (await IcpTldOperator.get_metrics("hour")) {
      case (#ok(data)) { data };
      case (#err(e)) { Debug.trap("failed get_metrics with error: " # e) };
    };
    let expectedLookupCounts = Array.map<(Text, Text), (Text, Nat)>(testDomains, func(e) { (Text.toLowercase(e.0), if (e.1 == "CID") { 2 } else { 1 }) });
    let expectedMetrics : Metrics.MetricsData = {
      logLength = testDomains.size() * 2 + extraLookupsCount; // register and lookup operations
      lookupCount = {
        fail = badDomainCount + extraBadLookupsCount;
        success = goodDomainCount + extraGoodLookupsCount;
      };
      registerCount = { fail = badDomainCount; success = goodDomainCount };
      extras = [("cidRecordsCount", 9)]; // 4 registered in this test, and 5 test domains registered previously.
      topLookups = Array.sort<(Text, Nat)>(expectedLookupCounts, Test.compareLookupCounts);
      sinceTimestamp = metricsData.sinceTimestamp; // cannot predict this field
    };
    assert Test.isEqualMetrics(metricsData, expectedMetrics);

    // Purge metrics again, and check the outcome.
    let anotherPurgeResult = await IcpTldOperator.purge_metrics();
    Result.assertOk(anotherPurgeResult);

    let newMetricsData = switch (await IcpTldOperator.get_metrics("hour")) {
      case (#ok(data)) { data };
      case (#err(e)) { Debug.trap("failed get_metrics with error: " # e) };
    };
    let expectedEmptyMetrics : Metrics.MetricsData = {
      logLength = 0;
      lookupCount = { fail = 0; success = 0 };
      registerCount = { fail = 0; success = 0 };
      extras = [("cidRecordsCount", 9)];
      topLookups = [];
      sinceTimestamp = newMetricsData.sinceTimestamp; // cannot predict this field
    };
    assert Test.isEqualMetrics(newMetricsData, expectedEmptyMetrics);
  };

  func shouldNotRegisterNonIcpDomain() : async () {
    Debug.print("    test shouldNotRegisterNonIcpDomain...");
    for (
      (domain) in [
        (".fun."),
        ("example.com."),
        ("another.dfn."),
        (""),
        ("one.more.dfn."),
      ].vals()
    ) {
      let domainRecord : DomainRecord = {
        name = domain;
        record_type = "CID";
        ttl = 3600;
        data = "aaaaa-aa";
      };
      let registrationRecords = {
        controller = [];
        records = ?[domainRecord];
      };
      let response = await IcpTldOperator.register(domain, registrationRecords);
      let errMsg = "shouldNotRegisterNonIcpDomain() failed for domain: " # domain;
      assert Test.isTrue(not response.success, errMsg);
      assert Test.textContains(asText(response.message), "Unsupported TLD", errMsg);
    };
  };

  func shouldNotRegisterIfInconsistentDomainRecord() : async () {
    Debug.print("    test shouldNotRegisterIfInconsistentDomainRecord...");
    for (
      (domain, record_name) in [
        ("some.name.icp.", "other.domain.icp."),
        ("valid.subdomain.icp.", "subdomain.icp."),
      ].vals()
    ) {
      let domainRecord : DomainRecord = {
        name = record_name;
        record_type = "CID";
        ttl = 3600;
        data = "aaaaa-aa";
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

  func shouldNotRegisterIcpDomainIfNotController() : async () {
    Debug.print("    test shouldNotRegisterIcpDomainIfNotController...");
    for (
      (domain) in [
        ("my_domain.icp."),
        ("example.icp."),
      ].vals()
    ) {
      let domainRecord : DomainRecord = {
        name = domain;
        record_type = "CID";
        ttl = 3600;
        data = "aaaaa-aa";
      };
      let registrationRecords = {
        controller = [];
        records = ?[domainRecord];
      };
      let response = await IcpTldOperator.register(domain, registrationRecords);
      let errMsg = "shouldNotRegisterIcpDomainIfNotController() failed for domain: " # domain;
      assert Test.isTrue(not response.success, errMsg);
      assert Test.textContains(asText(response.message), "only a canister controller can register", errMsg);
    };
  };

  func shouldRegisterAndLookupIcpTestDomainIfNotController() : async () {
    Debug.print("    test shouldRegisterAndLookupIcpTestDomainIfNotController...");
    for (
      (domain, recordType, canisterId) in [
        ("my_domain.test.icp.", "CID", "aaaaa-aa"),
        ("example.test.icp.", "Cid", "em77e-bvlzu-aq"),
        ("another.test.ICP.", "cid", "un4fu-tqaaa-aaaab-qadjq-cai"),
        ("one.more.test.Icp.", "CId", "2vxsx-fae"),
        ("my_domain.test.icp.", "CID", "2vxsx-fae"), // overwrite previous mapping
      ].vals()
    ) {
      let domainRecord : DomainRecord = {
        name = domain;
        record_type = recordType;
        ttl = 3600;
        data = canisterId;
      };
      let registrationRecords = {
        controller = [];
        records = ?[domainRecord];
      };
      let registerResponse = await IcpTldOperator.register(domain, registrationRecords);
      assert Test.isTrue(registerResponse.success, asText(registerResponse.message));

      let lookupResponse = await IcpTldOperator.lookup(domain, recordType);
      let errMsg = "shouldRegisterAndLookupIcpTestDomainIfNotController() failed for domain: " # domain # ", recordType: " # recordType # ", size of response.";
      assert Test.isEqualInt(lookupResponse.answers.size(), 1, errMsg # "answers");
      assert Test.isEqualInt(lookupResponse.additionals.size(), 0, errMsg # "additionals");
      assert Test.isEqualInt(lookupResponse.authorities.size(), 0, errMsg # "authorities");

      let responseDomainRecord = lookupResponse.answers[0];
      assert Test.isEqualDomainRecord(responseDomainRecord, domainRecord);
    };
  };

  // This test should be run after shouldRegisterAndLookupIcpTestDomainIfNotController() finished
  // registering some test domains, but it should use a different caller then the registrant.
  func shouldNotOverwriteTestDomainIfNotRegistrantOrController() : async () {
    Debug.print("    test shouldNotOverwriteTestDomainIfNotRegistrantOrController...");
    for (
      // The test data is a subset from shouldRegisterAndLookupIcpTestDomainIfNotController()
      (domain, recordType, canisterId) in [
        ("example.test.icp.", "Cid", "em77e-bvlzu-aq"),
        ("another.test.ICP.", "cid", "un4fu-tqaaa-aaaab-qadjq-cai"),
        ("one.more.test.Icp.", "CId", "2vxsx-fae"),
      ].vals()
    ) {
      let expectedDomainRecord : DomainRecord = {
        name = domain;
        record_type = recordType;
        ttl = 3600;
        data = canisterId;
      };
      let newDomainRecord : DomainRecord = {
        name = domain;
        record_type = "CID";
        ttl = 3600;
        data = "aaaaa-aa"; // try to override an existing mapping
      };
      let registrationRecords = {
        controller = [];
        records = ?[newDomainRecord];
      };
      let registerResponse = await IcpTldOperator.register(domain, registrationRecords);
      assert Test.isFalse(registerResponse.success, "Registration of " # domain # " succeeded unexpectedly");
      assert Test.textContains(asText(registerResponse.message), "does not match the registrant", "Registration of " # domain # " failed for a wrong reason");

      let lookupResponse = await IcpTldOperator.lookup(domain, recordType);
      let errMsg = "shouldNotOverwriteTestDomainIfNotRegistrantOrController() failed for domain: " # domain # ", recordType: " # recordType # ", size of response.";
      assert Test.isEqualInt(lookupResponse.answers.size(), 1, errMsg # "answers");
      assert Test.isEqualInt(lookupResponse.additionals.size(), 0, errMsg # "additionals");
      assert Test.isEqualInt(lookupResponse.authorities.size(), 0, errMsg # "authorities");

      let responseDomainRecord = lookupResponse.answers[0];
      assert Test.isEqualDomainRecord(responseDomainRecord, expectedDomainRecord);
    };
  };

  func shouldRegisterTestDomainOtherCallerRegistrant() : async () {
    Debug.print("    test shouldRegisterTestDomainOtherCallerRegistrant...");
    let domain = "to-be-overriden.test.icp.";
    let canisterId = "2vxsx-fae";
    let record : DomainRecord = {
      name = domain;
      record_type = "CID";
      ttl = 3600;
      data = canisterId;
    };
    let registrationRecords = {
      controller = [];
      records = ?[record];
    };
    let registerResponse = await IcpTldOperator.register(domain, registrationRecords);
    assert Test.isTrue(registerResponse.success, "Registration of " # domain # " failed unexpectedly with error" # debug_show (registerResponse.message));
  };

  func shouldOverwriteTestDomainIfController() : async () {
    Debug.print("    test shouldOverwriteTestDomainIfController...");
    let domain = "to-be-overriden.test.icp.";
    let canisterId = "2vxsx-fae";
    let expectedDomainRecord : DomainRecord = {
      name = domain;
      record_type = "CID";
      ttl = 3600;
      data = canisterId;
    };

    // Lookup previous registration.
    let lookupResponse = await IcpTldOperator.lookup(domain, "CID");
    let errMsg = "shouldRegisterTestDomainOtherCaller() failed for domain: " # domain # ", size of response.";
    assert Test.isEqualInt(lookupResponse.answers.size(), 1, errMsg # "answers");
    assert Test.isEqualInt(lookupResponse.additionals.size(), 0, errMsg # "additionals");
    assert Test.isEqualInt(lookupResponse.authorities.size(), 0, errMsg # "authorities");

    let responseDomainRecord = lookupResponse.answers[0];
    assert Test.isEqualDomainRecord(responseDomainRecord, expectedDomainRecord);

    // Overwrite the registration
    let newDomainRecord : DomainRecord = {
      name = domain;
      record_type = "CID";
      ttl = 600; // different ttl
      data = "aaaaa-aa"; // different canister id
    };
    let registrationRecords = {
      controller = [];
      records = ?[newDomainRecord];
    };

    let registerResponse = await IcpTldOperator.register(domain, registrationRecords);
    assert Test.isTrue(registerResponse.success, "Registration of " # domain # " failed unexpectedly with error" # debug_show (registerResponse.message));

    // Lookup the new record.
    let newLookupResponse = await IcpTldOperator.lookup(domain, "CID");
    assert Test.isEqualInt(newLookupResponse.answers.size(), 1, errMsg # "answers");
    assert Test.isEqualInt(newLookupResponse.additionals.size(), 0, errMsg # "additionals");
    assert Test.isEqualInt(newLookupResponse.authorities.size(), 0, errMsg # "authorities");

    let newResponseDomainRecord = newLookupResponse.answers[0];
    assert Test.isEqualDomainRecord(newResponseDomainRecord, newDomainRecord);
  };

  func shouldNotRegisterTestDomainIfBadCanisterId() : async () {
    Debug.print("    test shouldNotRegisterTestDomainIfBadCanisterId...");
    let domain = "example.test.icp.";
    let record : DomainRecord = {
      name = domain;
      record_type = "CID";
      ttl = 3600;
      data = "bad-canister-id";
    };
    let registrationRecords = {
      controller = [];
      records = ?[record];
    };
    try {
      let _ = await IcpTldOperator.register(domain, registrationRecords);
    } catch (_) {
      // expected
      return;
    };
    Debug.trap("Registration with bad canister id did not trap");
  };

  func shouldNotRegisterTestDomainIfNotCid() : async () {
    Debug.print("    test shouldNotRegisterTestDomainIfNotCid...");
    let domain = "example.test.icp.";
    let record : DomainRecord = {
      name = domain;
      record_type = "NS";
      ttl = 3600;
      data = "aaaaa-aa";
    };
    let registrationRecords = {
      controller = [];
      records = ?[record];
    };
    let registerResponse = await IcpTldOperator.register(domain, registrationRecords);
    assert Test.isFalse(registerResponse.success, "Registration of " # domain # " succeeded unexpectedly");
    assert Test.textContains(asText(registerResponse.message), "only CID-records can be registered", "Registration of " # domain # " failed for a wrong reason");
  };

  func shouldNotRegisterTestDomainIfExplicitController() : async () {
    Debug.print("    test shouldNotRegisterTestDomainIfExplicitController...");
    let domain = "example.test.icp.";
    let record : DomainRecord = {
      name = domain;
      record_type = "CID";
      ttl = 3600;
      data = "aaaaa-aa";
    };
    let registrationRecords : Types.RegistrationRecords = {
      controller = [{
        principal = Principal.fromText("aaaaa-aa");
        roles : [Types.RegistrationControllerRole] = [#registrant];
      }];
      records = ?[record];
    };
    let registerResponse = await IcpTldOperator.register(domain, registrationRecords);
    assert Test.isFalse(registerResponse.success, "Registration of " # domain # " succeeded unexpectedly");
    assert Test.textContains(asText(registerResponse.message), "no explicit controller setting is supported", "Registration of " # domain # " failed for a wrong reason");
  };

  func shouldNotRegisterTestDomainIfInconsistentDomainRecord() : async () {
    Debug.print("    test shouldNotRegisterTestDomainIfInconsistentDomainRecord...");
    let domain = "example.test.icp.";
    let record : DomainRecord = {
      name = "other.domain.test.icp.";
      record_type = "CID";
      ttl = 3600;
      data = "aaaaa-aa";
    };
    let registrationRecords = {
      controller = [];
      records = ?[record];
    };
    let registerResponse = await IcpTldOperator.register(domain, registrationRecords);
    assert Test.isFalse(registerResponse.success, "Registration of " # domain # " succeeded unexpectedly");
    assert Test.textContains(asText(registerResponse.message), "Inconsistent domain record", "Registration of " # domain # " failed for a wrong reason");
  };

  func shouldNotRegisterTestDomainIfNotDotIcp() : async () {
    Debug.print("    test shouldNotRegisterTestDomainIfNotDotIcp...");
    let domain = "example.test.org.";
    let record : DomainRecord = {
      name = domain;
      record_type = "CID";
      ttl = 3600;
      data = "aaaaa-aa";
    };
    let registrationRecords = {
      controller = [];
      records = ?[record];
    };
    let registerResponse = await IcpTldOperator.register(domain, registrationRecords);
    assert Test.isFalse(registerResponse.success, "Registration of " # domain # " succeeded unexpectedly");
    assert Test.textContains(asText(registerResponse.message), "Unsupported TLD", "Registration of " # domain # " failed for a wrong reason");
  };

  func shouldNotReturnOrPurgeMetricsIfNotController() : async () {
    Debug.print("    test shouldNotReturnOrPurgeMetricsIfNotController...");

    let metricsResult = await IcpTldOperator.get_metrics("hour");
    var errMsg = "shouldNotReturnOrPurgeMetricsIfNotController() got unexpected result from get_metrics()-call";
    assert Test.isTrue(Result.isErr(metricsResult), errMsg);
    assert Test.textContains(debug_show (metricsResult), "only a controller can get metrics", errMsg);

    let purgeResult = await IcpTldOperator.purge_metrics();
    errMsg := "shouldNotReturnOrPurgeMetricsIfNotController() got unexpected result from purge_metrics()-call";
    assert Test.isTrue(Result.isErr(purgeResult), errMsg);
    assert Test.textContains(debug_show (purgeResult), "only a controller can purge metrics", errMsg);
  };

  func shouldNotRegisterIfMissingDomainRecord() : async () {
    let response = await IcpTldOperator.register(".icp.", { controller = []; records = null });
    let errMsg = "shouldNotRegisterIfMissingDomainRecord() failed";
    assert Test.isTrue(not response.success, errMsg);
    assert Test.textContains(asText(response.message), "exactly one domain record", errMsg);
  };

  func shouldNotRegisterIfMultipleDomainRecords() : async () {
    Debug.print("    test shouldNotRegisterIfMultipleDomainRecords...");

    let domainRecord : Types.DomainRecord = {
      name = "example.icp.";
      record_type = "CID";
      ttl = 3600;
      data = "aaaaa-aa";
    };
    let registrationRecords = {
      controller = [];
      records = ?[domainRecord, domainRecord];
    };
    let response = await IcpTldOperator.register(".icp.", registrationRecords);
    let errMsg = "shouldNotRegisterIfMultipleDomainRecords() failed for two DomainRecords";
    assert Test.isFalse(response.success, errMsg);
    assert Test.textContains(asText(response.message), "exactly one domain record", errMsg);
  };

};
