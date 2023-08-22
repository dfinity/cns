use crate::{
    repositories::RepositorySearchInto,
    types::{
        DomainRecord, DomainRecordInput, DomainZone, DomainZoneInput, RecordName, ZoneApexDomain,
    },
};
use ic_stable_structures::{BoundedStorable, Storable};

/// In order to store a DomainZone in stable memory, we need to store the DomainZone and the DomainRecord as
/// a tuple, this enables more efficient lookup and update operations when accessing stable memory since
/// the BTreeMap is transformed into a Set and the tuple is used as a composite key.
#[derive(Clone, Debug, Eq, PartialEq, Ord, PartialOrd)]
pub struct DomainZoneEntry((DomainZone, DomainRecord));

impl DomainZoneEntry {
    pub fn new(zone: DomainZone, record: DomainRecord) -> Self {
        Self((zone, record))
    }
}

// Adds serialization and deserialization support to DomainZone to stable memory.
impl Storable for DomainZoneEntry {
    fn to_bytes(&self) -> std::borrow::Cow<[u8]> {
        self.0.to_bytes()
    }

    fn from_bytes(bytes: std::borrow::Cow<[u8]>) -> Self {
        Self(<(DomainZone, DomainRecord)>::from_bytes(bytes))
    }
}

/// Represents the memory required to store a DomainZone in stable memory.
impl BoundedStorable for DomainZoneEntry {
    const MAX_SIZE: u32 = <(DomainZone, DomainRecord)>::MAX_SIZE;

    const IS_FIXED_SIZE: bool = false;
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
            Some(name) => ZoneApexDomain::new(name),
            _ => Ok(ZoneApexDomain::default()),
        }
        .map_err(|e| e.to_string())?;

        Ok(DomainZoneEntry((
            DomainZone {
                name: apex_domain.clone(),
            },
            DomainRecord {
                name: match record.name {
                    Some(name) => RecordName::new(name, &apex_domain).unwrap(),
                    _ => RecordName::default(),
                },
                record_type: record.record_type.unwrap_or_default(),
                ttl: record.ttl.unwrap_or(0),
                data: record.data.unwrap_or_default(),
            },
        )))
    }

    fn map_to_upper_range_key(&self) -> Result<DomainZoneEntry, String> {
        let zone = self.0.clone();
        let record = self.1.clone();
        let apex_domain = match zone.name {
            Some(name) => ZoneApexDomain::new(name).map_err(|e| e.to_string())?,
            _ => ZoneApexDomain::new(".".to_string()).map_err(|e| e.to_string())?,
        };

        Ok(DomainZoneEntry((
            DomainZone {
                name: apex_domain.clone(),
            },
            DomainRecord {
                name: match record.name {
                    Some(name) => RecordName::new(name, &apex_domain).unwrap(),
                    _ => DomainRecord::max_record_name_value(Some(apex_domain)),
                },
                record_type: record
                    .record_type
                    .unwrap_or(DomainRecord::max_record_type_value()),
                ttl: record.ttl.unwrap_or(DomainRecord::max_ttl_value()),
                data: record.data.unwrap_or(DomainRecord::max_data_value()),
            },
        )))
    }
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
        )
        .0;

        let serialized_domain_zone = domain_zone_entry.to_bytes();
        let deserialized_domain_zone = DomainZoneEntry::from_bytes(serialized_domain_zone).0;

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
