use std::fmt::Display;

/// Represents the existing record types that can be used in a domain record.
pub enum DomainRecordTypes {
    A,
    AAAA,
    CID,
    CNAME,
    MX,
    NC,
    NS,
    TXT,
}

/// Adds the equivalent string representation for each DomainRecordType.
impl Display for DomainRecordTypes {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            DomainRecordTypes::A => write!(f, "A"),
            DomainRecordTypes::AAAA => write!(f, "AAAA"),
            DomainRecordTypes::CID => write!(f, "CID"),
            DomainRecordTypes::CNAME => write!(f, "CNAME"),
            DomainRecordTypes::MX => write!(f, "MX"),
            DomainRecordTypes::NC => write!(f, "NC"),
            DomainRecordTypes::NS => write!(f, "NS"),
            DomainRecordTypes::TXT => write!(f, "TXT"),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn record_types_match_string_representation() {
        assert_eq!(DomainRecordTypes::A.to_string(), "A");
        assert_eq!(DomainRecordTypes::AAAA.to_string(), "AAAA");
        assert_eq!(DomainRecordTypes::CID.to_string(), "CID");
        assert_eq!(DomainRecordTypes::CNAME.to_string(), "CNAME");
        assert_eq!(DomainRecordTypes::MX.to_string(), "MX");
        assert_eq!(DomainRecordTypes::NC.to_string(), "NC");
        assert_eq!(DomainRecordTypes::NS.to_string(), "NS");
        assert_eq!(DomainRecordTypes::TXT.to_string(), "TXT");
    }
}
