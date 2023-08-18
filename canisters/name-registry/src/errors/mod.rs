//! Various error types for failure scenarios

/// Error types for the record name.
mod record_name;
pub use record_name::*;

/// Error types for the zone apex domain.
mod zone_apex_domain;
pub use zone_apex_domain::*;
