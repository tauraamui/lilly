//! Crate-level doc comment.
//! Rust syntax stress file: lexing only, not meant to compile.
#![allow(dead_code, unused_variables)]

use std::collections::{HashMap, BTreeMap};
use std::fmt::{self, Display};

/* Block comments nest in Rust:
   /* level two
      /* level three */
      back in level two
   */
   back in level one, closes next line */
const LIMIT: u64 = 0xFFFF_FFFFu64;
static RATIO: f64 = 1_000.5e-3_f64;
const BITS: u8 = 0b1010_0101;
const PERMS: u32 = 0o755;

/// Doc comment on a struct, with `code` and [links].
#[derive(Debug, Clone, PartialEq)]
pub struct Parser<'a, T: Display + 'a> {
    input: &'a str,
    items: Vec<T>,
    cache: HashMap<&'a str, Box<dyn Fn(&str) -> Option<T> + 'a>>,
}

impl<'a, T> Parser<'a, T>
where
    T: Display + Clone + 'a,
{
    pub fn new(input: &'a str) -> Self {
        Self { input, items: Vec::new(), cache: HashMap::new() }
    }

    fn strings(&self) -> String {
        let plain = "escapes: \n \t \" \\ \u{1F600}";
        let multi = "this string
spans several lines
    and keeps going \" with an escaped quote
until here";
        let raw = r"C:\no\escapes\here";
        let raw1 = r#"contains "quotes" freely"#;
        let raw2 = r##"contains "# without ending"##;
        let byte_str = b"bytes\x00";
        let raw_bytes = br#"raw "bytes""#;
        let ch = 'x';
        let esc = '\'';
        let uni = '\u{2764}';
        let byte = b'a';
        format!("{plain}{multi}{raw}{raw1}{raw2}{:?}{:?}{ch}{esc}{uni}{byte}", byte_str, raw_bytes)
    }
}

// lifetimes and labels share the leading quote with char literals
fn longest<'long, 'short: 'long>(a: &'long str, b: &'short str) -> &'long str {
    'outer: for i in 0..10 {
        'inner: loop {
            if i % 2 == 0 {
                continue 'outer;
            }
            break 'inner;
        }
    }
    if a.len() > b.len() { a } else { b }
}

pub trait Shape: fmt::Debug {
    type Output;
    const SIDES: usize;
    fn area(&self) -> f64;
    fn describe(&self) -> String where Self: Sized {
        format!("{:?} with {} sides", self, Self::SIDES)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn turbofish_and_macros() {
        let parsed = "42".parse::<i32>().unwrap();
        let collected = (0..5).map(|x| x * 2).collect::<Vec<_>>();
        let m: BTreeMap<String, Vec<u8>> = BTreeMap::new();
        assert_eq!(parsed, 42);
        vec![1, 2, 3].iter().for_each(|n| println!("{n}"));
        let s = std::mem::size_of::<usize>();
        matches!(collected.first(), Some(&0));
        todo! {};
    }
}

async fn async_stuff() -> Result<(), Box<dyn std::error::Error>> {
    let fut = async move { 1u8 };
    let value = fut.await;
    let closure = |a: i128, b: isize| -> u128 { (a as u128) + (b as u128) };
    unsafe {
        let ptr = &value as *const u8;
        let _ = *ptr;
    }
    match value {
        0 => {}
        1..=9 => println!("small"),
        n @ 10.. if n % 2 == 0 => println!("even {}", n),
        _ => unreachable!(),
    }
    Ok(())
}

// KNOWN GAP: a multi-line attribute only highlights its first line
#[cfg_attr(
    feature = "serde",
    derive(serde::Serialize)
)]
struct Gap;

// KNOWN GAP: r###"..."### (three hashes) has no context of its own
const THREE: &str = r###"has "## inside"###;
fn after_gap() -> bool { true }
