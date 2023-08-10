use crate::types::ZoneApexDomain;
use candid::{CandidType, Decode, Deserialize, Encode};
use ic_stable_structures::Storable;
use std::borrow::Cow;

/// Represents a domain zone with all the records that it is responsible for.
///
/// The zone name correlates to the apex domain of a zone and manages a list of records associated with it.
#[derive(Clone, Debug, Default, Ord, Eq, CandidType, Deserialize, PartialEq, PartialOrd)]
pub struct DomainZone {
    /// The zone name correlates to the main domain of a zone and manages a list of records associated with it.
    pub name: ZoneApexDomain,
}

impl DomainZone {
    pub const FIELD_NAME_BYTE_SIZE: u32 = 255;

    /// The maximum byte size of a DomainZone.
    ///  
    /// Represents the memory required to store a DomainZone in stable memory.
    pub const MAX_SIZE: u32 = Self::FIELD_NAME_BYTE_SIZE;

    pub fn new(name: ZoneApexDomain) -> Self {
        Self { name }
    }
}

/// DomainZoneInput represents a zone apex item input for creating, updating or facilitating optional search
/// operations over the DomainZone.
#[derive(Clone, Debug, Default)]
pub struct DomainZoneInput {
    /// The zone apex name, e.g. "mydomain.tld.".
    pub name: Option<String>,
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn deserialization_for_domain_zone_match() {
        let domain_zone = DomainZone {
            name: ZoneApexDomain::new(String::from("internetcomputer.tld.")).unwrap(),
        };

        let serialized_domain_zone = domain_zone.to_bytes();
        let deserialized_domain_zone = DomainZone::from_bytes(serialized_domain_zone);

        assert_eq!(domain_zone.name, deserialized_domain_zone.name);
    }
}
