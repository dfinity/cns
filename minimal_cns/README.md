# A Minimal CNS (WIP)

This folder contains an experimental implementation of a "minimal" MVP CNS.
While it uses [the full CNS API](../canisters/name-registry/spec.did), it implements 
only a small part of the API, necessary to support basic CNS use cases. 
Currently, the following components are being worked on: 
- A minimal [CNS root canister](./src/backend/cns_root.mo), that supports only the `lookup`-operation 
  for a single TLD (`.icp`), returning an NC-entry for that TLD, and otherwise returns unsupported/error 
  (in particular, it does not support registration of new TLD operators yet). Having such a CNS root 
  initially is to ensure that the client libraries’ flows are correct from the very beginning, 
  i.e. they won’t change once we add other TLDs.


  ## Test instuctions

  ```
  dfx start --clean --background

  dfx canister create name_registry
  dfx canister create cns_root
  dfx canister create cns_root_test
  
  dfx deploy cns_root
  dfx deploy cns_root_test
  dfx canister call cns_root_test runTests "()"
  ```
