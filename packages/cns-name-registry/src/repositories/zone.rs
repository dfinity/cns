use crate::{
    repositories::{with_memory_manager, Memory, Repository, DOMAIN_ZONES_MEMORY_ID},
    types::{DomainZoneEntry, DomainZoneEntryInput},
};
use ic_stable_structures::BTreeMap;
use std::cell::RefCell;

use super::{RepositorySearch, RepositorySearchInto};

/// The database schema for the DomainZone repository.
///
/// DomainZone is used as the key & value hereby transorming the BTreeMap into a Set and enabling a more efficient
/// lookup and update operations when accessing stable memory.
pub type DomainZoneDatabase = BTreeMap<DomainZoneEntry, (), Memory>;

thread_local! {
  /// The memory reference to the DomainZone repository.
  static DB: RefCell<DomainZoneDatabase> = with_memory_manager(|memory_manager| {
    RefCell::new(
      BTreeMap::init(memory_manager.get(DOMAIN_ZONES_MEMORY_ID))
    )
  })
}

/// A repository that enables managing domain zones in stable memory.
pub struct DomainZoneRepository {}

/// Enables the initialization of the DomainZone repository.
impl DomainZoneRepository {
    pub fn new() -> Self {
        Self {}
    }
}

impl Default for DomainZoneRepository {
    fn default() -> Self {
        Self::new()
    }
}

/// Common interfaces for the DomainZone repository, it enables storing, retrieving and removing domain zones.
impl Repository<DomainZoneEntry> for DomainZoneRepository {
    fn get(&self, record: &DomainZoneEntry) -> Option<DomainZoneEntry> {
        let found = DB.with(|m| m.borrow_mut().get(record));

        match found.is_some() {
            true => Some(record.clone()),
            _ => None,
        }
    }

    fn insert(&self, record: &DomainZoneEntry) {
        DB.with(|m| m.borrow_mut().insert(record.clone(), ()));
    }

    fn remove(&self, record: &DomainZoneEntry) -> Option<DomainZoneEntry> {
        let removed = DB.with(|m| m.borrow_mut().remove(record));

        match removed.is_some() {
            true => Some(record.clone()),
            _ => None,
        }
    }
}

impl RepositorySearch<DomainZoneEntryInput, DomainZoneEntry> for DomainZoneRepository {
    fn search(&self, input: &DomainZoneEntryInput) -> Vec<DomainZoneEntry> {
        DB.with(|m| {
            // todo: handle panics and return an error
            let start_key = input.map_to_lower_range_key().unwrap();
            let end_key = input.map_to_upper_range_key().unwrap();

            let results = m
                .borrow()
                .range(start_key..=end_key)
                .map(|(k, _)| k)
                .collect::<Vec<DomainZoneEntry>>();

            results
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::types::{
        DomainRecord, DomainRecordInput, DomainRecordTypes, DomainZone, DomainZoneInput,
        RecordName, ZoneApexDomain,
    };

    #[test]
    fn init_domain_zone_repository() {
        let repository = DomainZoneRepository::default();
        assert!(repository
            .search(&DomainZoneEntryInput::new(
                DomainZoneInput {
                    name: Some("internetcomputer.tld.".to_string()),
                },
                DomainRecordInput::default()
            ))
            .is_empty());
    }

    #[test]
    fn insert_domain_zone() {
        let repository = DomainZoneRepository::default();
        repository.insert(&DomainZoneEntry::new(
            DomainZone {
                name: ZoneApexDomain::new(String::from("internetcomputer.tld.")).unwrap(),
            },
            DomainRecord::default(),
        ));
        repository.insert(&DomainZoneEntry::new(
            DomainZone {
                name: ZoneApexDomain::new(String::from("internetcomputer.tld.")).unwrap(),
            },
            DomainRecord {
                name: RecordName::default(),
                record_type: DomainRecordTypes::CNAME.to_string(),
                ttl: 0,
                data: "ic.boundary.network.".to_string(),
            },
        ));
        let results = repository.search(&DomainZoneEntryInput::new(
            DomainZoneInput {
                name: Some("internetcomputer.tld.".to_string()),
            },
            DomainRecordInput::default(),
        ));

        assert_eq!(results.len(), 2);
        assert_eq!(
            DomainZoneEntry::new(
                DomainZone {
                    name: ZoneApexDomain::new(String::from("internetcomputer.tld.")).unwrap(),
                },
                DomainRecord::default(),
            ),
            results.get(0).unwrap().to_owned()
        );
        assert_eq!(
            DomainZoneEntry::new(
                DomainZone {
                    name: ZoneApexDomain::new(String::from("internetcomputer.tld.")).unwrap(),
                },
                DomainRecord {
                    name: RecordName::default(),
                    record_type: DomainRecordTypes::CNAME.to_string(),
                    ttl: 0,
                    data: "ic.boundary.network.".to_string(),
                },
            ),
            results.get(1).unwrap().to_owned()
        );
    }

    #[test]
    fn remove_domain_zone_exact_match() {
        let repository = DomainZoneRepository::default();
        let domain_zone_entry = DomainZoneEntry::new(
            DomainZone {
                name: ZoneApexDomain::new(String::from("internetcomputer.tld.")).unwrap(),
            },
            DomainRecord::default(),
        );
        repository.insert(&domain_zone_entry);
        assert!(repository.get(&domain_zone_entry).is_some());
        repository.remove(&domain_zone_entry);
        assert!(repository.get(&domain_zone_entry).is_none());
    }

    #[test]
    fn search_domain_zone_partial_match() {
        let repository = DomainZoneRepository::default();
        let internetcomputer_apex =
            ZoneApexDomain::new(String::from("internetcomputer.tld.")).unwrap();
        repository.insert(&DomainZoneEntry::new(
            DomainZone {
                name: internetcomputer_apex.clone(),
            },
            DomainRecord::default(),
        ));
        repository.insert(&DomainZoneEntry::new(
            DomainZone {
                name: internetcomputer_apex.clone(),
            },
            DomainRecord {
                name: RecordName::default(),
                record_type: DomainRecordTypes::CNAME.to_string(),
                ttl: 0,
                data: "ic.boundary.network.".to_string(),
            },
        ));
        repository.insert(&DomainZoneEntry::new(
            DomainZone {
                name: internetcomputer_apex.clone(),
            },
            DomainRecord {
                name: RecordName::new(String::from("subdomain"), &internetcomputer_apex).unwrap(),
                record_type: DomainRecordTypes::CNAME.to_string(),
                ttl: 0,
                data: "ic.boundary.network.".to_string(),
            },
        ));
        repository.insert(&DomainZoneEntry::new(
            DomainZone {
                name: ZoneApexDomain::new(String::from("canister.tld.")).unwrap(),
            },
            DomainRecord {
                name: RecordName::default(),
                record_type: DomainRecordTypes::TXT.to_string(),
                ttl: 0,
                data: "ic.boundary.network.".to_string(),
            },
        ));

        let results_icp = repository.search(&DomainZoneEntryInput::new(
            DomainZoneInput {
                name: Some(internetcomputer_apex.as_str().to_string()),
            },
            DomainRecordInput::default(),
        ));

        let results_canister = repository.search(&DomainZoneEntryInput::new(
            DomainZoneInput {
                name: Some("canister.tld.".to_string()),
            },
            DomainRecordInput::default(),
        ));
        assert_eq!(results_icp.len(), 3);
        assert_eq!(results_canister.len(), 1);
    }

    #[test]
    fn get_domain_zone_exact_match() {
        let repository = DomainZoneRepository::default();
        let domain_zone_entry = DomainZoneEntry::new(
            DomainZone {
                name: ZoneApexDomain::new(String::from("internetcomputer.tld.")).unwrap(),
            },
            DomainRecord::default(),
        );
        repository.insert(&domain_zone_entry);
        assert!(repository.get(&domain_zone_entry).is_some());
    }
}
