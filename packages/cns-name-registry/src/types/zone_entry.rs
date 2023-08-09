use crate::types::{DomainRecord, DomainZone};
use candid::{CandidType, Decode, Deserialize, Encode};
use ic_stable_structures::{BoundedStorable, Storable};
use std::borrow::Cow;

/// In order to store a DomainZone in stable memory, we need to store the DomainZone and the DomainRecord as
/// a tuple, this enables more efficient lookup and update operations when accessing stable memory since
/// the BTreeMap is transformed into a Set and the tuple is used as a composite key.
#[derive(CandidType, Deserialize, Clone, Debug, PartialEq, PartialOrd, Eq, Ord)]
pub struct DomainZoneEntry(DomainZone, DomainRecord);

impl DomainZoneEntry {
    pub fn default_upper_range_key(&self) -> Self {
        let zone = self.0.clone();
        let record = self.1.clone();

        Self(
            DomainZone { name: zone.name },
            DomainRecord {
                name: match record.name.is_empty() {
                    true => DomainRecord::max_domain_name_value(),
                    _ => record.name,
                },
                record_type: match record.record_type.is_empty() {
                    true => DomainRecord::max_record_type_value(),
                    _ => record.record_type,
                },
                ttl: match record.ttl.is_some() {
                    true => record.ttl,
                    _ => Some(DomainRecord::max_ttl_value()),
                },
                data: match record.data.is_some() {
                    true => record.data,
                    _ => Some(DomainRecord::max_data_value()),
                },
            },
        )
    }

    pub fn new(zone: DomainZone, record: DomainRecord) -> Self {
        Self(zone, record)
    }
}

/// Size definitions for DomainZoneEntry.
pub mod domain_zone_entry_byte_size {
    use crate::types::{domain_record_byte_size, domain_zone_byte_size};

    // The size of each field in a DomainZoneEntry.
    pub const TUPLE_ZONE: u32 = domain_zone_byte_size::MAX_SIZE;
    pub const TUPLE_RECORD: u32 = domain_record_byte_size::MAX_SIZE;

    /// The maximum byte size of a DomainZoneEntry.
    pub const MAX_SIZE: u32 = TUPLE_ZONE + TUPLE_RECORD;
}

// Adds serialization and deserialization support to DomainZone to stable memory.
impl Storable for DomainZoneEntry {
    fn to_bytes(&self) -> std::borrow::Cow<[u8]> {
        Cow::Owned(Encode!(self).unwrap())
    }

    fn from_bytes(bytes: std::borrow::Cow<[u8]>) -> Self {
        Decode!(bytes.as_ref(), Self).unwrap()
    }
}

/// Represents the memory required to store a DomainZone in stable memory.
impl BoundedStorable for DomainZoneEntry {
    const MAX_SIZE: u32 = domain_zone_entry_byte_size::MAX_SIZE;

    const IS_FIXED_SIZE: bool = false;
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn bounded_storable_for_domain_zone_entry_has_expected_size() {
        assert_eq!(
            DomainZoneEntry::MAX_SIZE,
            domain_zone_entry_byte_size::MAX_SIZE
        );
    }

    #[test]
    fn deserialization_for_domain_zone_entry_match() {
        let domain_zone_entry = DomainZoneEntry::new(
            DomainZone {
                name: "internetcomputer.icp.".to_string(),
            },
            DomainRecord {
                name: "internetcomputer.icp.".to_string(),
                record_type: "A".to_string(),
                ttl: Some(3600),
                data: None,
            },
        );

        let serialized_domain_zone = domain_zone_entry.to_bytes();
        let deserialized_domain_zone = DomainZoneEntry::from_bytes(serialized_domain_zone);

        assert_eq!(domain_zone_entry.0.name, deserialized_domain_zone.0.name);
        assert_eq!(domain_zone_entry.1.name, deserialized_domain_zone.1.name);
        assert_eq!(
            domain_zone_entry.1.record_type,
            deserialized_domain_zone.1.record_type
        );
        assert_eq!(domain_zone_entry.1.ttl, deserialized_domain_zone.1.ttl);
        assert_eq!(domain_zone_entry.1.data, deserialized_domain_zone.1.data);
    }
}
