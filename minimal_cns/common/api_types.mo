import DomainTypes "data/domain/Types";
import Metrics "metrics";
import Result "mo:base/Result";

module {
  public type OperationResult = {
    success : Bool;
    message : ?Text;
  };
  public type RegisterResult = OperationResult;

  public type LookupResponse = {
    answers : [DomainTypes.DomainRecord];
    additionals : [DomainTypes.DomainRecord];
    authorities : [DomainTypes.DomainRecord];
  };

  public type GetMetricsResult = Result.Result<Metrics.MetricsData, Text>;
  public type PurgeMetricsResult = Result.Result<Nat, Text>
};
