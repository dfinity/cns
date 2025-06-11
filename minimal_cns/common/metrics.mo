import Array "mo:base/Array";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import Map "mo:base/Map";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Time "mo:base/Time";

module {
  public type CnsOp = {
    #lookupOp;
    #registerOp;
  };
  public type RecordType = {
    #ncRecordType;
    #cidRecordType;
    #otherRecordType;
  };
  public type LogEntry = {
    timestamp : Int;
    cnsOp : CnsOp;
    domain : Text;
    recordType : RecordType;
    isSuccess : Bool;
  };

  public type MetricsData = {
    lookupCount : { success : Nat; fail : Nat };
    registerCount : { success : Nat; fail : Nat };
    topLookups : [(Text, Nat)];
    extras : [(Text, Nat)];
    sinceTimestamp : Int;
    logLength : Nat;
  };

  public type LogStore = Map.Map<Int, LogEntry>;

  public func newStore() : LogStore {
    Map.empty<Int, LogEntry>();
  };

  public class CnsMetrics(store : LogStore) = {
    func recordTypeFromText(recordType : Text) : RecordType {
      switch (Text.toUpper(recordType)) {
        case ("NC") {
          return #ncRecordType;
        };
        case ("CID") {
          return #cidRecordType;
        };
        case (_) {
          return #otherRecordType;
        };
      };
    };

    public func makeLookupEntry(domainLowercase : Text, recordType : Text, isSuccess : Bool) : LogEntry {
      return {
        timestamp = Time.now();
        cnsOp = #lookupOp;
        domain = domainLowercase;
        recordType = recordTypeFromText(recordType);
        isSuccess = isSuccess;
      };
    };

    public func makeRegisterEntry(domainLowercase : Text, recordType : Text, isSuccess : Bool) : LogEntry {
      return {
        timestamp = Time.now();
        cnsOp = #registerOp;
        domain = domainLowercase;
        recordType = recordTypeFromText(recordType);
        isSuccess = isSuccess;
      };
    };

    public func addEntry(entry : LogEntry) {
      Map.add(store, Int.compare, entry.timestamp, entry);
    };

    public func getMetrics(period : Text, extras : [(Text, Nat)]) : MetricsData {
      let nsPerHour : Int = 3600 * 1000_000_000;
      let periodNs = switch (Text.toLower(period)) {
        case ("hour") {
          nsPerHour;
        };
        case ("day") {
          24 * nsPerHour;
        };
        case ("month") {
          30 * 24 * nsPerHour;
        };
        case (_) {
          nsPerHour; // default to 1h
        };
      };
      let computedMetrics = computeMetrics(Time.now() - periodNs);
      return { computedMetrics with extras = extras };
    };

    public func purge() : Nat {
      let originalSize = Map.size(store);
      Map.clear(store);
      return originalSize;
    };

    func computeMetrics(sinceTimestamp : Int) : MetricsData {
      var lookupSuccess : Nat = 0;
      var lookupFail : Nat = 0;
      var registerSuccess : Nat = 0;
      var registerFail : Nat = 0;
      var domainLookups : Map.Map<Text, Nat> = Map.empty();

      func countLookup(domainLowercase : Text) {
        let countWithIncrement = switch (Map.get(domainLookups, Text.compare, domainLowercase)) {
          case null 1;
          case (?count) count + 1;
        };
        Map.add(
          domainLookups,
          Text.compare,
          domainLowercase,
          countWithIncrement
        );
      };

      func top10Lookups() : [(Text, Nat)] {
        let lookupCounts = Iter.toArray(Map.entries(domainLookups));
        let sorted = Array.sort<(Text, Nat)>(
          lookupCounts,
          func(a, b) {
            if (a.1 > b.1) { #less } else if (a.1 < b.1) { #greater } else {
              Text.compare(a.0, b.0);
            };
          },
        );
        Array.sliceToArray(sorted, 0, Nat.min(Array.size(sorted), 10));
      };

      label timeLimit for ((_, e) in Map.reverseEntries(store)) {
        if (e.timestamp < sinceTimestamp) {
          break timeLimit;
        };
        switch (e.cnsOp) {
          case (#lookupOp) {
            if (e.isSuccess) {
              lookupSuccess += 1;
            } else {
              lookupFail += 1;
            };
            countLookup(e.domain);
          };
          case (#registerOp) {
            if (e.isSuccess) {
              registerSuccess += 1;
            } else {
              registerFail += 1;
            };
          };

        };
      };
      return {
        lookupCount = { success = lookupSuccess; fail = lookupFail };
        registerCount = {
          success = registerSuccess;
          fail = registerFail;
        };
        topLookups = top10Lookups();
        extras = [];
        sinceTimestamp = sinceTimestamp;
        logLength = Map.size(store);
      };
    };
  };
};
