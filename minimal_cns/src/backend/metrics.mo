import Int "mo:base/Int";
import Map "mo:base/OrderedMap";
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

  // TODO: add more metrics:
  //   - top-10 domains looked up (with counts)
  //   - total number of DomainRecords
  public type MetricsData = {
    lookupCount : { success : Nat; fail : Nat };
    registerCount : { success : Nat; fail : Nat };
    sinceTimestamp : Int;
    logLength : Nat;
  };

  public type LogStore = Map.Map<Int, LogEntry>;

  public type Store = { var log : LogStore; var size : Nat };

  public func newStore() : Store {
    let logWrapper = Map.Make<Int>(Int.compare);
    return { var log = logWrapper.empty(); var size = 0 };
  };

  public class CnsMetrics(store : Store) = {
    let logWrapper = Map.Make<Int>(Int.compare);

    func recordTypeFromText(recordType : Text) : RecordType {
      switch (Text.toUppercase(recordType)) {
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
      store.log := logWrapper.put(store.log, store.size, entry);
      store.size += 1;
    };

    public func getMetrics(period : Text) : MetricsData {
      let nsPerHour : Int = 3600 * 1000_000_000;
      let periodNs = switch (Text.toLowercase(period)) {
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
      return computeMetrics(Time.now() - periodNs);
    };

    public func purge() : Nat {
      let originalSize = logWrapper.size(store.log);
      store.log := logWrapper.empty();
      store.size := 0;
      return originalSize;

    };

    func computeMetrics(sinceTimestamp : Int) : MetricsData {
      var lookupSuccess : Nat = 0;
      var lookupFail : Nat = 0;
      var registerSuccess : Nat = 0;
      var registerFail : Nat = 0;
      label timeLimit for ((_, e) in logWrapper.entriesRev(store.log)) {
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
        sinceTimestamp = sinceTimestamp;
        logLength = logWrapper.size(store.log);
      };
    };
  };
};
