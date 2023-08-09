use crate::{
    repositories::{with_memory_manager, Memory, Repository, DOMAIN_ZONES_MEMORY_ID},
    types::DomainZoneEntry,
};
use ic_stable_structures::BTreeMap;
use std::cell::RefCell;

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

/// Enbales the initialization of the DomainZone repository.
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
    fn search(&self, key: &DomainZoneEntry) -> Vec<DomainZoneEntry> {
        DB.with(|m| {
            let results = m
                .borrow()
                .range(key..=&key.default_upper_range_key())
                .map(|(k, _)| k)
                .collect::<Vec<DomainZoneEntry>>();

            results
        })
    }

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

#[cfg(test)]
mod tests {
    use super::*;
    use crate::types::{DomainRecord, DomainRecordTypes, DomainZone};

    #[test]
    fn init_domain_zone_repository() {
        let repository = DomainZoneRepository::default();
        assert!(repository
            .search(&DomainZoneEntry::new(
                DomainZone {
                    name: "internetcomputer.tld.".to_string()
                },
                DomainRecord::default()
            ))
            .is_empty());
    }

    #[test]
    fn insert_domain_zone() {
        let repository = DomainZoneRepository::default();
        repository.insert(&DomainZoneEntry::new(
            DomainZone {
                name: "internetcomputer.tld.".to_string(),
            },
            DomainRecord::default(),
        ));
        repository.insert(&DomainZoneEntry::new(
            DomainZone {
                name: "internetcomputer.tld.".to_string(),
            },
            DomainRecord {
                name: "internetcomputer.tld.".to_string(),
                record_type: DomainRecordTypes::CNAME.to_string(),
                ttl: Some(0),
                data: Some("ic.boundary.network.".to_string()),
            },
        ));
        let results = repository.search(&DomainZoneEntry::new(
            DomainZone {
                name: "internetcomputer.tld.".to_string(),
            },
            DomainRecord::default(),
        ));

        assert_eq!(results.len(), 2);
        assert_eq!(
            DomainZoneEntry::new(
                DomainZone {
                    name: "internetcomputer.tld.".to_string(),
                },
                DomainRecord::default(),
            ),
            results.get(0).unwrap().to_owned()
        );
        assert_eq!(
            DomainZoneEntry::new(
                DomainZone {
                    name: "internetcomputer.tld.".to_string(),
                },
                DomainRecord {
                    name: "internetcomputer.tld.".to_string(),
                    record_type: DomainRecordTypes::CNAME.to_string(),
                    ttl: Some(0),
                    data: Some("ic.boundary.network.".to_string()),
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
                name: "internetcomputer.tld.".to_string(),
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
        repository.insert(&DomainZoneEntry::new(
            DomainZone {
                name: "internetcomputer.tld.".to_string(),
            },
            DomainRecord::default(),
        ));
        repository.insert(&DomainZoneEntry::new(
            DomainZone {
                name: "internetcomputer.tld.".to_string(),
            },
            DomainRecord {
                name: "internetcomputer.tld.".to_string(),
                record_type: DomainRecordTypes::CNAME.to_string(),
                ttl: Some(0),
                data: Some("ic.boundary.network.".to_string()),
            },
        ));
        repository.insert(&DomainZoneEntry::new(
            DomainZone {
                name: "internetcomputer.tld.".to_string(),
            },
            DomainRecord {
                name: "subdomain.internetcomputer.tld.".to_string(),
                record_type: DomainRecordTypes::CNAME.to_string(),
                ttl: Some(0),
                data: Some("ic.boundary.network.".to_string()),
            },
        ));
        repository.insert(&DomainZoneEntry::new(
            DomainZone {
                name: "canister.tld.".to_string(),
            },
            DomainRecord {
                name: "canister.tld.".to_string(),
                record_type: DomainRecordTypes::TXT.to_string(),
                ttl: Some(0),
                data: Some("ic.boundary.network.".to_string()),
            },
        ));

        let results_icp = repository.search(&DomainZoneEntry::new(
            DomainZone {
                name: "internetcomputer.tld.".to_string(),
            },
            DomainRecord::default(),
        ));

        let results_canister = repository.search(&DomainZoneEntry::new(
            DomainZone {
                name: "canister.tld.".to_string(),
            },
            DomainRecord::default(),
        ));
        assert_eq!(results_icp.len(), 3);
        assert_eq!(results_canister.len(), 1);
    }

    #[test]
    fn get_domain_zone_exact_match() {
        let repository = DomainZoneRepository::default();
        let domain_zone_entry = DomainZoneEntry::new(
            DomainZone {
                name: "internetcomputer.tld.".to_string(),
            },
            DomainRecord::default(),
        );
        repository.insert(&domain_zone_entry);
        assert!(repository.get(&domain_zone_entry).is_some());
    }
}
