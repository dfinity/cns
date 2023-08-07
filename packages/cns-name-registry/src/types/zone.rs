use crate::types::{domain_record_byte_size::MAX_SIZE as MAX_RECORD_SIZE, DomainRecord};
use candid::{CandidType, Decode, Deserialize, Encode};
use ic_stable_structures::{BoundedStorable, Storable};
use std::{borrow::Cow, collections::HashMap};

/// MAX_RECORDS_PER_ZONE represents the maximum number of record entries that a DomainZone can have.
pub const MAX_RECORDS_PER_ZONE: u32 = 25_000;

/// The domain name ascii encoded, e.g. "mydomain.tld.", must end with a dot (.) and can't be longer than 255 bytes.
pub type DomainName = String;

/// Main struct that represents a domain zone with all the records that it is responsible for.
#[derive(CandidType, Deserialize, Clone, Debug, PartialEq, Eq)]
pub struct DomainZone {
    /// The domain name that this zone is managing.
    pub name: DomainName,
    /// Map of name records that this zone is responsible for, these records are used to resolve lookup queries.
    pub records: HashMap<DomainName, Vec<DomainRecord>>,
}

/// Size definitions for DomainZone.
pub mod domain_zone_byte_size {
    use super::{MAX_RECORDS_PER_ZONE, MAX_RECORD_SIZE};

    // The size of each field in a DomainZone.
    pub const RECORDS_KEY: u32 = 255;
    pub const FIELD_NAME: u32 = 255;
    pub const FIELD_RECORDS: u32 = (MAX_RECORD_SIZE + RECORDS_KEY) * MAX_RECORDS_PER_ZONE;

    /// The maximum byte size of a DomainZone.
    pub const MAX_SIZE: u32 = FIELD_NAME + FIELD_RECORDS;
}

/// Adds serialization and deserialization support to DomainZone to stable memory.
impl Storable for DomainZone {
    fn to_bytes(&self) -> std::borrow::Cow<[u8]> {
        Cow::Owned(Encode!(self).unwrap())
    }

    fn from_bytes(bytes: std::borrow::Cow<[u8]>) -> Self {
        Decode!(bytes.as_ref(), Self).unwrap()
    }
}

/// Represents the memory required to store a DomainZone in stable memory.
impl BoundedStorable for DomainZone {
    const MAX_SIZE: u32 = domain_zone_byte_size::MAX_SIZE;

    const IS_FIXED_SIZE: bool = false;
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn bounded_storable_for_domain_zone_has_expected_size() {
        assert_eq!(DomainZone::MAX_SIZE, domain_zone_byte_size::MAX_SIZE);
    }

    #[test]
    fn deserialization_for_domain_zone_match() {
        let domain_zone = DomainZone {
            name: "internetcomputer.tld.".to_string(),
            records: HashMap::from([
                (
                    "docs.internetcomputer.tld.".to_string(),
                    vec![
                        DomainRecord {
                            name: "docs.internetcomputer.tld.".to_string(),
                            record_type: "CID".to_string(),
                            ttl: 3600,
                            data: "qoctq-giaaa-aaaaa-aaaea-cai".to_string(),
                        },
                        DomainRecord {
                            name: "docs.internetcomputer.tld.".to_string(),
                            record_type: "A".to_string(),
                            ttl: 60,
                            data: "127.0.0.1".to_string(),
                        },
                    ],
                ),
                (
                    "internetcomputer.tld.".to_string(),
                    vec![DomainRecord {
                        name: "internetcomputer.tld.".to_string(),
                        record_type: "CNAME".to_string(),
                        ttl: 3600,
                        data: "boundary.icp.tld.".to_string(),
                    }],
                ),
            ]),
        };

        let serialized_domain_zone = domain_zone.to_bytes();
        let deserialized_domain_zone = DomainZone::from_bytes(serialized_domain_zone);
        let main_domain = deserialized_domain_zone
            .records
            .get("internetcomputer.tld.")
            .unwrap();
        let docs_domain = deserialized_domain_zone
            .records
            .get("docs.internetcomputer.tld.")
            .unwrap();

        assert_eq!(domain_zone.name, deserialized_domain_zone.name);
        assert_eq!(deserialized_domain_zone.records.len(), 2);
        assert_eq!(main_domain.len(), 1);
        assert_eq!(
            main_domain.get(0).unwrap().data,
            "boundary.icp.tld.".to_string()
        );
        assert_eq!(docs_domain.len(), 2);
        assert_eq!(
            docs_domain.get(0).unwrap().data,
            "qoctq-giaaa-aaaaa-aaaea-cai".to_string()
        );
        assert_eq!(docs_domain.get(1).unwrap().data, "127.0.0.1".to_string());
    }
}
