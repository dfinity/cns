import NameRegistry "canister:name_registry";
import Text "mo:base/Text";
import Map "mo:base/OrderedMap";
import Principal "mo:base/Principal";

actor TldOperator {
  let myTld = ".icp";
  type DomainRecord = NameRegistry.DomainRecord;
  type DomainLookup = NameRegistry.DomainLookup;

  type OperationResult = {
    success : Bool;
    message : ?Text;
  };

  type RegisterResult = OperationResult;

  type RegistrationControllerRole = {
    #registrar;
    #registrant;
    #technical;
    #administrative;
  };

  type RegistrationController = {
    principal : Principal;
    roles : [RegistrationControllerRole];
  };

  /*
  // Types related to domain registration, but not used by `register`-endpoint.
  type DomainRegistrationStatus = { #active; #inactive; #transfer_prohibited };
  type RegistrationEventAction = {
    #registration;
    #locked;
    #unlocked;
    #expiration;
    #reregistration;
    #transfer;
  };

  type RegistrationEvent = {
    action : RegistrationEventAction;
    date : Text;
  };
  type DomainRegistrationData = {
    name : Text;
    status : [DomainRegistrationStatus];
    events : [RegistrationEvent];
    entities : [RegistrationController];
    name_canister : ?Principal;
  };

  type RegistrationDataResult = {
    certificate : Blob;
    data : DomainRegistrationData;
  };
  */

  type RegistrationRecords = {
    controller : [RegistrationController];
    records : ?[DomainRecord];
  };

  type DomainRecordsMap = Map.Map<Text, DomainRecord>;
  let answersWrapper = Map.Make<Text>(Text.compare);
  stable var lookupAnswersMap : DomainRecordsMap = answersWrapper.empty();

  public shared query func lookup(domain : Text, recordType : Text) : async DomainLookup {
    var answers : [DomainRecord] = [];
    let domainLowercase : Text = Text.toLowercase(domain);

    if (Text.endsWith(domainLowercase, #text myTld)) {
      switch (Text.toUppercase(recordType)) {
        case ("CID") {
          let maybeAnswer : ?DomainRecord = answersWrapper.get(lookupAnswersMap, domainLowercase);
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

  public shared ({ caller }) func register(domain : Text, records : RegistrationRecords) : async (RegisterResult) {
    if (not Principal.isController(caller)) {
      return {
        success = false;
        message = ?("Currently only a canister controller can register " # myTld # "-domains, caller: " # Principal.toText(caller));
      };
    };
    let domainRecords = switch (records.records) {
      case (null) { [] };
      case (?records) { records };
    };
    // TODO: remove the restriction of acceping exactly one domain record.
    if (domainRecords.size() != 1) {
      return {
        success = false;
        message = ?"Currently exactly one domain record must be specified.";
      };
    };
    let record : DomainRecord = domainRecords[0];
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
        message = ?("Inconsistent domain record, record.name: `" # domain # "` doesn't match domain: " # domainLowercase);
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
