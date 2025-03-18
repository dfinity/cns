import Map "mo:base/OrderedMap";
import Metrics "metrics";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Types "cns_types";

actor TldOperator {
  let myTld = ".icp.";
  type DomainRecordsMap = Map.Map<Text, Types.DomainRecord>;
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
          let maybeAnswer : ?Types.DomainRecord = answersWrapper.get(lookupAnswersMap, domainLowercase);
          answers := switch maybeAnswer {
            case null { [] };
            case (?answer) { [answer] };
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

  // In addition th the `RegisterResult` this helper returns the relevant record type,
  // so that the caller can properly log the operation.
  func validateAndRegister(caller : Principal, domain : Text, records : Types.RegistrationRecords) : (Types.RegisterResult, Text) {
    if (not Principal.isController(caller)) {
      return (
        {
          success = false;
          message = ?("Currently only a canister controller can register " # myTld # "-domains, caller: " # Principal.toText(caller));
        },
        "",
      );
    };
    let domainRecords = Option.get(records.records, []);
    // TODO: remove the restriction of acceping exactly one domain record.
    if (domainRecords.size() != 1) {
      return (
        {
          success = false;
          message = ?"Currently exactly one domain record must be specified.";
        },
        "",
      );
    };
    let record : Types.DomainRecord = domainRecords[0];
    let recordType = record.record_type;
    let domainLowercase : Text = Text.toLowercase(domain);
    if (not Text.endsWith(domainLowercase, #text myTld)) {
      return (
        {
          success = false;
          message = ?("Unsupported TLD in domain " # domain # ", expected TLD=" # myTld);
        },
        recordType,
      );
    };
    if (domainLowercase != Text.toLowercase(record.name)) {
      return (
        {
          success = false;
          message = ?("Inconsistent domain record, record.name: `" # record.name # "` doesn't match domain: " # domainLowercase);
        },
        recordType,
      );
    };
    // TODO: add more checks: validate domain name and all the fields of the domain record(s).

    lookupAnswersMap := answersWrapper.put(lookupAnswersMap, domainLowercase, record);

    return (
      {
        success = true;
        message = null;
      },
      recordType,
    );
  };

  public shared ({ caller }) func register(domain : Text, records : Types.RegistrationRecords) : async (Types.RegisterResult) {
    let (result, recordType) = validateAndRegister(caller, domain, records);
    metrics.addEntry(metrics.makeRegisterEntry(Text.toLowercase(domain), recordType, result.success));
    return result;
  };

  public shared query ({ caller }) func get_metrics(period : Text) : async Result.Result<Metrics.MetricsData, Text> {
    if (not Principal.isController(caller)) {
      return #err("Currently only a controller can get metrics");
    };
    return #ok(metrics.getMetrics(period));
  };

  public shared ({ caller }) func purge_metrics() : async Result.Result<Nat, Text> {
    if (not Principal.isController(caller)) {
      return #err("Currently only a controller can purge metrics");
    };
    return #ok(metrics.purge());
  };
};
