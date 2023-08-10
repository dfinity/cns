/// Container for record name errors
#[derive(thiserror::Error, Debug, Eq, PartialEq, Clone)]
pub enum RecordNameError {
    /// The record name is empty and cannot be used to create a record
    #[error(r#"Record name is empty"#)]
    NonEmptyName,

    /// The record name cannot have empty labels
    #[error(r#"Record name has an empty label"#)]
    NonEmptyLabel,

    /// The record name can't end with a dot
    #[error(r#"Record name can't end with a dot (.)"#)]
    InvalidEndWithDot,

    /// The domain name is too long and cannot be used to create a zone apex domain
    #[error("Record name is too long. Received {name_length:?}, expected smaller or equal to {max_name_length:?}")]
    NameTooLong {
        /// The actual name length
        name_length: usize,
        /// The max name size
        max_name_length: usize,
    },

    /// The domain name label is too long and cannot be used in the zone apex domain
    #[error("Name label is too long. Received {label_length:?}, expected smaller or equal to {max_label_length:?}")]
    LabelTooLong {
        /// The actual label size
        label_length: usize,
        /// The max label size
        max_label_length: usize,
    },

    /// The record name cannot start or end with a hyphen
    #[error(r#"Record name labels cannot start or end with a hyphen (-)"#)]
    MisplacedHyphen,

    /// The record name cannot start or end with a hyphen
    #[error(r#"A domain name can only have underscore (_) in the beginning"#)]
    MisplacedUnderscore,

    /// Name labels can only contain alphanumeric characters and hyphens (-)
    #[error(
        "Name labels can only contain alphanumeric characters and hyphens (-). Received {label:?}"
    )]
    InvalidNameLabel {
        /// The invalid record name label
        label: String,
    },
}
