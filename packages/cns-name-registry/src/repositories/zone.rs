use crate::{
    repositories::{with_memory_manager, Memory, Repository, DOMAIN_ZONES_MEMORY_ID},
    types::{domain_zone_byte_size, DomainName, DomainZone},
};
use ic_stable_structures::{BTreeMap, BoundedStorable, Storable};
use std::cell::RefCell;

/// The key used to store a DomainZone within the repository.
#[derive(PartialEq, Eq, PartialOrd, Ord, Clone)]
pub struct DomainZoneKey(DomainName);

/// The database schema for the DomainZone repository.
pub type DomainZoneDatabase = BTreeMap<DomainZoneKey, DomainZone, Memory>;

/// Adds serialization and deserialization support to DomainZoneKey to stable memory.
impl Storable for DomainZoneKey {
    fn to_bytes(&self) -> std::borrow::Cow<[u8]> {
        // DomainName is a String that already implements `Storable`.
        self.0.to_bytes()
    }

    fn from_bytes(bytes: std::borrow::Cow<[u8]>) -> Self {
        Self(String::from_bytes(bytes))
    }
}

/// Represents the memory required to store a DomainZoneKey in stable memory.
impl BoundedStorable for DomainZoneKey {
    const MAX_SIZE: u32 = domain_zone_byte_size::FIELD_NAME;
    const IS_FIXED_SIZE: bool = false;
}

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
impl Repository<DomainName, DomainZone> for DomainZoneRepository {
    fn get(&self, key: DomainName) -> Option<DomainZone> {
        DB.with(|m| m.borrow().get(&DomainZoneKey(key)))
    }

    fn insert(&self, key: DomainName, zone: DomainZone) -> Option<DomainZone> {
        DB.with(|m| m.borrow_mut().insert(DomainZoneKey(key), zone))
    }

    fn remove(&self, key: DomainName) -> Option<DomainZone> {
        DB.with(|m| m.borrow_mut().remove(&DomainZoneKey(key)))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn init_domain_zone_repository() {
        let repository = DomainZoneRepository::default();
        assert!(repository
            .get("internetcomputer.tld.".to_string())
            .is_none());
    }

    #[test]
    fn insert_domain_zone() {
        let repository = DomainZoneRepository::default();
        let domain_zone = DomainZone {
            name: "internetcomputer.tld.".to_string(),
            records: Default::default(),
        };
        repository.insert(domain_zone.name.clone(), domain_zone.clone());
        assert_eq!(
            repository.get(domain_zone.name.clone()).unwrap(),
            domain_zone
        );
    }

    #[test]
    fn remove_domain_zone() {
        let repository = DomainZoneRepository::default();
        let domain_zone = DomainZone {
            name: "internetcomputer.tld.".to_string(),
            records: Default::default(),
        };
        repository.insert(domain_zone.name.clone(), domain_zone.clone());
        assert!(repository.get(domain_zone.name.clone()).is_some());
        repository.remove(domain_zone.name.clone());
        assert!(repository.get(domain_zone.name.clone()).is_none());
    }

    #[test]
    fn get_domain_zone_by_key() {
        let repository = DomainZoneRepository::default();
        let domain_zone = DomainZone {
            name: "internetcomputer.tld.".to_string(),
            records: Default::default(),
        };
        repository.insert(domain_zone.name.clone(), domain_zone.clone());
        let found_domain = repository.get(domain_zone.name.clone());
        assert!(found_domain.is_some());
        assert_eq!(found_domain.unwrap().name, domain_zone.name.clone());
    }
}
