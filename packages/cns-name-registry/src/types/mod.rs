//! Public types used for domain names.

/// Types to represent a domain name record.
mod record;
pub use record::*;

/// Types to represent a domain record type.
mod record_type;
pub use record_type::*;

/// Types to represent a domain name zone.
mod zone;
pub use zone::*;
