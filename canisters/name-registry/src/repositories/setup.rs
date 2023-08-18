use ic_stable_structures::{
    memory_manager::{MemoryId, MemoryManager, VirtualMemory},
    DefaultMemoryImpl,
};
use std::cell::RefCell;

/// Stable memory id used to store the domain zones.
pub const DOMAIN_ZONES_MEMORY_ID: MemoryId = MemoryId::new(1);

/// Memory layout for the stable memory.
pub type Memory = VirtualMemory<DefaultMemoryImpl>;

thread_local! {
  // The memory manager is used for simulating multiple memories. Given a `MemoryId` it can
  // return a memory that can be used by stable structures.
  static MEMORY_MANAGER: RefCell<MemoryManager<DefaultMemoryImpl>> =
      RefCell::new(MemoryManager::init(DefaultMemoryImpl::default()));
}

/// A helper function that executes a closure with the memory manager.
pub fn with_memory_manager<R>(f: impl FnOnce(&MemoryManager<DefaultMemoryImpl>) -> R) -> R {
    MEMORY_MANAGER.with(|cell| f(&cell.borrow()))
}

/// A repository is a generic interface for storing and retrieving data.
pub trait Repository<Record> {
    /// Returns `true` if the repository contains a record for the specified key.
    fn exists(&self, record: &Record) -> bool;

    /// Inserts a record into the repository.
    fn insert(&self, record: Record);

    /// Removes a record from the repository.
    fn remove(&self, record: &Record) -> bool;
}

/// Responsible for searching for records in a repository.
pub trait RepositorySearch<SearchInput, SearchResultItem>
where
    SearchInput: RepositorySearchInto<SearchResultItem>,
    Self: Repository<SearchResultItem>,
{
    /// Searches for records in a repository based on the search input and returns a list of results
    /// that match the search criteria and are within the range of the search input.
    fn search(&self, input: &SearchInput) -> Vec<SearchResultItem>;
}

/// This trait facilitates the mapping between a search input and the target ranges for searching in a repository.
pub trait RepositorySearchInto<SearchResultItem> {
    /// Converts the search input into a lower range key for searching in a repository.
    fn map_to_lower_range_key(&self) -> Result<SearchResultItem, String>;

    /// Converts the search input into a upper range key for searching in a repository.
    fn map_to_upper_range_key(&self) -> Result<SearchResultItem, String>;
}
