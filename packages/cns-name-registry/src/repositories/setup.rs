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
pub trait Repository<K, V> {
    fn get(&self, key: K) -> Option<V>;
    fn insert(&self, key: K, value: V) -> Option<V>;
    fn remove(&self, key: K) -> Option<V>;
}
