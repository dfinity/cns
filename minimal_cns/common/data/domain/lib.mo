import Types "Types";
import Map "mo:base/Map";
import Text "mo:base/Text";
import StableBuffer "mo:stable-buffer/StableBuffer";

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
        domainToRecordsMap = Map.empty<Types.Domain, Types.RegistrationRecordsWithPrincipals>();
        principalToDomainIndex = Map.empty<Principal, Types.Domain>();
      };
    };

    public func size(store : Types.RegistrationRecordsStore) : Nat {
      Map.size(store.domainToRecordsMap);
    };

    public func getByDomain(
      store : Types.RegistrationRecordsStore,
      domain : Types.Domain,
    ) : ?Types.RegistrationRecordsWithPrincipals {
      Map.get(store.domainToRecordsMap, Text.compare, domain);
    };

    // TODO: Drop in replacement - improve this in the next PR
    public func add(
      store : Types.RegistrationRecordsStore,
      domain : Types.Domain,
      records : Types.RegistrationRecords,
      principals : [Principal],
    ) : () {
      Map.add(
        store.domainToRecordsMap,
        Text.compare,
        domain,
        {
          records;
          principals = StableBuffer.fromArray<Principal>(principals);
        },
      );

      // TODOs (next PR):
      // 1. Update the list of principals associated with the domain
      // 2. Update principal to domain index
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
};
