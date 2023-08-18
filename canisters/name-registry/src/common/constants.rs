/// The maximum length of a domain name.
pub const MAX_DOMAIN_NAME_LENGTH: usize = 255;

/// The maximum length of a label in a domain name.
pub const MAX_DOMAIN_LABEL_LENGTH: usize = 63;

/// The maximum value of an ASCII character accepted in a domain name, which is 122.
pub const MAX_DOMAIN_ASCII_CHAR_VALUE: u8 = b'z';

/// The maximum value of a domain name label.
pub const MAX_DOMAIN_LABEL: [u8; MAX_DOMAIN_LABEL_LENGTH] = [b'z'; MAX_DOMAIN_LABEL_LENGTH];

/// The maximum domain name.
pub const MAX_DOMAIN_NAME: [u8; MAX_DOMAIN_NAME_LENGTH] = {
    let mut max_domain_name: [u8; 255] = [b'z'; MAX_DOMAIN_NAME_LENGTH];
    let mut index = MAX_DOMAIN_LABEL_LENGTH - 1;

    // The last character of a domain name is always a dot.
    max_domain_name[MAX_DOMAIN_NAME_LENGTH - 1] = b'.';

    while index < MAX_DOMAIN_NAME_LENGTH {
        max_domain_name[index] = b'.';
        index += MAX_DOMAIN_LABEL_LENGTH + 1;
    }

    max_domain_name
};
