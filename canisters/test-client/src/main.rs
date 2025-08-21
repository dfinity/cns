//! # A CNS client for testing
//!
//! A CNS client for testing various functionalities of a CNS.

use candid::{CandidType, Deserialize, Principal};
use ic_cdk::{init, update};
use ic_cns_canister_client::CnsError;

#[derive(CandidType, Deserialize)]
pub struct ClientInit {
    pub cns_root_cid: String,
}

#[init]
fn init(init_arg: Option<ClientInit>) {
    if let Some(init) = init_arg {
        ic_cns_canister_client::override_cns_root_for_testing(
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
    ic_cns_canister_client::register_domain(&domain, cid).await
}

#[update]
async fn lookup_domain(domain: String) -> Result<Principal, CnsError> {
    ic_cns_canister_client::lookup_domain(&domain).await
}

#[update]
async fn lookup_subnet(subnet_name: String) -> Result<Principal, CnsError> {
    ic_cns_canister_client::lookup_subnet(&subnet_name).await
}

#[update]
async fn domain_for_canister(cid_text: String) -> Result<String, CnsError> {
    let cid = Principal::from_text(&cid_text)
        .map_err(|e| format!("Failed parsing principal {}: {}", cid_text, e))
        .unwrap();
    ic_cns_canister_client::domain_for_canister(cid).await
}

#[update]
async fn name_for_subnet(sid_text: String) -> Result<String, CnsError> {
    let sid = Principal::from_text(&sid_text)
        .map_err(|e| format!("Failed parsing principal {}: {}", sid_text, e))
        .unwrap();
    ic_cns_canister_client::name_for_subnet(sid).await
}

fn main() {}
