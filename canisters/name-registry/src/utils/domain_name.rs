use crate::common::{MAX_DOMAIN_LABEL, MAX_DOMAIN_NAME};

/// The maximum domain name as a string.
pub fn max_domain_name() -> String {
    String::from_utf8(MAX_DOMAIN_NAME.to_vec()).unwrap()
}

/// The maximum domain label as a string.
pub fn max_domain_label() -> String {
    String::from_utf8(MAX_DOMAIN_LABEL.to_vec()).unwrap()
}

/// Returns a string with the given character repeated the given times.
pub fn repeat_char(c: char, times: usize) -> String {
    std::iter::repeat(c).take(times).collect::<String>()
}
