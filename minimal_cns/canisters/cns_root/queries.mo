import Types "../../common/cns_types";
import MetricsTypes "../../common/metrics";
import Map "mo:base/Map";
import Text "mo:base/Text";
import { getTldFromDomain } "parse";

module {
  public func lookup(
    rootTld : Text,
    lookupAnswersMap : Map.Map<Text, Types.DomainRecord>,
    lookupAuthoritiesMap : Map.Map<Text, Types.DomainRecord>,
    metrics : MetricsTypes.CnsMetrics,
    domain : Text,
    recordType : Text
  ) : Types.DomainLookup{
    var answers : [Types.DomainRecord] = [];
    var authorities : [Types.DomainRecord] = [];

    let domainLowercase : Text = Text.toLower(domain);
    if (Text.endsWith(domainLowercase, #text rootTld)) {
      let tld = getTldFromDomain(domainLowercase);
      switch (Text.toUpper(recordType)) {
        case ("NC") {
          let maybeRecord : ?Types.DomainRecord = Map.get(lookupAnswersMap, Text.compare, tld);
          answers := switch maybeRecord {
            case null { [] };
            case (?record) { [record] };
          };
        };
        case _ {
          let maybeRecord : ?Types.DomainRecord = Map.get(lookupAuthoritiesMap, Text.compare, tld);
          authorities := switch maybeRecord {
            case null { [] };
            case (?record) { [record] };
          };
        };
      };
    };
    metrics.addEntry(metrics.makeLookupEntry(domainLowercase, recordType, (answers != [] or authorities != [])));

    {
      answers = answers;
      additionals = [];
      authorities = authorities;
    };
  };
}