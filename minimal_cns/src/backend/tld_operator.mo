import Text "mo:base/Text";
import Map "mo:base/OrderedMap";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import Types "cns_types";

actor TldOperator {
  let myTld = ".icp";
  type DomainRecordsMap = Map.Map<Text, Types.DomainRecord>;
  let answersWrapper = Map.Make<Text>(Text.compare);
  stable var lookupAnswersMap : DomainRecordsMap = answersWrapper.empty();

  public shared query func lookup(domain : Text, recordType : Text) : async Types.DomainLookup {
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

    {
      answers = answers;
      additionals = [];
      authorities = [];
    };
  };

  public shared ({ caller }) func register(domain : Text, records : Types.RegistrationRecords) : async (Types.RegisterResult) {
    if (not Principal.isController(caller)) {
      return {
        success = false;
        message = ?("Currently only a canister controller can register " # myTld # "-domains, caller: " # Principal.toText(caller));
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
    let domainLowercase : Text = Text.toLowercase(domain);
    if (not Text.endsWith(domainLowercase, #text myTld)) {
      return {
        success = false;
        message = ?("Unsupported TLD in domain " # domain # ", expected TLD=" #myTld);
      };
    };
    if (domainLowercase != Text.toLowercase(record.name)) {
      return {
        success = false;
        message = ?("Inconsistent domain record, record.name: `" # record.name # "` doesn't match domain: " # domainLowercase);
      };
    };
    // TODO: add more checks: validate domain name and all the fields of the domain record(s).

    lookupAnswersMap := answersWrapper.put(lookupAnswersMap, domainLowercase, record);

    return {
      success = true;
      message = null;
    };
  };
};
