import NameRegistry "canister:name_registry";
import Text "mo:base/Text";
import Principal "mo:base/Principal";

module {
  public type DomainRecord = NameRegistry.DomainRecord;
  public type DomainLookup = NameRegistry.DomainLookup;

  public type OperationResult = {
    success : Bool;
    message : ?Text;
  };

  public func normalizedDomainRecord(record : DomainRecord) : DomainRecord {
    return {
      name = Text.toLowercase(record.name);
      record_type = Text.toUppercase(record.record_type);
      ttl = record.ttl;
      data = record.data;
    };
  };

  public type RegisterResult = OperationResult;

  public type RegistrationControllerRole = {
    #registrar;
    #registrant;
    #technical;
    #administrative;
  };

  public type RegistrationController = {
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

  public type RegistrationRecords = {
    controller : [RegistrationController];
    records : ?[DomainRecord];
  };
};
