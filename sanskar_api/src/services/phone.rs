/// Normalize to E.164: leading + and 7–15 digits after +.
pub fn normalize_e164_phone(input: &str) -> Option<String> {
    let mut t: String = input.chars().filter(|c| !c.is_whitespace()).collect();
    t = t.replace(['-', '(', ')'], "");
    if !t.starts_with('+') {
        return None;
    }
    let digits = &t[1..];
    if digits.len() < 7 || digits.len() > 15 {
        return None;
    }
    if !digits.chars().all(|c| c.is_ascii_digit()) {
        return None;
    }
    Some(t)
}
