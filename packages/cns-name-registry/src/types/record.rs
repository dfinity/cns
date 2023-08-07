use candid::{CandidType, Decode, Deserialize, Encode};
use ic_stable_structures::{BoundedStorable, Storable};
use std::borrow::Cow;

/// DomainRecord represents a Chain Name System (CNS) record item.
#[derive(CandidType, Deserialize, Clone, Debug, PartialEq, Eq)]
pub struct DomainRecord {
    /// The domain name, e.g. "mydomain.tld.", the name is required for all operations and must
    /// end with a dot (.). Names have well defined size limits and must have the parts between
    /// the dots or commonly called as labels with equal or less then 63 bytes and the entire
    /// name must be under 255 bytes.
    ///
    /// Names are encoded in ascii and are case insensitive, but the canonical form is lowercase.
    pub name: String,
    /// The record type refers to the classification or category of a specific record within the
    /// system, e.g. "CID", "A", "CNAME", "TXT", "MX", "AAAA", "NC", "NS", "DNSKEY", "NSEC".
    ///
    /// Also, "ANY" is a reserved type that can only be used in lookups to retrieve all records of a domain.
    ///
    /// Record types can have maximum of 12 bytes, are encoded in ascii and are case insensitive,
    /// but the canonical form is uppercase.
    pub record_type: String,
    /// The Time to Live (TTL) is a parameter in a record that specifies the amount of time for
    /// which the record should be cached before being refreshed from the authoritative naming canister.
    ///
    /// This value must be set in seconds and the minimum value is 0 seconds, which means not cached.
    /// Common values for TTL include 3600 seconds (1 hour), 86400 seconds (24 hours), or other intervals
    /// based on specific needs.
    pub ttl: u32,
    /// The record data in a domaiØn record refers to the specific information associated with that record type.
    /// Format of the data depends on the type of record to fit its purpose, but it must not exceed 2550 bytes.
    pub data: String,
}

/// Size definitions for DomainRecords.
pub mod domain_record_byte_size {
    // The size of each field in a DomainRecord.
    pub const FIELD_NAME: u32 = 255;
    pub const FIELD_RECORD_TYPE: u32 = 12;
    pub const FIELD_TTL: u32 = 4;
    pub const FIELD_DATA: u32 = 2550;

    /// The maximum byte size of a DomainRecord.
    pub const MAX_SIZE: u32 = FIELD_NAME + FIELD_RECORD_TYPE + FIELD_TTL + FIELD_DATA;
}

/// Adds serialization and deserialization support to DomainRecord to stable memory.
impl Storable for DomainRecord {
    fn to_bytes(&self) -> std::borrow::Cow<[u8]> {
        Cow::Owned(Encode!(self).unwrap())
    }

    fn from_bytes(bytes: std::borrow::Cow<[u8]>) -> Self {
        Decode!(bytes.as_ref(), Self).unwrap()
    }
}

/// Represents the memory required to store a DomainRecord in stable memory.
impl BoundedStorable for DomainRecord {
    const MAX_SIZE: u32 = domain_record_byte_size::MAX_SIZE;

    const IS_FIXED_SIZE: bool = false;
}

#[cfg(test)]
mod tests {
    use super::*;
    use ic_stable_structures::{BoundedStorable, Storable};
    use std::borrow::Cow;

    #[test]
    fn bounded_storable_for_domain_record_has_expected_size() {
        assert_eq!(DomainRecord::MAX_SIZE, domain_record_byte_size::MAX_SIZE);
    }

    #[test]
    fn deserialization_for_domain_record_match() {
        let domain_record = DomainRecord {
            name: "internetcomputer.tld.".to_string(),
            record_type: "CID".to_string(),
            ttl: 3600,
            data: "qoctq-giaaa-aaaaa-aaaea-cai".to_string(),
        };
        let bytes = domain_record.to_bytes();
        let domain_record_back = DomainRecord::from_bytes(Cow::Borrowed(&bytes));
        assert_eq!(domain_record.name, domain_record_back.name);
        assert_eq!(domain_record.record_type, domain_record_back.record_type);
        assert_eq!(domain_record.ttl, domain_record_back.ttl);
        assert_eq!(domain_record.data, domain_record_back.data);
    }
}
