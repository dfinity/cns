import Types "Types";
import Array "mo:base/Array";
import Map "mo:base/Map";
import Text "mo:base/Text";
import Principal "mo:base/Principal";

module {
  public module DomainRecordsStore {
    public func init() : Types.DomainRecordsStore {
      Map.empty<Types.Domain, Types.DomainRecord>();
    };

    public func size(store : Types.DomainRecordsStore) : Nat {
      Map.size(store);
    };

    public func getByDomain(
      store : Types.DomainRecordsStore,
      domain : Types.Domain,
    ) : ?Types.DomainRecord {
      Map.get(store, Text.compare, domain);
    };

    public func add(
      store : Types.DomainRecordsStore,
      domain : Types.Domain,
      record : Types.DomainRecord,
    ) : () {
      Map.add(store, Text.compare, domain, record);
    };
  };

  public module RegistrationRecordsStore {
    public func init() : Types.RegistrationRecordsStore {
      {
        domainToRecordsMap = Map.empty<Types.Domain, Types.RegistrationRecords>();
        principalToDomainIndex = Map.empty<Principal, Types.Domain>();
      };
    };

    public func size(store : Types.RegistrationRecordsStore) : Nat {
      Map.size(store.domainToRecordsMap);
    };

    public func getByDomain(
      store : Types.RegistrationRecordsStore,
      domain : Types.Domain,
    ) : ?Types.RegistrationRecords {
      Map.get(store.domainToRecordsMap, Text.compare, domain);
    };

    public func getByDomainAndRecordType(
      store : Types.RegistrationRecordsStore,
      domain : Types.Domain,
      recordType : Text,
    ) : ?Types.DomainRecord {
      let maybeRegistrationRecords = switch (getByDomain(store, domain)) {
        case null { return null };
        case (?registrationRecords) { registrationRecords.records };
      };
      let recordsList = switch (maybeRegistrationRecords) {
        case null { return null };
        case (?records) { records };
      };

      Array.find<Types.DomainRecord>(
        recordsList,
        func(record) { record.record_type == recordType },
      );
    };

    // Synthesizes a PTR record for a given principal by looking up the domain for that principal
    // in the principal to domain index, and then ensuring that a domain record for that domain exists
    public func getPtrRecord(
      store : Types.RegistrationRecordsStore,
      reverseDomain : Text,
      principal : Principal,
    ) : ?Types.DomainRecord {
      let domain = switch (Map.get(store.principalToDomainIndex, Principal.compare, principal)) {
        case null { return null };
        case (?domain) { domain };
      };
      // Attempt to retrieve the domain record for the reverse index (sanity check + inherits the same ttl).
      let domainRecord = switch (getByDomain(store, domain)) {
        case null { return null };
        case (?maybeRegistrationRecords) {
          switch (maybeRegistrationRecords.records) {
            case null { return null };
            case (?records) { records[0] };
          };
        };
      };

      return ?{
        name = reverseDomain;
        record_type = "PTR";
        ttl = domainRecord.ttl;
        data = domain; // The PTR record points to the domain name
      };
    };

    // TODO: Handle the case where there are more than one record type per domain (doesn't just overwrite the existing registration records)
    public func add(
      store : Types.RegistrationRecordsStore,
      domain : Types.Domain,
      { controllers; record } : Types.NewRegistrationDomainRecord,
      updatePtrRecords : Bool,
    ) : () {
      // if this is a principal record type CID or SID (in the future maybe other principals?),
      // update the principal to domain index
      if (updatePtrRecords and isPrincipalRecordType(record.record_type)) {
        // update the principal to domain index entry (add new or update existing)
        updatePrincipalToDomainIndexEntry(store, domain, record);
      };

      let registrationRecords : Types.RegistrationRecords = {
        controllers;
        records = ?[record];
      };

      Map.add(
        store.domainToRecordsMap,
        Text.compare,
        domain,
        registrationRecords,
      );
    };

    func updatePrincipalToDomainIndexEntry(
      store : Types.RegistrationRecordsStore,
      domain : Types.Domain,
      newRecord : Types.DomainRecord,
    ) : () {
      // TODO: don't trap on invalid Principals.
      let newPrincipalData = Principal.fromText(newRecord.data);
      switch (
        getByDomainAndRecordType(
          store,
          domain,
          newRecord.record_type,
        )
      ) {
        case null {};
        case (?existingRecord) {
          // TODO: don't trap on invalid Principals.
          let oldPrincipalData = Principal.fromText(existingRecord.data);
          // If the old principal data is different, first remove the old principal to domain entry from the index
          if (oldPrincipalData != newPrincipalData) {
            Map.remove(store.principalToDomainIndex, Principal.compare, oldPrincipalData);
          };
        };
      };

      // Add the new principal to domain index entry
      Map.add(store.principalToDomainIndex, Principal.compare, newPrincipalData, domain);
    };
  };

  public func normalizedDomainRecord(record : Types.DomainRecord) : Types.DomainRecord {
    {
      name = Text.toLower(record.name);
      record_type = Text.toUpper(record.record_type);
      ttl = record.ttl;
      data = record.data;
    };
  };

  func isPrincipalRecordType(recordType : Text) : Bool {
    Array.any<Text>(
      ["CID", "SID"],
      func(supportedType) { supportedType == recordType },
    );
  };
};
