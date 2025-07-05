use candid::{encode_args, encode_one, Decode, Principal, Nat};
use ic_cns_canister_client::{CnsError, DomainLookup, DomainRecord, RegistrationRecords};
pub use cns_domain_registry::types::RegisterResult;
use pocket_ic::{PocketIc, PocketIcBuilder, WasmResult};
use std::fs;

const INIT_CYCLES: u128 = 2_000_000_000_000; // 2T cycles
const CNS_ROOT_WASM: &str = "../../../.dfx/local/canisters/cns_root/cns_root.wasm";
const TLD_OPERATOR_WASM: &str = "../../../.dfx/local/canisters/tld_operator/tld_operator.wasm";
const TEST_CLIENT_WASM: &str = "../../../.dfx/local/canisters/test_client/test_client.wasm";
use assert_matches::assert_matches;
use candid::{CandidType, Deserialize};

#[derive(CandidType, Deserialize)]
pub struct ClientInit {
    pub cns_root_cid: String,
}

struct CnsFixture {
    pic: PocketIc,
    cns_root: Principal,
    tld_operator: Principal,
    test_client: Principal,
}

impl CnsFixture {
    fn init() -> CnsFixture {
        let pic = PocketIcBuilder::new()
            .with_application_subnet()
            .with_log_level(slog::Level::Debug)
            .build();
        let cns_root = pic.create_canister();
        let tld_operator = pic.create_canister();
        let test_client = pic.create_canister();
        pic.add_cycles(cns_root, INIT_CYCLES);
        pic.add_cycles(tld_operator, INIT_CYCLES);
        pic.add_cycles(test_client, INIT_CYCLES);
        println!("  cns_root CID: {}", cns_root);
        println!("  tld_operator CID: {}", tld_operator);
        println!("  test_client CID: {}", test_client);

        let cns_root_wasm = fs::read(CNS_ROOT_WASM).unwrap_or_else(|_| {
            panic!(
                "Wasm file not found at {}, current dir: {}, run 'dfx build'.",
                CNS_ROOT_WASM,
                std::env::current_dir().unwrap().display()
            )
        });
        let tld_operator_wasm =
            fs::read(TLD_OPERATOR_WASM).expect("Wasm file not found, run 'dfx build'.");
        let test_client_wasm =
            fs::read(TEST_CLIENT_WASM).expect("Wasm file not found, run 'dfx build'.");
        pic.install_canister(cns_root, cns_root_wasm, vec![], None);
        pic.install_canister(tld_operator, tld_operator_wasm, vec![], None);
        pic.install_canister(
            test_client,
            test_client_wasm,
            encode_one(Some(ClientInit {
                cns_root_cid: cns_root.to_string(),
            }))
            .unwrap(),
            None,
        );
        // Set controller, so that test_client can register domains.
        pic.set_controllers(tld_operator, None, vec![test_client])
            .expect("Failed setting TLD operator controller");
        CnsFixture {
            pic,
            cns_root,
            tld_operator,
            test_client,
        }
    }

    fn register_icp_nc(&self) {
        let registration_records = RegistrationRecords {
            controllers: vec![],
            records: Some(vec![DomainRecord {
                name: ".icp.".to_string(),
                record_type: "NC".to_string(),
                ttl: Nat::from(3600u32),
                data: self.tld_operator.to_string(),
            }]),
        };
        self.pic
            .update_call(
                self.cns_root,
                Principal::anonymous(),
                "register",
                encode_args((&".icp.", &registration_records)).expect("failed encoding args"),
            )
            .expect("Failed registering NC for icp");
    }

    fn register_domain(&self, domain: &str, cid_text: &str) -> Result<(), CnsError> {
        let response = self.pic.update_call(
            self.test_client,
            Principal::anonymous(),
            "register_domain",
            encode_args((&domain, &cid_text)).expect("failed encoding args"),
        );
        let Ok(WasmResult::Reply(reply)) = response else {
            panic!("call failed: {:?}", response);
        };
        Decode!(&reply, Result<(), CnsError>).expect("reply decoding failed")
    }

    fn lookup_domain(&self, domain: &str) -> Result<Principal, CnsError> {
        let response = self.pic.update_call(
            self.test_client,
            Principal::anonymous(),
            "lookup_domain",
            encode_one(domain).expect("failed encoding arg"),
        );
        let Ok(WasmResult::Reply(reply)) = response else {
            panic!("call failed: {:?}", response);
        };
        Decode!(&reply, Result<Principal, CnsError>).expect("reply decoding failed")
    }
}

#[test]
fn should_register_and_lookup() {
    let env = CnsFixture::init();
    env.register_icp_nc();
    for (domain, cid_text) in [
        ("example.icp.", "aaaaa-aa"),
        ("nns_governance.icp.", "rrkah-fqaaa-aaaaa-aaaaq-cai"),
        ("nns_registry.icp.", "rwlgt-iiaaa-aaaaa-aaaaa-cai"),
    ] {
        let result = env.register_domain(domain, cid_text);
        assert!(result.is_ok(), "Domain registration failed: {:?}", result);
        let result = env.lookup_domain(domain);
        assert_matches!(result, Ok(cid) if (cid.to_string() == cid_text));
    }
}

#[test]
fn should_not_register_and_lookup_if_missing_nc() {
    let env = CnsFixture::init();
    for (domain, cid_text) in [
        ("example.com.", "aaaaa-aa"),
        ("nns_governance.icp.", "rrkah-fqaaa-aaaaa-aaaaq-cai"),
        ("nns_registry.icp.", "rwlgt-iiaaa-aaaaa-aaaaa-cai"),
    ] {
        let result = env.register_domain(domain, cid_text);
        assert_matches!(result, Err(err) if (err.to_string().contains("No record for NC")));
        let result = env.lookup_domain(domain);
        assert_matches!(result, Err(err) if (err.to_string().contains("No record for NC")));
    }
}

#[test]
fn should_not_register_and_lookup_if_not_icp_tld() {
    let env = CnsFixture::init();
    for (domain, cid_text) in [
        ("example.com.", "aaaaa-aa"),
        ("nns_governance.org.", "rrkah-fqaaa-aaaaa-aaaaq-cai"),
        ("nns_registry.edu.", "rwlgt-iiaaa-aaaaa-aaaaa-cai"),
    ] {
        let result = env.register_domain(domain, cid_text);
        assert_matches!(result, Err(err) if (err.to_string().contains("No record for NC")));
        let result = env.lookup_domain(domain);
        assert_matches!(result, Err(err) if (err.to_string().contains("No record for NC")));
    }
}
