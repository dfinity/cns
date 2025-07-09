import ApiTypes "../../common/api_types";
import DomainTypes "../../common/data/domain/Types";
import Domain "../../common/data/domain";
import MetricsTypes "../../common/metrics";
import Option "mo:base/Option";
import Text "mo:base/Text";
import Iter "mo:base/Iter";
import Principal "mo:base/Principal";

module {
  let EMPTY_DOMAIN_LOOKUP : ApiTypes.DomainLookup = {
    answers = [];
    additionals = [];
    authorities = [];
  };
  public func lookup(
    myTld : Text,
    lookupAnswersMap : DomainTypes.RegistrationRecordsStore,
    metrics : MetricsTypes.CnsMetrics,
    domain : Text,
    recordType : Text,
  ) : ApiTypes.DomainLookup {
    let domainLowercase : Text = Text.toLower(domain);
    if (not Text.endsWith(domainLowercase, #text(myTld))) {
      metrics.addEntry(metrics.makeLookupEntry(domainLowercase, recordType, false));
      return EMPTY_DOMAIN_LOOKUP;
    };

    let response = switch (Text.toUpper(recordType)) {
      case ("CID" or "SID") { forwardLookup(lookupAnswersMap, domainLowercase) };
      case ("PTR") { reverseLookup(lookupAnswersMap, domainLowercase) };
      // Unsupported record types return an empty lookup
      case _ { EMPTY_DOMAIN_LOOKUP };
    };

    metrics.addEntry(metrics.makeLookupEntry(domainLowercase, recordType, response.answers != []));

    response;
  };

  public func forwardLookup(
    domainRecordsStore : DomainTypes.RegistrationRecordsStore,
    domain : Text,
  ) : ApiTypes.DomainLookup {
    // look up the domain record by the domain
    let maybeRecords = Domain.RegistrationRecordsStore.getByDomain(domainRecordsStore, domain);
    let answers = switch (maybeRecords) {
      case null { [] };
      case (?{ records }) {
        let domainRecords = Option.get(records, []);
        if (domainRecords.size() == 0) { [] } else { [domainRecords[0]] };
      };
    };

    {
      answers;
      additionals = [];
      authorities = [];
    };
  };

  // Reverse lookups have the format <principal>.reverse.<tld>
  // In this case, we expect the <principal> to be a valid principal.
  public func reverseLookup(
    domainRecordsStore : DomainTypes.RegistrationRecordsStore,
    domain : Text,
  ) : ApiTypes.DomainLookup {
    // split the domain into parts, based on "."
    let parts = Iter.toArray(Text.split(domain, #char '.'));
    // expect there to be exactly 3 parts: <principal>, reverse, <tld>
    // The 4th part is the 3rd period at the end (so parts[3] is the empty string)
    if (parts.size() != 4) {
      return { answers = []; additionals = []; authorities = [] };
    };

    let principalText = parts[0];
    // check if the first part is a valid principal - will trap if not
    // TODO: perform this check without trapping
    let principal = Principal.fromText(principalText);

    // check if the second part is "reverse"
    if (parts[1] != "reverse") {
      return { answers = []; additionals = []; authorities = [] };
    };

    // look up the PTR domain record of the principal
    let answers = switch (Domain.RegistrationRecordsStore.getPtrRecord(domainRecordsStore, domain, principal)) {
      case null { [] };
      case (?record) { [record] };
    };

    {
      answers;
      additionals = [];
      authorities = [];
    };
  };
};
