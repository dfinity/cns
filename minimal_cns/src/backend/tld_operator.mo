import Debug "mo:base/Debug";
import Map "mo:base/OrderedMap";
import Metrics "metrics";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Types "cns_types";

actor TldOperator {
  let myTld = ".icp.";
  type DomainRecordsMap = Map.Map<Text, Types.RegistrationRecords>;
  let answersWrapper = Map.Make<Text>(Text.compare);
  stable var lookupAnswersMap : DomainRecordsMap = answersWrapper.empty();

  stable var metricsStore : Metrics.Store = Metrics.newStore();
  let metrics = Metrics.CnsMetrics(metricsStore);

  public shared func lookup(domain : Text, recordType : Text) : async Types.DomainLookup {
    var answers : [Types.DomainRecord] = [];
    let domainLowercase : Text = Text.toLowercase(domain);

    if (Text.endsWith(domainLowercase, #text myTld)) {
      switch (Text.toUppercase(recordType)) {
        case ("CID") {
          let maybeRecords : ?Types.RegistrationRecords = answersWrapper.get(lookupAnswersMap, domainLowercase);
          answers := switch (maybeRecords) {
            case (null) { [] };
            case (?records) {
              let domainRecords = Option.get(records.records, []);
              if (domainRecords.size() == 0) { [] } else { [domainRecords[0]] };
            };
          };
        };
        case _ {};
      };
    };
    metrics.addEntry(metrics.makeLookupEntry(domainLowercase, recordType, answers != []));
    {
      answers = answers;
      additionals = [];
      authorities = [];
    };
  };

  // Validates the records, and if the domain already exisits, extracts the registrant.
  // If validation fails, returns an error message.
  func validateRegistrationRecords(domainLowercase : Text, records : Types.RegistrationRecords) : Result.Result<(Types.DomainRecord, ?Principal), Text> {
    let domainRecords = Option.get(records.records, []);
    // TODO: remove the restriction of acceping exactly one domain record.
    if (domainRecords.size() != 1) {
      return #err("Currently exactly one domain record must be specified.");
    };
    // TODO: remove the restriction of not setting the controller(s) explicitly.
    if (records.controller.size() != 0) {
      return #err("Currently no explicit controller setting is supported.");
    };
    let record : Types.DomainRecord = domainRecords[0];
    let recordType = Text.toUppercase(record.record_type);
    if (not Text.endsWith(domainLowercase, #text myTld)) {
      return #err("Unsupported TLD in domain " # domainLowercase # ", expected TLD=" # myTld);
    };
    if (domainLowercase != Text.toLowercase(record.name)) {
      return #err("Inconsistent domain record, record.name: `" # record.name # "` doesn't match domain: " # domainLowercase);
    };
    if (recordType != "CID") {
      return #err("Currently only CID-records can be registered");
    };
    // TODO: don't trap on invalid Principals.
    let _ = Principal.fromText(record.data);

    let maybeRegistrant : ?Principal = switch (answersWrapper.get(lookupAnswersMap, domainLowercase)) {
      case (null) { null };
      case (?records) {
        if (records.controller.size() == 0) {
          Debug.trap("Internal error: missing registration controller for " # domainLowercase);
        } else {
          ?records.controller[0].principal;
        };
      };
    };
    return #ok(Types.normalizedDomainRecord(record), maybeRegistrant);
  };

  // In addition th the `RegisterResult` this helper returns the relevant record type,
  // so that the caller can properly log the operation.
  func validateAndRegister(caller : Principal, domainLowercase : Text, records : Types.RegistrationRecords) : (Types.RegisterResult, Text) {
    let (domainRecord, maybeRegistrant) = switch (validateRegistrationRecords(domainLowercase, records)) {
      case (#ok(record, maybePrincipal)) { (record, maybePrincipal) };
      case (#err(msg)) {
        return (
          {
            success = false;
            message = ?(msg);
          },
          "",
        );
      };
    };
    if (not Principal.isController(caller)) {
      // Only subdomains of .test.icp are allowed for non-controllers
      if (not Text.endsWith(domainLowercase, #text(".test" # myTld))) {
        return (
          {
            success = false;
            message = ?("Currently only a canister controller can register non-test " # myTld # "-domains, domain: " # domainLowercase # ", caller: " # Principal.toText(caller));
          },
          "",
        );
      };
      // If the domain was registered previously, the caller must match the existing registrant.
      switch (maybeRegistrant) {
        case (null) {};
        case (?registrant) {
          if (registrant != caller) {
            return (
              {
                success = false;
                message = ?("Caller " # Principal.toText(caller) # " does not match the registrant " # Principal.toText(registrant));
              },
              "",
            );
          };
        };
      };
    };
    let registrationRecord = {
      controller = [{
        principal = caller;
        roles = [#registrant];
      }];
      records = ?[domainRecord];
    };
    lookupAnswersMap := answersWrapper.put(lookupAnswersMap, domainLowercase, registrationRecord);

    return (
      {
        success = true;
        message = null;
      },
      Text.toUppercase(domainRecord.record_type),
    );
  };

  public shared ({ caller }) func register(domain : Text, records : Types.RegistrationRecords) : async (Types.RegisterResult) {
    let domainLowercase : Text = Text.toLowercase(domain);
    let (result, recordType) = validateAndRegister(caller, domainLowercase, records);
    metrics.addEntry(metrics.makeRegisterEntry(domainLowercase, recordType, result.success));
    return result;
  };

  public shared query ({ caller }) func get_metrics(period : Text) : async Result.Result<Metrics.MetricsData, Text> {
    if (not Principal.isController(caller)) {
      return #err("Currently only a controller can get metrics");
    };
    return #ok(metrics.getMetrics(period, [("cidRecordsCount", answersWrapper.size(lookupAnswersMap))]));
  };

  public shared ({ caller }) func purge_metrics() : async Result.Result<Nat, Text> {
    if (not Principal.isController(caller)) {
      return #err("Currently only a controller can purge metrics");
    };
    return #ok(metrics.purge());
  };
};
