import Types "../../common/cns_types";
import Map "mo:base/Map";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Principal "mo:base/Principal";
import Option "mo:base/Option";
import { trap } "mo:base/Runtime";

module {
  // In addition th the `RegisterResult` this helper returns the relevant record type,
  // so that the caller can properly log the operation.
  public func validateAndRegister(
    caller : Principal,
    myTld : Text,
    lookupAnswersMap : Map.Map<Text, Types.RegistrationRecords>,
    domainLowercase : Text,
    records : Types.RegistrationRecords,
  ) : (Types.RegisterResult, Text) {
    let (domainRecord, maybeRegistrant) = switch (validateRegistrationRecords(myTld, lookupAnswersMap, domainLowercase, records)) {
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
    Map.add(lookupAnswersMap, Text.compare, domainLowercase, registrationRecord);

    (
      {
        success = true;
        message = null;
      },
      Text.toUpper(domainRecord.record_type),
    );
  };

  // Validates the records, and if the domain already exisits, extracts the registrant.
  // If validation fails, returns an error message.
  func validateRegistrationRecords(
    myTld : Text,
    lookupAnswersMap : Map.Map<Text, Types.RegistrationRecords>,
    domainLowercase : Text,
    records : Types.RegistrationRecords,
  ) : Result.Result<(Types.DomainRecord, ?Principal), Text> {
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
    let recordType = Text.toUpper(record.record_type);
    if (not Text.endsWith(domainLowercase, #text myTld)) {
      return #err("Unsupported TLD in domain " # domainLowercase # ", expected TLD=" # myTld);
    };
    if (domainLowercase != Text.toLower(record.name)) {
      return #err("Inconsistent domain record, record.name: `" # record.name # "` doesn't match domain: " # domainLowercase);
    };
    if (recordType != "CID") {
      return #err("Currently only CID-records can be registered");
    };
    // TODO: don't trap on invalid Principals.
    let _ = Principal.fromText(record.data);

    let maybeRegistrant : ?Principal = switch (Map.get(lookupAnswersMap, Text.compare, domainLowercase)) {
      case (null) { null };
      case (?records) {
        if (records.controller.size() == 0) {
          trap("Internal error: missing registration controller for " # domainLowercase);
        } else {
          ?records.controller[0].principal;
        };
      };
    };

    #ok(Types.normalizedDomainRecord(record), maybeRegistrant);
  };
}

