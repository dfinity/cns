import ApiTypes "../../common/api_types";
import Domain "../../common/data/domain";
import DomainTypes "../../common/data/domain/Types";
import Array "mo:base/Array";
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
    lookupAnswersMap : DomainTypes.RegistrationRecordsStore,
    domainLowercase : Text,
    records : DomainTypes.RegistrationRecords,
  ) : (ApiTypes.RegisterResult, Text) {
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
      switch (canRegisterResult(caller, myTld, domainLowercase, maybeRegistrant)) {
        case (#ok) {};
        case (#err(msg)) { return ({ success = false; message = ?(msg) }, "") };
      };
    };

    // Currently, only adding exactly one domain record is supported. (see checks in `validateRegistrationRecords`).
    let newRegistrationRecord : DomainTypes.NewRegistrationDomainRecord = {
      controllers = [{
        principal = caller;
        roles = [#registrant];
      }];
      record = domainRecord;
    };

    Domain.RegistrationRecordsStore.add(lookupAnswersMap, domainLowercase, newRegistrationRecord);

    (
      {
        success = true;
        message = null;
      },
      Text.toUpper(domainRecord.record_type),
    );
  };

  func canRegisterResult(
    caller : Principal,
    myTld : Text,
    domain : Text,
    maybeRegistrant : ?Principal,
  ) : Result.Result<(), Text> {
    if (not Text.endsWith(domain, #text(".test" # myTld))) {
      return #err("Currently only a canister controller can register non-test " # myTld # "-domains, domain: " # domain # ", caller: " # Principal.toText(caller));
    };
    // If the domain was registered previously, the caller must match the existing registrant.
    switch (maybeRegistrant) {
      case (null) {};
      case (?registrant) {
        if (registrant != caller) {
          return #err("Caller " # Principal.toText(caller) # " does not match the registrant " # Principal.toText(registrant));
        };
      };
    };

    #ok;
  };

  // Validates the records, and if the domain already exisits, extracts the registrant.
  // If validation fails, returns an error message.
  func validateRegistrationRecords(
    myTld : Text,
    lookupAnswersMap : DomainTypes.RegistrationRecordsStore,
    domainLowercase : Text,
    records : DomainTypes.RegistrationRecords,
  ) : Result.Result<(DomainTypes.DomainRecord, ?Principal), Text> {
    let domainRecords = Option.get(records.records, []);
    // TODO: remove the restriction of acceping exactly one domain record.
    if (domainRecords.size() != 1) {
      return #err("Currently exactly one domain record must be specified.");
    };
    // TODO: remove the restriction of not setting the controller(s) explicitly.
    if (records.controllers.size() != 0) {
      return #err("Currently no explicit controller setting is supported.");
    };
    let record : DomainTypes.DomainRecord = domainRecords[0];
    let recordType = Text.toUpper(record.record_type);
    if (not Text.endsWith(domainLowercase, #text myTld)) {
      return #err("Unsupported TLD in domain " # domainLowercase # ", expected TLD=" # myTld);
    };
    if (domainLowercase != Text.toLower(record.name)) {
      return #err("Inconsistent domain record, record.name: `" # record.name # "` doesn't match domain: " # domainLowercase);
    };

    switch (validateRecord(record)) {
      case (#ok) {};
      case (#err(msg)) { return #err(msg) };
    };

    // TODO: don't trap on invalid Principals.
    let _ = Principal.fromText(record.data);

    let maybeRegistrant : ?Principal = switch (Domain.RegistrationRecordsStore.getByDomain(lookupAnswersMap, domainLowercase)) {
      case (null) { null };
      case (?{ controllers }) {
        if (controllers.size() == 0) {
          trap("Internal error: missing registration controller for " # domainLowercase);
        } else {
          ?controllers[0].principal;
        };
      };
    };

    #ok(Domain.normalizedDomainRecord(record), maybeRegistrant);
  };

  func isRecordTypeSupported(recordType : Text) : Bool {
    Array.any<Text>(
      ["CID", "SID"],
      func(supportedType) { supportedType == recordType },
    );
  };

  func validateRecord(
    record : DomainTypes.DomainRecord
  ) : Result.Result<(), Text> {
    let recordType = Text.toUpper(record.record_type);
    if (not isRecordTypeSupported(recordType)) {
      return #err("Currently only CID and SID records can be registered");
    };

    if (recordType == "CID") {
      let canisterPrincipal = Principal.fromText(record.data);
      if (not Principal.isCanister(canisterPrincipal)) {
        return #err("CID record data is not a valid canister principal");
      };
    };

    if (recordType == "SID") {
      let servicePrincipal = Principal.fromText(record.data);
      if (not Principal.isSelfAuthenticating(servicePrincipal)) {
        return #err("SID record data is not a valid service principal");
      };
    };

    #ok;
  };
};
