use crate::{
    repositories::RepositorySearchInto,
    types::{
        DomainRecord, DomainRecordInput, DomainZone, DomainZoneInput, RecordName, ZoneApexDomain,
    },
};
use candid::{CandidType, Decode, Deserialize, Encode};
use ic_stable_structures::{BoundedStorable, Storable};
use std::borrow::Cow;

/// In order to store a DomainZone in stable memory, we need to store the DomainZone and the DomainRecord as
/// a tuple, this enables more efficient lookup and update operations when accessing stable memory since
/// the BTreeMap is transformed into a Set and the tuple is used as a composite key.
#[derive(CandidType, Deserialize, Clone, Debug, PartialEq, PartialOrd, Eq, Ord)]
pub struct DomainZoneEntry(DomainZone, DomainRecord);

impl DomainZoneEntry {
    pub const TUPLE_ZONE_BYTE_SIZE: u32 = DomainZone::MAX_SIZE;
    pub const TUPLE_RECORD_BYTE_SIZE: u32 = DomainRecord::MAX_SIZE;

    pub const MAX_SIZE: u32 = Self::TUPLE_ZONE_BYTE_SIZE + Self::TUPLE_RECORD_BYTE_SIZE;

    pub fn new(zone: DomainZone, record: DomainRecord) -> Self {
        Self(zone, record)
    }
}

/// Represents a zone entry input for creating, updating or facilitating optional search
/// operations over the DomainZoneEntry.
#[derive(Clone, Debug)]
pub struct DomainZoneEntryInput(DomainZoneInput, DomainRecordInput);

impl DomainZoneEntryInput {
    pub fn new(zone: DomainZoneInput, record: DomainRecordInput) -> Self {
        Self(zone, record)
    }
}

impl RepositorySearchInto<DomainZoneEntry> for DomainZoneEntryInput {
    fn map_to_lower_range_key(&self) -> Result<DomainZoneEntry, String> {
        let zone = self.0.clone();
        let record = self.1.clone();
        let apex_domain = match zone.name {
            Some(name) => ZoneApexDomain::new(name).map_err(|e| e.to_string())?,
            _ => ZoneApexDomain::new(".".to_string()).map_err(|e| e.to_string())?,
        };

        Ok(DomainZoneEntry(
            DomainZone {
                name: apex_domain.clone(),
            },
            DomainRecord {
                name: match record.name {
                    Some(name) => RecordName::new(name, &apex_domain).unwrap(),
                    _ => RecordName::default(),
                },
                record_type: match record.record_type {
                    Some(record_type) => record_type,
                    _ => String::default(),
                },
                ttl: match record.ttl {
                    Some(ttl) => ttl,
                    _ => 0,
                },
                data: match record.data {
                    Some(data) => data,
                    _ => String::default(),
                },
            },
        ))
    }

    fn map_to_upper_range_key(&self) -> Result<DomainZoneEntry, String> {
        let zone = self.0.clone();
        let record = self.1.clone();
        let apex_domain = match zone.name {
            Some(name) => ZoneApexDomain::new(name).map_err(|e| e.to_string())?,
            _ => ZoneApexDomain::new(".".to_string()).map_err(|e| e.to_string())?,
        };

        Ok(DomainZoneEntry(
            DomainZone {
                name: apex_domain.clone(),
            },
            DomainRecord {
                name: match record.name {
                    Some(name) => RecordName::new(name, &apex_domain).unwrap(),
                    _ => DomainRecord::max_record_name_value(Some(apex_domain)),
                },
                record_type: match record.record_type {
                    Some(record_type) => record_type,
                    _ => DomainRecord::max_record_type_value(),
                },
                ttl: match record.ttl {
                    Some(ttl) => ttl,
                    _ => DomainRecord::max_ttl_value(),
                },
                data: match record.data {
                    Some(data) => data,
                    _ => DomainRecord::max_data_value(),
                },
            },
        ))
    }
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
    const MAX_SIZE: u32 = DomainZoneEntry::MAX_SIZE;

    const IS_FIXED_SIZE: bool = false;
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::types::{RecordName, ZoneApexDomain};

    #[test]
    fn deserialization_for_domain_zone_entry_match() {
        let zone_apex_domain = ZoneApexDomain::new(String::from("internetcomputer.icp.")).unwrap();
        let record_name = RecordName::new(String::from("@"), &zone_apex_domain).unwrap();
        let domain_zone_entry = DomainZoneEntry::new(
            DomainZone {
                name: zone_apex_domain,
            },
            DomainRecord {
                name: record_name,
                record_type: "A".to_string(),
                ttl: 3600,
                data: String::default(),
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
