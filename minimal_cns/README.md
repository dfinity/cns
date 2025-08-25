# A Minimal CNS (WIP)

This folder contains an experimental implementation of a "minimal" MVP CNS.
While it uses [the full CNS API](../canisters/name-registry/spec.did), it implements
only a small part of the API, necessary to support basic CNS use cases.
Currently, the following components are being worked on:

- A minimal [CNS root canister](./src/backend/cns_root.mo) that supports only the following:

  - `register`-operation available only for canister controller, allowing registration of a TLD operator
    for a single TLD (`.icp`).
  - `lookup`-operation, available publicly, returning an NC-entry for `.icp`-domains,
    provided previously via `register`-operation.

  All other operations fail or return unsupported/error. Having such a CNS root
  initially is to ensure that the client libraries’ flows are correct from the very beginning,
  i.e. they won’t change once we add other TLDs.

- A minimal [TLD operator canister](./src/backend/tld_operator.mo) that supports only the following:
  - `register`-operation available publicly, but with restricted rights:
    - canister controller can register CID- (canister id) or SID- (subnet id) records
      for any subdomain of `.icp`-domain.
    - a caller that is not a canister controller can register any subdomain of `.test.icp`-domain,
      e.g. `example.test.icp`. (first-come-first-serve basis, no ownership checks, but also no
      stability guarantees, i.e. test domains can be removed at any moment)
  - `lookup`-operation, available publicly, returning CID- or SID- records for `.icp`-domains,
    provided previously via `register`-operation.
  - `lookup`-operation for reverse lookup by principal (canister id or subnet id), returning `PTR`-like
    records if a **non-test domain** has been assigned to the principal previously
    (cf. [here](https://en.wikipedia.org/wiki/List_of_DNS_record_types#PTR)).  
    To make a reverse lookup for a principal, encode the principal in a special domain
    `<text representation of principal>.reverse.icp.` and request `PTR`-record.
    If present, the domain is returned in `data`-field of a response record.

**NOTE**: to comply with the spec, the domains used in the requests should have a trailing dot,
i.e. they should have form like e.g. `some.domain.icp.` or `domain.test.icp.`

## Test deploment on the IC

We have deployed the minimal CNS on the IC, with the following canisters:

- cns_root: [rupqg-4qaaa-aaaad-qhosa-cai](https://a4gq6-oaaaa-aaaab-qaa4q-cai.raw.icp0.io/?id=rupqg-4qaaa-aaaad-qhosa-cai)
- tld_operator for `.icp.`-domain: [rtows-riaaa-aaaad-qhosq-cai](https://a4gq6-oaaaa-aaaab-qaa4q-cai.raw.icp0.io/?id=rtows-riaaa-aaaad-qhosq-cai)

See also [known_canisters.csv](./init/known_canisters.csv) and [known_subnets.csv](./init/known_subnets.csv)
for data that was used to pre-populate the deployment.

In addition to these canisters, the [lib](../lib/)-folder contains client libraries (currently Rust and Javascript)
that can be used to interact with the test CNS deployment

## Test instuctions

For local testing consult the processes defined in [tests.yaml](../.github/workflows/tests.yaml).
