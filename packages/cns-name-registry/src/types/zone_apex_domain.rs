use crate::{
    common::{MAX_DOMAIN_LABEL_LENGTH, MAX_DOMAIN_NAME_LENGTH},
    errors::ZoneApexDomainError,
};
use candid::{CandidType, Decode, Deserialize, Encode};
use ic_stable_structures::{BoundedStorable, Storable};
use std::borrow::Cow;

/// The apex domain name, e.g. "mydomain.tld.", the name is required for all operations and must
/// end with a dot (.). Names have well defined size limits and must have the parts between
/// the dots or commonly called as labels with equal or less then 63 bytes and the entire
/// name must be under 255 bytes.
///
/// Names are encoded in ascii, have alphanumeric characters and are case insensitive, but
/// the canonical form is lowercase.
#[derive(CandidType, Deserialize, Clone, Debug, Eq, Ord, PartialEq, PartialOrd)]
pub struct ZoneApexDomain(String);

impl ZoneApexDomain {
    /// The maximum size of a domain name.
    pub const MAX_SIZE: usize = MAX_DOMAIN_NAME_LENGTH;

    /// Creates a new apex domain name and returns an error if it is invalid.
    pub fn new(name: String) -> Result<Self, ZoneApexDomainError> {
        Self::validate(&name)?;

        Ok(Self(name))
    }

    /// Returns the domain name as a primitive string.
    pub fn as_str(&self) -> &str {
        &self.0
    }

    /// Validates the apex domain name and returns an error if it is invalid.
    pub fn validate(domain_name: &str) -> Result<(), ZoneApexDomainError> {
        if domain_name.is_empty() {
            return Err(ZoneApexDomainError::NonEmptyDomain);
        }

        if domain_name.len() > MAX_DOMAIN_NAME_LENGTH {
            return Err(ZoneApexDomainError::DomainTooLong {
                domain_name_length: domain_name.len(),
                max_domain_name_length: MAX_DOMAIN_NAME_LENGTH,
            });
        }

        if !domain_name.ends_with('.') {
            return Err(ZoneApexDomainError::MissingEndWithDot);
        }

        let labels: Vec<&str> = domain_name.split('.').collect::<Vec<&str>>();
        for label in &labels[0..labels.len() - 1] {
            if label.is_empty() {
                return Err(ZoneApexDomainError::NonEmptyLabel);
            }

            if label.len() > MAX_DOMAIN_LABEL_LENGTH {
                return Err(ZoneApexDomainError::DomainLabelTooLong {
                    label_length: label.len(),
                    max_label_length: MAX_DOMAIN_LABEL_LENGTH,
                });
            }

            if !label.chars().all(|c| c.is_ascii_alphanumeric() || c == '-') {
                return Err(ZoneApexDomainError::InvalidDomainNameLabel {
                    label: label.to_string(),
                });
            }

            if label.starts_with('-') || label.ends_with('-') {
                return Err(ZoneApexDomainError::MisplacedHyphen);
            }
        }

        Ok(())
    }
}

impl Default for ZoneApexDomain {
    fn default() -> Self {
        Self(".".to_string())
    }
}

/// Adds serialization and deserialization support to ZoneApexDomain to stable memory.
impl Storable for ZoneApexDomain {
    fn to_bytes(&self) -> std::borrow::Cow<[u8]> {
        Cow::Owned(Encode!(self).unwrap())
    }

    fn from_bytes(bytes: std::borrow::Cow<[u8]>) -> Self {
        Decode!(bytes.as_ref(), Self).unwrap()
    }
}

/// Represents the memory required to store a ZoneApexDomain in stable memory.
impl BoundedStorable for ZoneApexDomain {
    const MAX_SIZE: u32 = ZoneApexDomain::MAX_SIZE as u32;

    const IS_FIXED_SIZE: bool = false;
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::utils::max_domain_name;
    use rstest::rstest;

    #[rstest]
    #[case::regular_domain_name(&"internetcomputer.tld.")]
    #[case::short_domain_name(&"a.tld.")]
    #[case::long_domain_name(&"abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz123456.tld.")]
    #[case::max_possible_domain_name(&max_domain_name())]
    fn apex_domain_validation_pass(#[case] domain_name: &str) {
        let apex_domain = ZoneApexDomain::new(String::from(domain_name));

        assert!(apex_domain.is_ok());
    }

    #[rstest]
    #[case::empty_domain(&"", ZoneApexDomainError::NonEmptyDomain)]
    #[case::empty_label(&".tld.", ZoneApexDomainError::NonEmptyLabel)]
    #[case::missing_end_with_dot(&"internetcomputer.tld", ZoneApexDomainError::MissingEndWithDot)]
    #[case::label_too_long(&"abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz123456789abc.tld.", ZoneApexDomainError::DomainLabelTooLong { label_length: 64, max_label_length: MAX_DOMAIN_LABEL_LENGTH })]
    #[case::invalid_hyphen_start(&"-test.tld.", ZoneApexDomainError::MisplacedHyphen)]
    #[case::invalid_hyphen_end(&"test-.tld.", ZoneApexDomainError::MisplacedHyphen)]
    #[case::invalid_name_start_with_underscore(&"_test.tld.", ZoneApexDomainError::InvalidDomainNameLabel { label: String::from("_test") })]
    // add test for valid domain name but with length > 255
    fn apex_domain_validation_fail(
        #[case] domain_name: &str,
        #[case] expected_err: ZoneApexDomainError,
    ) {
        let apex_domain = ZoneApexDomain::new(String::from(domain_name));

        assert!(apex_domain.is_err());
        assert_eq!(apex_domain.unwrap_err(), expected_err);
    }
}
