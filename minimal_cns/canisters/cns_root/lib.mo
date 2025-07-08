import Text "mo:base/Text";
import Metrics "../../common/metrics";
import Principal "mo:base/Principal";
import ApiTypes "../../common/api_types";
import DomainTypes "../../common/data/domain/Types";
import Domain "../../common/data/domain";
import Queries "queries";
import Mutations "mutations";

shared actor class () {
  let icpTld = ".icp.";

  stable var lookupAnswersMap = Domain.DomainRecordsStore.init();
  stable var lookupAuthoritiesMap = Domain.DomainRecordsStore.init();

  stable var metricsStore : Metrics.LogStore = Metrics.newStore();
  let metrics = Metrics.CnsMetrics(metricsStore);

  public shared func lookup(domain : Text, recordType : Text) : async ApiTypes.DomainLookup {
    Queries.lookup(
      icpTld,
      lookupAnswersMap,
      lookupAuthoritiesMap,
      metrics,
      domain,
      recordType,
    );
  };

  public shared ({ caller }) func register(domain : Text, records : DomainTypes.RegistrationRecords) : async (ApiTypes.RegisterResult) {
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

  public shared query ({ caller }) func get_metrics(period : Text) : async ApiTypes.GetMetricsResult {
    if (not Principal.isController(caller)) {
      return #err("Currently only a controller can get metrics");
    };
    return #ok(metrics.getMetrics(period, [("ncRecordsCount", Domain.DomainRecordsStore.size(lookupAnswersMap))]));
  };

  public shared ({ caller }) func purge_metrics() : async ApiTypes.PurgeMetricsResult {
    if (not Principal.isController(caller)) {
      return #err("Currently only a controller can purge metrics");
    };
    return #ok(metrics.purge());
  };
};
