import Map "mo:base/Map";
import Text "mo:base/Text";
import Metrics "../../common/metrics";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Types "../../common/cns_types";
import Queries "queries";
import Mutations "mutations";

shared actor class () {
  let icpTld = ".icp.";

  type DomainRecordsMap = Map.Map<Text, Types.DomainRecord>;
  stable var lookupAnswersMap : DomainRecordsMap = Map.empty();
  stable var lookupAuthoritiesMap : DomainRecordsMap = Map.empty();

  stable var metricsStore : Metrics.LogStore = Metrics.newStore();
  let metrics = Metrics.CnsMetrics(metricsStore);

  public shared func lookup(domain : Text, recordType : Text) : async Types.DomainLookup {
    Queries.lookup(
      icpTld,
      lookupAnswersMap,
      lookupAuthoritiesMap,
      metrics,
      domain,
      recordType,
    );
  };

  public shared ({ caller }) func register(domain : Text, records : Types.RegistrationRecords) : async (Types.RegisterResult) {
    let (result, recordType) = Mutations.validateAndRegister(
      caller,
      icpTld,
      domain,
      lookupAnswersMap,
      lookupAuthoritiesMap,
      records,
    );
    metrics.addEntry(metrics.makeRegisterEntry(Text.toLower(domain), recordType, result.success));

    result;
  };

  public shared query ({ caller }) func get_metrics(period : Text) : async Result.Result<Metrics.MetricsData, Text> {
    if (not Principal.isController(caller)) {
      return #err("Currently only a controller can get metrics");
    };
    return #ok(metrics.getMetrics(period, [("ncRecordsCount", Map.size(lookupAnswersMap))]));
  };

  public shared ({ caller }) func purge_metrics() : async Result.Result<Nat, Text> {
    if (not Principal.isController(caller)) {
      return #err("Currently only a controller can purge metrics");
    };
    return #ok(metrics.purge());
  };
};
