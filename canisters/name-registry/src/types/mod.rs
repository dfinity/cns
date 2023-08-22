//! Public types used for domain names.

/// Types to represent a domain name record.
mod record;
pub use record::*;

/// Types to represent a record name.
mod record_name;
pub use record_name::*;

/// Types to represent a domain record type.
mod record_type;
pub use record_type::*;

/// Types to represent a domain name zone.
mod zone;
pub use zone::*;

/// Types to represent the zone apex name, the main domain name of a zone.
mod zone_apex_domain;
pub use zone_apex_domain::*;

/// Types to represent a domain name zone entry.
mod zone_entry;
pub use zone_entry::*;
