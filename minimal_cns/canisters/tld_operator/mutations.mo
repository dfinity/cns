import ApiTypes "../../common/api_types";
import Domain "../../common/data/domain";
import DomainTypes "../../common/data/domain/Types";
import Array "mo:base/Array";
import Char "mo:base/Char";
import Iter "mo:base/Iter";
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
      switch (canRegisterResult(caller, myTld, domainLowercase, domainRecord.record_type, maybeRegistrant)) {
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

  // Registration authorization checks for if the caller is not a controller of the CNS service canister
  func canRegisterResult(
    caller : Principal,
    myTld : Text,
    domain : Text,
    recordType : Text,
    maybeRegistrant : ?Principal,
  ) : Result.Result<(), Text> {
    // Only allow CNS service controllers to register SID/other records to start
    if (recordType != "CID") {
      return #err("Not authorized to register non-CID records");
    };
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
    // Prevent record stuffing - initial limits (can be changed later) to ensure that the name,
    // record_type, and data fields are limited to 100 characters
    if (
      record.name.size() > 100 or
      record.record_type.size() > 100 or
      record.data.size() > 100
    ) {
      return #err("Domain record name, record_type, and data fields must be limited to 100 characters");
    };

    if (not Text.endsWith(domainLowercase, #text myTld)) {
      return #err("Unsupported TLD in domain " # domainLowercase # ", expected TLD=" # myTld);
    };
    if (domainLowercase != Text.toLower(record.name)) {
      return #err("Inconsistent domain record, record.name: `" # record.name # "` doesn't match domain: " # domainLowercase);
    };

    switch (validateRecord({ record with record_type = Text.toUpper(record.record_type) })) {
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
      switch (validateCanisterRecord(record)) {
        case (#ok) {};
        case (#err(msg)) { return #err(msg) };
      };
    };

    if (recordType == "SID") {
      switch (validateSubnetRecord(record)) {
        case (#ok) {};
        case (#err(msg)) { return #err(msg) };
      };
    };

    #ok;
  };

  func validateCanisterRecord(
    record : DomainTypes.DomainRecord
  ) : Result.Result<(), Text> {
    let canisterPrincipal = Principal.fromText(record.data);
    if (not Principal.isCanister(canisterPrincipal)) {
      return #err("CID record data is not a valid canister principal");
    };

    #ok;
  };

  // Subnet domain names follow the format `{subnet_type}-(optional {subnet_specialization})-{incrementing counter id}.subnet.icp.`
  func validateSubnetRecord(
    record : DomainTypes.DomainRecord
  ) : Result.Result<(), Text> {
    let servicePrincipal = Principal.fromText(record.data);
    if (not Principal.isSelfAuthenticating(servicePrincipal)) {
      return #err("SID record data is not a valid service principal");
    };

    // The subnet name must end with `.subnet.icp.`
    if (not Text.endsWith(record.name, #text(".subnet.icp."))) {
      return #err("Subnet record name must end with `.subnet.icp.`");
    };

    let parts = Iter.toArray(Text.split(record.name, #text(".")));
    if (parts.size() != 4) {
      return #err("Subnet record name has improper format");
    };

    let prefix = parts[0];

    let prefixParts = Iter.toArray(Text.split(prefix, #char '-'));
    if (prefixParts.size() < 2 or prefixParts.size() > 3) {
      return #err("Subnet record name has improper prefix format");
    };

    let subnetType = prefixParts[0];
    if (subnetType != "sys" and subnetType != "app") {
      return #err("Subnet record has unsupported subnet type");
    };
    // TODO: validate subnet specialization if it exists

    let counterId = prefixParts[prefixParts.size() - 1];
    for (char in counterId.chars()) {
      if (not Char.isDigit(char)) {
        return #err("Subnet record counter id is not numeric");
      };
    };

    #ok;
  };
};
