/// Container for zone apex domain errors
#[derive(thiserror::Error, Debug, Eq, PartialEq, Clone)]
pub enum ZoneApexDomainError {
    /// The domain name is empty and cannot be used to create a zone apex domain
    #[error(r#"Domain name is empty"#)]
    NonEmptyDomain,

    /// The domain name cannot have empty labels
    #[error(r#"Domain has an empty label"#)]
    NonEmptyLabel,

    /// The domain name is too long and cannot be used to create a zone apex domain
    #[error("Apex domain is too long. Received {domain_name_length:?}, expected smaller or equal to {max_domain_name_length:?}")]
    DomainTooLong {
        /// The actual domain name size
        domain_name_length: usize,
        /// The max domain name size
        max_domain_name_length: usize,
    },

    /// The domain name label is too long and cannot be used in the zone apex domain
    #[error("Domain label is too long. Received {label_length:?}, expected smaller or equal to {max_label_length:?}")]
    DomainLabelTooLong {
        /// The actual label size
        label_length: usize,
        /// The max label size
        max_label_length: usize,
    },

    /// The domain name must end with a dot
    #[error(r#"Domain is missing a dot (.) in the end"#)]
    MissingEndWithDot,

    /// The domain name cannot start or end with a hyphen
    #[error(r#"Domain name labels cannot start or end with a hyphen (-)"#)]
    MisplacedHyphen,

    /// Domain name labels can only contain alphanumeric characters and hyphens (-)
    #[error("Domain name labels can only contain alphanumeric characters and hyphens (-). Received {label:?}")]
    InvalidDomainNameLabel {
        /// The invalid domain name label
        label: String,
    },
}
