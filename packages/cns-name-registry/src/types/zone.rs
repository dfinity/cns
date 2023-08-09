use crate::types::DomainName;
use candid::{CandidType, Decode, Deserialize, Encode};
use ic_stable_structures::{BoundedStorable, Storable};
use std::borrow::Cow;

/// Main struct that represents a domain zone with all the records that it is responsible for.
///
/// It contains the domain name and a list of records that are managed by the zone.
#[derive(Clone, Debug, Ord, Eq, CandidType, Deserialize, PartialEq, PartialOrd)]
pub struct DomainZone {
    /// The zone name correlates to the main domain of a zone and manages a list of records associated with it.
    pub name: DomainName,
}

/// Size definitions for DomainZone.
pub mod domain_zone_byte_size {
    // The size of each field in a DomainZone.
    pub const FIELD_NAME: u32 = 255;

    /// The maximum byte size of a DomainZone.
    pub const MAX_SIZE: u32 = FIELD_NAME;
}

impl Default for DomainZone {
    fn default() -> Self {
        Self {
            name: "".to_string(),
        }
    }
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
        };

        let serialized_domain_zone = domain_zone.to_bytes();
        let deserialized_domain_zone = DomainZone::from_bytes(serialized_domain_zone);

        assert_eq!(domain_zone.name, deserialized_domain_zone.name);
    }
}
