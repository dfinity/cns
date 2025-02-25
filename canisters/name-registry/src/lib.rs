//! # Name registry canister
//!
//! Domain names leverage the Chain Name System (CNS) specification on the
//! Internet Computer(https://internetcomputer.org) to enable the resolution of readable names to complex resources.
//!
//! The name registry canister is responsible for managing domain zones and their name records while enabling
//! the resolution through standard protocols.

pub mod builders;
pub mod common;
pub mod errors;
pub mod repositories;
pub mod types;
pub mod utils;
