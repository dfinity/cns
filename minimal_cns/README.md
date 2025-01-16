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
  - `register`-operation available only for canister controller, allowing registration of CID-records
    for `.icp`-domains.
  - `lookup`-operation, available publicly, returning an CID-entry for `.icp`-domains,
    provided previously via `register`-operation.

## Test instuctions

For local testing consult the processes defined in [tests.yaml](../.github/workflows/tests.yaml).
