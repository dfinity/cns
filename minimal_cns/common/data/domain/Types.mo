import Map "mo:base/Map";
import StableBuffer "mo:stable-buffer/StableBuffer";

module {
  public type RecordName = Text;
  /// DomainRecord represents a zone record item.
  public type DomainRecord = {
    /// The domain name, e.g. "mydomain.tld.", the name is required for all operations and must
    /// end with a dot (.). Names have well defined size limits and must have the parts between
    /// the dots or commonly called as labels with equal or less then 63 bytes and the entire
    /// name must be under 255 bytes.
    ///
    /// Names are encoded in ascii and are case insensitive, but the canonical form is lowercase.
    name : RecordName;
    /// The record type refers to the classification or category of a specific record within the
    /// system, e.g. "CID", "A", "CNAME", "TXT", "MX", "AAAA", "NC", "NS", "DNSKEY", "NSEC".
    ///
    /// Also, "ANY" is a reserved type that can only be used in lookups to retrieve all records of a domain.
    ///
    /// Record types can have maximum of 12 bytes, are encoded in ascii and are case insensitive,
    record_type : Text;
    /// The Time to Live (TTL) is a parameter in a record that specifies the amount of time for
    /// which the record should be cached before being refreshed from the authoritative naming canister.
    ///
    /// This value must be set in seconds and the minimum value is 0 seconds, which means not cached.
    /// Common values for TTL include 3600 seconds (1 hour), 86400 seconds (24 hours), or other intervals
    /// based on specific needs.
    ttl : Nat;
    /// The record data in a domain record refers to the specific information associated with that record type.
    /// Format of the data depends on the type of record to fit its purpose, but it must not exceed 2550 bytes.
    data : Text;
  };

  // A lowercase domain name, e.g. "mydomain.tld.".
  public type Domain = Text;

  public type RegistrationControllerRole = {
    #registrar;
    #registrant;
    #technical;
    #administrative;
  };

  public type RegistrationController = {
    controller_id : Principal;
    roles : [RegistrationControllerRole];
  };

  public type NewRegistrationDomainRecord = {
    controllers : [RegistrationController];
    record : DomainRecord;
  };

  public type RegistrationRecords = {
    controllers : [RegistrationController];
    records : ?[DomainRecord];
  };

  public type RegistrationRecordsMap = Map.Map<Domain, RegistrationRecords>;
  public type PrincipalToDomainIndex = Map.Map<Principal, Domain>;

  public type RegistrationRecordsStore = {
    // The map of domain to registration records and the principals that point to the domain.
    domainToRecordsMap : RegistrationRecordsMap;
    // Principal to domain that the principal points to.
    principalToDomainIndex : PrincipalToDomainIndex;
  };

  // CNS Root Domain Record Store
  // Map of domain names to domain records.
  public type DomainRecordsStore = Map.Map<Domain, DomainRecord>;
};
