use crate::{
    common::{MAX_DOMAIN_ASCII_CHAR_VALUE, MAX_DOMAIN_LABEL_LENGTH},
    errors::RecordNameError,
    types::ZoneApexDomain,
    utils::repeat_char,
};
use candid::{CandidType, Decode, Deserialize, Encode};
use ic_stable_structures::{BoundedStorable, Storable};
use std::{borrow::Cow, cmp};

/// The domain name, e.g. "mydomain.tld.", the name is required for all operations and must
/// end with a dot (.). Names have well defined size limits and must have the parts between
/// the dots or commonly called as labels with equal or less then 63 bytes and the entire
/// name must be under 255 bytes.
///
/// Names are encoded in ascii, have alphanumeric characters and are case insensitive, but
/// the canonical form is lowercase.
#[derive(CandidType, Deserialize, Clone, Debug, Eq, Ord, PartialEq, PartialOrd)]
pub struct RecordName(String);

impl RecordName {
    /// The maximum size of a record name is the size of the apex domain plus the size of the record name.
    pub const MAX_SIZE: usize = 255;

    /// Creates a new record name and returns an error if the name is invalid.
    ///
    /// The name will be converted to lowercase as the canonical form of any domain name is lowercase.
    pub fn new(name: String, apex_domain: &ZoneApexDomain) -> Result<Self, RecordNameError> {
        let lowercased_name = name.to_ascii_lowercase();
        Self::validate(&lowercased_name, apex_domain)?;

        Ok(Self(lowercased_name))
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }

    /// Validates the apex domain name and returns an error if it is invalid.
    pub fn validate(
        record_name: &str,
        apex_domain: &ZoneApexDomain,
    ) -> Result<(), RecordNameError> {
        if record_name.is_empty() {
            return Err(RecordNameError::NonEmptyName);
        }

        if record_name.ends_with('.') {
            return Err(RecordNameError::InvalidEndWithDot);
        }

        // a single @ is allowed as a record name, it means that the record is for the apex domain
        if record_name.eq_ignore_ascii_case("@") {
            return Ok(());
        }

        for label in record_name.split('.').collect::<Vec<&str>>() {
            if label.is_empty() {
                return Err(RecordNameError::NonEmptyLabel);
            }

            if label.len() > MAX_DOMAIN_LABEL_LENGTH {
                return Err(RecordNameError::LabelTooLong {
                    label_length: label.len(),
                    max_label_length: MAX_DOMAIN_LABEL_LENGTH,
                });
            }

            if !label
                .chars()
                .all(|c| c.is_ascii_alphanumeric() || c == '-' || c == '_')
            {
                return Err(RecordNameError::InvalidNameLabel {
                    label: label.to_string(),
                });
            }

            if label.starts_with('-') || label.ends_with('-') {
                return Err(RecordNameError::MisplacedHyphen);
            }
        }

        // Validates the fully qualified domain name
        let domain_name = format!("{}.{}", record_name, apex_domain.as_str());
        if domain_name.len() > Self::MAX_SIZE {
            return Err(RecordNameError::NameTooLong {
                name_length: domain_name.len(),
                max_name_length: Self::MAX_SIZE,
            });
        }

        if domain_name.matches('_').count() > 1
            || (domain_name.contains('_') && !domain_name.starts_with('_'))
        {
            return Err(RecordNameError::MisplacedUnderscore);
        }

        Ok(())
    }

    /// Generates the maximum value of a record name based on the apex domain.
    pub fn max_value(apex_domain: Option<ZoneApexDomain>) -> RecordName {
        let apex_domain_length = apex_domain.as_ref().map_or(0, |d| d.as_str().len());
        let max_length = cmp::max(0, Self::MAX_SIZE - apex_domain_length - 1);

        if max_length == 0 {
            return Self::default();
        }

        let (max_labels, remainder) = (max_length / 63, max_length % 63);

        let mut max_value = repeat_char(MAX_DOMAIN_ASCII_CHAR_VALUE as char, remainder);

        for _ in 0..max_labels {
            max_value = format!(
                "{}.{}",
                repeat_char(MAX_DOMAIN_ASCII_CHAR_VALUE as char, MAX_DOMAIN_LABEL_LENGTH),
                max_value
            );
        }

        Self(max_value.trim_end_matches('.').to_string())
    }

    /// Generates the minimum value of a record name.
    pub fn min_value() -> RecordName {
        Self("@".to_string())
    }
}

impl Default for RecordName {
    /// The default value of a record name is "@" which means that the record is for the apex domain.
    fn default() -> Self {
        Self("@".to_string())
    }
}

/// Adds serialization and deserialization support to RecordName to stable memory.
impl Storable for RecordName {
    fn to_bytes(&self) -> std::borrow::Cow<[u8]> {
        Cow::Owned(Encode!(self).unwrap())
    }

    fn from_bytes(bytes: std::borrow::Cow<[u8]>) -> Self {
        Decode!(bytes.as_ref(), Self).unwrap()
    }
}

/// Represents the memory required to store a RecordName in stable memory.
impl BoundedStorable for RecordName {
    const MAX_SIZE: u32 = RecordName::MAX_SIZE as u32;

    const IS_FIXED_SIZE: bool = false;
}

#[cfg(test)]
mod tests {
    use super::*;
    use rstest::rstest;

    #[rstest]
    #[case::apex_record(&"internetcomputer.tld.", &"@")]
    #[case::subdomain_record(&"internetcomputer.tld.", &"wiki")]
    #[case::multiple_subdomain_record(&"internetcomputer.tld.", &"subdomain.wiki")]
    #[case::valid_middle_hyphen(&"internetcomputer.tld.", &"subdomain-wiki")]
    #[case::valid_begin_with_underscore(&"internetcomputer.tld.", &"_canister")]
    fn record_name_validation_pass(#[case] apex_domain: &str, #[case] domain_name: &str) {
        let apex_domain = ZoneApexDomain::new(String::from(apex_domain)).unwrap();
        let record_name = RecordName::new(String::from(domain_name), &apex_domain);

        assert!(record_name.is_ok());
    }

    #[rstest]
    #[case::invalid_empty(&"internetcomputer.tld.", &"", RecordNameError::NonEmptyName)]
    #[case::non_empty_label(&"internetcomputer.tld.", &".subdomain", RecordNameError::NonEmptyLabel)]
    #[case::misplaced_hyphen_begin(&"internetcomputer.tld.", &"-domain", RecordNameError::MisplacedHyphen)]
    #[case::misplaced_hyphen_end(&"internetcomputer.tld.", &"domain-", RecordNameError::MisplacedHyphen)]
    #[case::misplaced_underscore_end(&"internetcomputer.tld.", &"domain_", RecordNameError::MisplacedUnderscore)]
    #[case::misplaced_underscore_middle(&"internetcomputer.tld.", &"domain_another", RecordNameError::MisplacedUnderscore)]
    #[case::misplaced_underscore_other_subdomain(&"internetcomputer.tld.", &"domain._another", RecordNameError::MisplacedUnderscore)]
    fn record_name_validation_fail(
        #[case] apex_domain: &str,
        #[case] domain_name: &str,
        #[case] expected_err: RecordNameError,
    ) {
        let apex_domain = ZoneApexDomain::new(String::from(apex_domain)).unwrap();
        let record_name = RecordName::new(String::from(domain_name), &apex_domain);

        assert!(record_name.is_err());
        assert_eq!(record_name.unwrap_err(), expected_err);
    }
}
