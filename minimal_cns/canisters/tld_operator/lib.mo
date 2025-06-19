import Map "mo:base/Map";
import Metrics "../../common/metrics";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Types "../../common/cns_types";
import Queries "queries";
import Mutations "mutations";

actor TldOperator {
  let myTld = ".icp.";
  type DomainRecordsMap = Map.Map<Text, Types.RegistrationRecords>;
  stable var lookupAnswersMap : DomainRecordsMap = Map.empty();

  stable var metricsStore : Metrics.LogStore = Metrics.newStore();
  let metrics = Metrics.CnsMetrics(metricsStore);

  public shared func lookup(domain : Text, recordType : Text) : async Types.DomainLookup {
    Queries.lookup(
      myTld,
      lookupAnswersMap,
      metrics,
      domain,
      recordType,
    );
  };

  public shared ({ caller }) func register(domain : Text, records : Types.RegistrationRecords) : async (Types.RegisterResult) {
    let domainLowercase : Text = Text.toLower(domain);
    let (result, recordType) = Mutations.validateAndRegister(
      caller,
      myTld,
      lookupAnswersMap,
      domainLowercase,
      records
    );
    metrics.addEntry(metrics.makeRegisterEntry(domainLowercase, recordType, result.success));

    result;
  };

  public shared query ({ caller }) func get_metrics(period : Text) : async Result.Result<Metrics.MetricsData, Text> {
    if (not Principal.isController(caller)) return #err("Currently only a controller can get metrics");

    #ok(metrics.getMetrics(period, [("cidRecordsCount", Map.size(lookupAnswersMap))]));
  };

  public shared ({ caller }) func purge_metrics() : async Result.Result<Nat, Text> {
    if (not Principal.isController(caller)) return #err("Currently only a controller can purge metrics");

    #ok(metrics.purge());
  };
};
