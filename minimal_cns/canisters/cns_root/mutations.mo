import ApiTypes "../../common/api_types";
import DomainTypes "../../common/data/domain/Types";
import Domain "../../common/data/domain";
import { getTldFromDomain } "parse";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import Text "mo:base/Text";

module {
  // In addition th the `RegisterResult` this helper returns the relevant record type,
  // so that the caller can properly log the operation.
  public func validateAndRegister(
    caller : Principal,
    rootTld : Text,
    domain : Text,
    lookupAnswersMap : DomainTypes.DomainRecordsStore,
    lookupAuthoritiesMap : DomainTypes.DomainRecordsStore,
    records : DomainTypes.RegistrationRecords,
  ) : (ApiTypes.RegisterResult, Text) {
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
    let tld = getTldFromDomain(domainLowercase);
    if (tld != domainLowercase) {
      return (
        {
          success = false;
          message = ?("The given domain " # domain # " is not a TLD, its TLD is " # tld);
        },
        "",
      );
    };
    if (tld != rootTld) {
      return (
        {
          success = false;
          message = ?("Currently only " # rootTld # "-TLD is supported; requested TLD: " # domain);
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
    let record : DomainTypes.DomainRecord = domainRecords[0];
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
        Domain.DomainRecordsStore.add(lookupAnswersMap, tld, record);
        Domain.DomainRecordsStore.add(lookupAuthoritiesMap, tld, record);

        (
          {
            success = true;
            message = null;
          },
          recordType,
        );
      };
      case _ {
        (
          {
            success = false;
            message = ?("Unsupported record_type: `" # record.record_type # "`, expected 'NC'");
          },
          recordType,
        );
      };
    };
  };
};
