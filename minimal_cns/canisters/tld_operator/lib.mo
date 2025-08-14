import Metrics "../../common/metrics";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import ApiTypes "../../common/api_types";
import DomainTypes "../../common/data/domain/Types";
import Queries "queries";
import Mutations "mutations";
import Domain "../../common/data/domain";

persistent actor TldOperator {
  transient let myTld = ".icp.";
  var lookupAnswersMap = Domain.RegistrationRecordsStore.init();
  var metricsStore : Metrics.LogStore = Metrics.newStore();

  public shared func lookup(domain : Text, recordType : Text) : async ApiTypes.DomainLookup {
    Queries.lookup(
      myTld,
      lookupAnswersMap,
      Metrics.CnsMetrics(metricsStore),
      domain,
      recordType,
    );
  };

  public shared ({ caller }) func register(domain : Text, records : DomainTypes.RegistrationRecords) : async ApiTypes.RegisterResult {
    let domainLowercase : Text = Text.toLower(domain);
    let (result, recordType) = Mutations.validateAndRegister(
      caller,
      myTld,
      lookupAnswersMap,
      domainLowercase,
      records,
    );
    let metrics = Metrics.CnsMetrics(metricsStore);
    metrics.addEntry(metrics.makeRegisterEntry(domainLowercase, recordType, result.success));

    result;
  };

  public shared query ({ caller }) func get_metrics(period : Text) : async ApiTypes.GetMetricsResult {
    if (not Principal.isController(caller)) return #err("Currently only a controller can get metrics");

    let metrics = Metrics.CnsMetrics(metricsStore);
    #ok(metrics.getMetrics(period, [("icpRecordsCount", Domain.RegistrationRecordsStore.size(lookupAnswersMap))]));
  };

  public shared ({ caller }) func purge_metrics() : async ApiTypes.PurgeMetricsResult {
    if (not Principal.isController(caller)) return #err("Currently only a controller can purge metrics");

    let metrics = Metrics.CnsMetrics(metricsStore);
    #ok(metrics.purge());
  };
};
