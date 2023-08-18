//! Repositories for domains and related data.

/// Common configurations for repositories.
mod setup;
pub use setup::*;

/// Repository for domain zones.
mod zone;
pub use zone::*;
