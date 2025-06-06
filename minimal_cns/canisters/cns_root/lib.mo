import Iter "mo:base/Iter";
import Map "mo:base/Map";
import Text "mo:base/Text";
import Metrics "../../common/metrics";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Types "../../common/cns_types";

shared actor class () {
  let icpTld = ".icp.";

  type DomainRecordsMap = Map.Map<Text, Types.DomainRecord>;
  stable var lookupAnswersMap : DomainRecordsMap = Map.empty();
  stable var lookupAuthoritiesMap : DomainRecordsMap = Map.empty();

  stable var metricsStore : Metrics.LogStore = Metrics.newStore();
  let metrics = Metrics.CnsMetrics(metricsStore);

  func getTld(domain : Text) : Text {
    let parts = Text.split(domain, #char '.');
    let array = Iter.toArray(parts);
    if (array.size() >= 2) {
      return "." # array[array.size() - 2] # ".";
    } else {
      return "..";
    };
  };

  public shared func lookup(domain : Text, recordType : Text) : async Types.DomainLookup {
    var answers : [Types.DomainRecord] = [];
    var authorities : [Types.DomainRecord] = [];

    let domainLowercase : Text = Text.toLower(domain);
    if (Text.endsWith(domainLowercase, #text icpTld)) {
      let tld = getTld(domainLowercase);
      switch (Text.toUpper(recordType)) {
        case ("NC") {
          let maybeRecord : ?Types.DomainRecord = Map.get(lookupAnswersMap, Text.compare, tld);
          answers := switch maybeRecord {
            case null { [] };
            case (?record) { [record] };
          };
        };
        case _ {
          let maybeRecord : ?Types.DomainRecord = Map.get(lookupAuthoritiesMap, Text.compare, tld);
          authorities := switch maybeRecord {
            case null { [] };
            case (?record) { [record] };
          };
        };
      };
    };
    metrics.addEntry(metrics.makeLookupEntry(domainLowercase, recordType, (answers != [] or authorities != [])));
    {
      answers = answers;
      additionals = [];
      authorities = authorities;
    };
  };

  // In addition th the `RegisterResult` this helper returns the relevant record type,
  // so that the caller can properly log the operation.
  func validateAndRegister(caller : Principal, domain : Text, records : Types.RegistrationRecords) : (Types.RegisterResult, Text) {
    if (not Principal.isController(caller)) {
      return (
        {
          success = false;
          message = ?("Currently only a canister controller can register new TLD-operators, caller: " # Principal.toText(caller));
        },
        "",
      );
    };
    let domainLowercase : Text = Text.toLower(domain);
    let tld = getTld(domainLowercase);
    if (tld != domainLowercase) {
      return (
        {
          success = false;
          message = ?("The given domain " # domain # " is not a TLD, its TLD is " # tld);
        },
        "",
      );
    };
    if (tld != icpTld) {
      return (
        {
          success = false;
          message = ?("Currently only " # icpTld # "-TLD is supported; requested TLD: " # domain);
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
    if (tld != (Text.toLower(record.name))) {
      return (
        {
          success = false;
          message = ?("Inconsistent domain record, record.name: `" # record.name # "` doesn't match TLD: " # tld);
        },
        recordType,
      );
    };
    // TODO: add more checks: validate domain name and all the fields of the domain record(s).

    switch (Text.toUpper(record.record_type)) {
      case ("NC") {
        Map.add(lookupAnswersMap, Text.compare, tld, record);
        Map.add(lookupAuthoritiesMap, Text.compare, tld, record);
        return (
          {
            success = true;
            message = null;
          },
          recordType,
        );
      };
      case _ {
        return (
          {
            success = false;
            message = ?("Unsupported record_type: `" # record.record_type # "`, expected 'NC'");
          },
          recordType,
        );
      };
    };
  };

  public shared ({ caller }) func register(domain : Text, records : Types.RegistrationRecords) : async (Types.RegisterResult) {
    let (result, recordType) = validateAndRegister(caller, domain, records);
    metrics.addEntry(metrics.makeRegisterEntry(Text.toLower(domain), recordType, result.success));
    return result;
  };

  public shared query ({ caller }) func get_metrics(period : Text) : async Result.Result<Metrics.MetricsData, Text> {
    if (not Principal.isController(caller)) {
      return #err("Currently only a controller can get metrics");
    };
    return #ok(metrics.getMetrics(period, [("ncRecordsCount", Map.size(lookupAnswersMap))]));
  };

  public shared ({ caller }) func purge_metrics() : async Result.Result<Nat, Text> {
    if (not Principal.isController(caller)) {
      return #err("Currently only a controller can purge metrics");
    };
    return #ok(metrics.purge());
  };
};
