//! # A CNS client for testing
//!
//! A CNS client for testing various functionalities of a CNS.

use candid::{CandidType, Deserialize, Principal};
use cns_client::CnsError;
use ic_cdk::{init, query, update};

#[derive(CandidType, Deserialize)]
pub struct ClientInit {
    pub cns_root_cid: String,
}

#[init]
fn init(init_arg: Option<ClientInit>) {
    if let Some(init) = init_arg {
        cns_client::override_cns_root_for_testing(
            Principal::from_text(&init.cns_root_cid).unwrap_or_else(|_| {
                panic!("Failed parsing init CNS root CID: {}", init.cns_root_cid)
            }),
        );
    };
}

#[update]
async fn register_domain(domain: String, cid_text: String) -> Result<(), CnsError> {
    let cid = Principal::from_text(&cid_text)
        .map_err(|e| format!("Failed parsing principal {}: {}", cid_text, e))
        .unwrap();
    cns_client::register_domain(&domain, cid).await
}

#[query(composite = true)]
async fn lookup_domain(domain: String) -> Result<Principal, CnsError> {
    cns_client::lookup_domain(&domain).await
}

fn main() {}
