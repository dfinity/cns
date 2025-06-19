import Map "mo:base/Map";
import Types "../../common/cns_types";
import MetricsTypes "../../common/metrics";
import Option "mo:base/Option";
import Text "mo:base/Text";

module {
  public func lookup(
    myTld : Text,
    lookupAnswersMap : Map.Map<Text, Types.RegistrationRecords>,
    metrics : MetricsTypes.CnsMetrics,
    domain : Text,
    recordType : Text
  ) : Types.DomainLookup {
    var answers : [Types.DomainRecord] = [];
    let domainLowercase : Text = Text.toLower(domain);

    if (Text.endsWith(domainLowercase, #text myTld)) {
      switch (Text.toUpper(recordType)) {
        case ("CID") {
          let maybeRecords : ?Types.RegistrationRecords = Map.get(lookupAnswersMap, Text.compare, domainLowercase);
          answers := switch (maybeRecords) {
            case (null) { [] };
            case (?records) {
              let domainRecords = Option.get(records.records, []);
              if (domainRecords.size() == 0) { [] } else { [domainRecords[0]] };
            };
          };
        };
        case _ {};
      };
    };
    metrics.addEntry(metrics.makeLookupEntry(domainLowercase, recordType, answers != []));

    {
      answers = answers;
      additionals = [];
      authorities = [];
    };
  }
}