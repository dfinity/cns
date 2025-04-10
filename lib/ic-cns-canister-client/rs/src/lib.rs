use candid::{CandidType, Deserialize, Principal};
pub use cns_domain_registry::types::RegisterResult;
use ic_cdk::api::call::{call, RejectionCode};
use lazy_static::lazy_static;
use std::sync::{Arc, Mutex};

type CanisterId = Principal;

const CNS_ROOT_MAINNET: &str = "rdmx6-jaaaa-aaaaa-aaadq-cai";

lazy_static! {
    pub static ref CNS_ROOT_CID: Arc<Mutex<Principal>> = Arc::new(Mutex::new(
        Principal::from_text(CNS_ROOT_MAINNET).unwrap_or_else(|_| panic!(
            "Failed parsing CNS root canister id: {}",
            CNS_ROOT_MAINNET
        ))
    ));
}

#[derive(CandidType, Deserialize, Clone, Debug, Eq, PartialEq)]
pub enum CnsError {
    NotFound(String),
    CallFailed((RejectionCode, String)),
    MalformedData(String),
    Internal(String),
}

impl std::fmt::Display for CnsError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(&format!("{:?}", self))
    }
}

impl From<(RejectionCode, String)> for CnsError {
    fn from((code, err_msg): (RejectionCode, String)) -> Self {
        CnsError::CallFailed((code, err_msg))
    }
}

// TODO: use DomainRecord and DomainLookup defined in cns_domain_registry.
#[derive(CandidType, Deserialize, Clone, Debug)]
pub struct DomainRecord {
    pub name: String,
    pub record_type: String,
    pub ttl: u32,
    pub data: String,
}

#[derive(CandidType, Deserialize, Clone, Debug)]
struct DomainLookup {
    pub answers: Vec<DomainRecord>,
    pub additionals: Vec<DomainRecord>,
    pub authorities: Vec<DomainRecord>,
}

#[derive(CandidType, Deserialize, Clone, Debug)]
pub enum RegistrationControllerRole {
    Registrar,
    Registrant,
    Technical,
    Administrative,
}

#[derive(CandidType, Deserialize, Clone, Debug)]
pub struct RegistrationController {
    pub principal: Principal,
    pub roles: Vec<RegistrationControllerRole>,
}

#[derive(CandidType, Deserialize, Clone, Debug)]
pub struct RegistrationRecords {
    pub controller: Vec<RegistrationController>,
    pub records: Option<Vec<DomainRecord>>,
}

fn get_cid_from_records(records: &[DomainRecord], context: &str) -> Result<CanisterId, CnsError> {
    if !records.is_empty() {
        if let Ok(id) = Principal::from_text(&records[0].data) {
            return Ok(id);
        } else {
            return Err(CnsError::MalformedData(format!(
                "Malformed principal id `{}` for {}",
                records[0].data, context
            )));
        }
    }
    Err(CnsError::NotFound(format!("No record for {}", context)))
}

async fn lookup_nc(domain: &str) -> Result<CanisterId, CnsError> {
    let cns_root = *CNS_ROOT_CID
        .lock()
        .map_err(|e| CnsError::Internal(format!("Failed getting CNS root cid: {}", e)))?;
    let (lookup,): (DomainLookup,) =
        call(cns_root, "lookup", (domain.to_string(), "NC".to_string())).await?;
    get_cid_from_records(&lookup.answers, &format!("NC lookup for {}", domain))
}

pub async fn lookup_domain(domain: &str) -> Result<CanisterId, CnsError> {
    let nc_cid = lookup_nc(domain).await?;
    let (lookup,): (DomainLookup,) =
        call(nc_cid, "lookup", (domain.to_string(), "CID".to_string())).await?;
    get_cid_from_records(&lookup.answers, &format!("CID lookup for {}", domain))
}

pub async fn register_domain(domain: &str, cid: CanisterId) -> Result<(), CnsError> {
    let nc_cid = lookup_nc(domain).await?;
    let record = DomainRecord {
        name: domain.to_string(),
        record_type: "CID".to_string(),
        ttl: 3600,
        data: cid.to_string(),
    };
    let registration_records = RegistrationRecords {
        controller: vec![],
        records: Some(vec![record]),
    };
    let (register,): (RegisterResult,) = call(
        nc_cid,
        "register",
        (domain.to_string(), registration_records),
    )
    .await?;
    if register.success {
        return Ok(());
    }
    Err(CnsError::CallFailed((
        RejectionCode::NoError,
        format!(
            "Registration of domain {} failed with error {}",
            domain,
            register.message.unwrap_or("".to_string())
        )
        .to_string(),
    )))
}

pub fn override_cns_root_for_testing(cns_root_for_testing: Principal) {
    *(CNS_ROOT_CID.lock().expect("Failed overriding CNS root CID")) = cns_root_for_testing;
}
