import NameRegistry "canister:name_registry";
import Text "mo:base/Text";

shared actor class () {
  let icpTld = ".icp";
  let icpTldCanisterId = "qoctq-giaaa-aaaaa-aaaea-cai";

  public shared func lookup(domain : Text, recordType : Text) : async NameRegistry.DomainLookup {
    var answers : [NameRegistry.DomainRecord] = [];
    var authorities : [NameRegistry.DomainRecord] = [];

    if (Text.endsWith(Text.toLowercase(domain), #text icpTld)) {
      switch (Text.toUppercase(recordType)) {
        case ("NC") {
          answers := [{
            name = ".icp.";
            record_type = "NC";
            ttl = 3600;
            data = icpTldCanisterId;
          }];
        };
        case _ {
          authorities := [{
            name = ".icp.";
            record_type = "NC";
            ttl = 3600;
            data = icpTldCanisterId;
          }];
        };
      };
    };

    {
      answers = answers;
      additionals = [];
      authorities = authorities;
    };
  };
};
