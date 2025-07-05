import APITypes "../../common/api_types";
import DomainTypes "../../common/data/domain/Types";
import Domain "../../common/data/domain";
import MetricsTypes "../../common/metrics";
import Text "mo:base/Text";
import { getTldFromDomain } "parse";

module {
  public func lookup(
    rootTld : Text,
    lookupAnswersMap : DomainTypes.DomainRecordsStore,
    lookupAuthoritiesMap : DomainTypes.DomainRecordsStore,
    metrics : MetricsTypes.CnsMetrics,
    domain : Text,
    recordType : Text,
  ) : APITypes.DomainLookup {
    var answers : [DomainTypes.DomainRecord] = [];
    var authorities : [DomainTypes.DomainRecord] = [];

    let domainLowercase : Text = Text.toLower(domain);
    if (Text.endsWith(domainLowercase, #text rootTld)) {
      let tld = getTldFromDomain(domainLowercase);
      switch (Text.toUpper(recordType)) {
        case ("NC") {
          let maybeRecord : ?DomainTypes.DomainRecord = Domain.DomainRecordsStore.getByDomain(lookupAnswersMap, tld); 
          answers := switch maybeRecord {
            case null { [] };
            case (?record) { [record] };
          };
        };
        case _ {
          let maybeRecord : ?DomainTypes.DomainRecord = Domain.DomainRecordsStore.getByDomain(lookupAuthoritiesMap, tld); 
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
