//! Bytes as hex: the one way the app writes a key, a token, a checksum or a
//! folder's hashed name, two lowercase digits a byte.

/// `bytes` as lowercase hex, two digits a byte.
pub fn hex(bytes: &[u8]) -> String {
    const DIGITS: &[u8; 16] = b"0123456789abcdef";
    let mut text = String::with_capacity(bytes.len() * 2);
    for byte in bytes {
        text.push(char::from(DIGITS[usize::from(byte >> 4)]));
        text.push(char::from(DIGITS[usize::from(byte & 0x0f)]));
    }
    text
}

#[cfg(test)]
mod tests {
    #[test]
    fn hex_is_two_lowercase_digits_a_byte() {
        assert_eq!(super::hex(&[0x00, 0x0f, 0xa0, 0xff]), "000fa0ff");
        assert_eq!(super::hex(&[]), "");
    }
}
