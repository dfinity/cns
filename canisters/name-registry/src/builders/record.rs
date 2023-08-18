use crate::types::{DomainRecord, RecordName};

/// A builder pattern for constructing a `DomainRecord`.
///
/// This structure allows you to build a `DomainRecord` by setting each field
/// individually, using a fluent interface.
#[derive(Default)]
pub struct DomainRecordBuilder {
    /// The domain name, ASCII encoded.
    name: RecordName,
    /// The type of DNS record, such as "A", "CNAME", "MX", etc.
    record_type: String,
    /// The time-to-live (TTL) value, in seconds, which specifies how long the record may be cached.
    /// None if it's not set.
    ttl: u32,
    /// The data associated with this record. The structure depends on the record type.
    /// None if it's not set.
    data: String,
}

impl DomainRecordBuilder {
    /// Creates a new `DomainRecordBuilder` with default values.
    pub fn new() -> Self {
        Self::default()
    }

    /// Sets the name for the `DomainRecord`.
    /// This will overwrite any previously set name.
    pub fn name(mut self, name: RecordName) -> Self {
        self.name = name;
        self
    }

    /// Sets the record type for the `DomainRecord`.
    /// This will overwrite any previously set record type.
    pub fn record_type(mut self, record_type: String) -> Self {
        self.record_type = record_type;
        self
    }

    /// Sets the TTL for the `DomainRecord`.
    /// This will overwrite any previously set TTL value.
    pub fn ttl(mut self, ttl: u32) -> Self {
        self.ttl = ttl;
        self
    }

    /// Sets the data for the `DomainRecord`.
    /// This will overwrite any previously set data.
    pub fn data(mut self, data: String) -> Self {
        self.data = data;
        self
    }

    /// Consumes the `DomainRecordBuilder`, returning a newly constructed `DomainRecord`.
    /// If any required fields are missing, this could result in a partially constructed object.
    pub fn build(self) -> DomainRecord {
        DomainRecord {
            name: self.name,
            record_type: self.record_type,
            ttl: self.ttl,
            data: self.data,
        }
    }
}
