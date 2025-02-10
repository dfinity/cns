import Iter "mo:base/Iter";
import Map "mo:base/OrderedMap";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Types "cns_types";

shared actor class () {
  let icpTld = ".icp.";

  type DomainRecordsMap = Map.Map<Text, Types.DomainRecord>;
  let answersWrapper = Map.Make<Text>(Text.compare);
  stable var lookupAnswersMap : DomainRecordsMap = answersWrapper.empty();
  stable var lookupAuthoritiesMap : DomainRecordsMap = answersWrapper.empty();

  func getTld(domain : Text) : Text {
    let parts = Text.split(domain, #char '.');
    let array = Iter.toArray(parts);
    if (array.size() >= 2) {
      return "." # array[array.size() - 2] # ".";
    } else {
      return "..";
    };
  };

  public shared query func lookup(domain : Text, recordType : Text) : async Types.DomainLookup {
    var answers : [Types.DomainRecord] = [];
    var authorities : [Types.DomainRecord] = [];

    let domainLowercase : Text = Text.toLowercase(domain);
    if (Text.endsWith(domainLowercase, #text icpTld)) {
      let tld = getTld(domainLowercase);
      switch (Text.toUppercase(recordType)) {
        case ("NC") {
          let maybeRecord : ?Types.DomainRecord = answersWrapper.get(lookupAnswersMap, tld);
          answers := switch maybeRecord {
            case null { [] };
            case (?record) { [record] };
          };
        };
        case _ {
          let maybeRecord : ?Types.DomainRecord = answersWrapper.get(lookupAuthoritiesMap, tld);
          authorities := switch maybeRecord {
            case null { [] };
            case (?record) { [record] };
          };
        };
      };
    };

    {
      answers = answers;
      additionals = [];
      authorities = authorities;
    };
  };

  public shared ({ caller }) func register(domain : Text, records : Types.RegistrationRecords) : async (Types.RegisterResult) {
    if (not Principal.isController(caller)) {
      return {
        success = false;
        message = ?("Currently only a canister controller can register new TLD-operators, caller: " # Principal.toText(caller));
      };
    };
    let domainLowercase : Text = Text.toLowercase(domain);
    let tld = getTld(domainLowercase);
    if (tld != domainLowercase) {
      return {
        success = false;
        message = ?("The given domain " # domain # " is not a TLD, its TLD is " # tld);
      };
    };
    if (tld != icpTld) {
      return {
        success = false;
        message = ?("Currently only " # icpTld # "-TLD is supported; requested TLD: " # domain);
      };
    };
    let domainRecords = Option.get(records.records, []);
    // TODO: remove the restriction of acceping exactly one domain record.
    if (domainRecords.size() != 1) {
      return {
        success = false;
        message = ?"Currently exactly one domain record must be specified.";
      };
    };
    let record : Types.DomainRecord = domainRecords[0];
    if (tld != (Text.toLowercase(record.name))) {
      return {
        success = false;
        message = ?("Inconsistent domain record, record.name: `" # record.name # "` doesn't match TLD: " # tld);
      };
    };
    // TODO: add more checks: validate domain name and all the fields of the domain record(s).

    switch (Text.toUppercase(record.record_type)) {
      case ("NC") {
        lookupAnswersMap := answersWrapper.put(lookupAnswersMap, tld, record);
        lookupAuthoritiesMap := answersWrapper.put(lookupAuthoritiesMap, tld, record);
        return {
          success = true;
          message = null;
        };
      };
      case _ {
        return {
          success = false;
          message = ?("Unsupported record_type: `" # record.record_type # "`, expected 'NC'");
        };
      };
    };
  };
};
