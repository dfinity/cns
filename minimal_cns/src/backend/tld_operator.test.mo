import Array "mo:base/Array";
import Debug "mo:base/Debug";
import IcpTldOperator "canister:tld_operator";
import Metrics "metrics";
import Option "mo:base/Option";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Test "../test_utils";
import Types "cns_types";

actor {
  type DomainRecord = Types.DomainRecord;

  public func runTests() : async () {
    await shouldNotLookupNonregisteredIcpDomain();
    await shouldRegisterAndLookupIcpDomain();
    await shouldGetMetrics();
    await shouldNotRegisterNonIcpDomain();
    await shouldNotRegisterIfInconsistentDomainRecord();
    await shouldNotRegisterTldIfMissingDomainRecord();
    await shouldNotRegisterTldIfMultipleDomainRecords();
  };

  public func runTestsIfNotController() : async () {
    await shouldNotRegisterDomainIfNotController();
    await shouldNotReturnOrPurgeMetricsIfNotController();
  };

  func asText(maybeText : ?Text) : Text {
    return Option.get(maybeText, "");
  };

  func shouldNotLookupNonregisteredIcpDomain() : async () {
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

  func shouldRegisterAndLookupIcpDomain() : async () {
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

  func shouldGetMetrics() : async () {
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
        data = "aaa-aaaa";
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
      extras = [("cidRecordsCount", 4)];
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
      extras = [("cidRecordsCount", 4)];
      topLookups = [];
      sinceTimestamp = newMetricsData.sinceTimestamp; // cannot predict this field
    };
    assert Test.isEqualMetrics(newMetricsData, expectedEmptyMetrics);
  };

  func shouldNotRegisterNonIcpDomain() : async () {
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
        data = "aaa-aaaa";
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
        ("my_domain.icp."),
        ("example.icp."),
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

  func shouldNotReturnOrPurgeMetricsIfNotController() : async () {
    let metricsResult = await IcpTldOperator.get_metrics("hour");
    var errMsg = "shouldNotReturnOrPurgeMetricsIfNotController() got unexpected result from get_metrics()-call";
    assert Test.isTrue(Result.isErr(metricsResult), errMsg);
    assert Test.textContains(debug_show (metricsResult), "only a controller can get metrics", errMsg);

    let purgeResult = await IcpTldOperator.purge_metrics();
    errMsg := "shouldNotReturnOrPurgeMetricsIfNotController() got unexpected result from purge_metrics()-call";
    assert Test.isTrue(Result.isErr(purgeResult), errMsg);
    assert Test.textContains(debug_show (purgeResult), "only a controller can purge metrics", errMsg);
  };

  func shouldNotRegisterTldIfMissingDomainRecord() : async () {
    let response = await IcpTldOperator.register(".icp.", { controller = []; records = null });
    let errMsg = "shouldNotRegisterTldIfMissingDomainRecord() failed";
    assert Test.isTrue(not response.success, errMsg);
    assert Test.textContains(asText(response.message), "exactly one domain record", errMsg);
  };

  func shouldNotRegisterTldIfMultipleDomainRecords() : async () {
    let domainRecord : Types.DomainRecord = {
      name = "example.icp.";
      record_type = "CID";
      ttl = 3600;
      data = "aaa-aaaa";
    };
    let registrationRecords = {
      controller = [];
      records = ?[domainRecord, domainRecord];
    };
    let response = await IcpTldOperator.register(".icp.", registrationRecords);
    let errMsg = "shouldNotRegisterTldIfMultipleDomainRecords() failed for two DomainRecords";
    assert Test.isTrue(not response.success, errMsg);
    assert Test.textContains(asText(response.message), "exactly one domain record", errMsg);
  };

};
