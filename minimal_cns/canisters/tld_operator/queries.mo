import ApiTypes "../../common/api_types";
import DomainTypes "../../common/data/domain/Types";
import Domain "../../common/data/domain";
import MetricsTypes "../../common/metrics";
import Option "mo:base/Option";
import Text "mo:base/Text";

module {
  public func lookup(
    myTld : Text,
    lookupAnswersMap : DomainTypes.RegistrationRecordsStore,
    metrics : MetricsTypes.CnsMetrics,
    domain : Text,
    recordType : Text,
  ) : ApiTypes.DomainLookup {
    var answers : [DomainTypes.DomainRecord] = [];
    let domainLowercase : Text = Text.toLower(domain);

    if (Text.endsWith(domainLowercase, #text myTld)) {
      switch (Text.toUpper(recordType)) {
        case ("CID") {
          let maybeRecords : ?DomainTypes.RegistrationRecordsWithPrincipals = Domain.RegistrationRecordsStore.getByDomain(lookupAnswersMap, domainLowercase);
          answers := switch (maybeRecords) {
            case (null) { [] };
            case (?{ records }) {
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
  };
};
