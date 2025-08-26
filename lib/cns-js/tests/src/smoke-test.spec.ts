import { HttpAgent } from '@icp-sdk/core/agent';
import { Principal } from '@icp-sdk/core/principal';
import { describe, it, expect, inject, beforeAll } from 'vitest';
import { CnsClient } from '../../src';
import { exec } from './util';

describe('Smoke test', () => {
  const rawTld = '.icp.';

  const rawCanisterDomain = 'test.icp.';
  const canisterDomain = 'test.icp';

  const rawSubnetDomain = 'app-fid-1.subnet.icp.';
  const subnetDomain = 'app-fid-1.subnet.icp';

  const tldOperator = inject('TLD_OPERATOR');
  const cnsRoot = inject('CNS_ROOT');
  const dfxUrl = inject('DFX_URL');

  const canisterId = Principal.fromText('r7inp-6aaaa-aaaaa-aaabq-cai');
  const subnetId = Principal.fromText(
    'pzp6e-ekpqk-3c5x7-2h6so-njoeq-mt45d-h3h6c-q3mxf-vpeq5-fk5o7-yae',
  );

  let client: CnsClient;

  beforeAll(() => {
    console.debug(addNcRecord(rawTld, tldOperator));
    console.debug(addCidRecord(rawCanisterDomain, canisterId.toText()));
    console.debug(addSidRecord(rawSubnetDomain, subnetId.toString()));

    const agent = HttpAgent.createSync({
      host: dfxUrl,
      shouldFetchRootKey: true,
    });
    client = new CnsClient({ agent, cnsRoot });
  });

  it('should lookup NC records', async () => {
    const result = await client.lookupNamingCanister(canisterDomain);

    expect(result.toText()).toEqual(tldOperator);
  });

  it('should lookup CID records', async () => {
    const result = await client.lookupCanisterId(canisterDomain);

    expect(result.toText()).toEqual(canisterId.toText());
  });

  it('should lookup SID records', async () => {
    const result = await client.lookupSubnetId(subnetDomain);

    expect(result.toText()).toEqual(subnetId.toText());
  });

  it('should lookup canister PTR records', async () => {
    const result = await client.reverseLookup(rawTld, canisterId.toText());

    expect(result.length).toEqual(1);
    expect(result[0]).toEqual({
      data: rawCanisterDomain,
      name: `${canisterId.toText()}.reverse${rawTld}`,
      recordType: 'PTR',
      ttl: 1000n,
    });
  });

  it('should lookup subnet PTR records', async () => {
    const result = await client.reverseLookup(rawTld, subnetId.toText());

    expect(result.length).toEqual(1);
    expect(result[0]).toEqual({
      data: rawSubnetDomain,
      name: `${subnetId.toText()}.reverse${rawTld}`,
      recordType: 'PTR',
      ttl: 1000n,
    });
  });
});

function addNcRecord(tld: string, data: string): string {
  return addRecord(tld, data, 'cns_root', 'NC');
}

function addCidRecord(domain: string, data: string): string {
  return addRecord(domain, data, 'tld_operator', 'CID');
}

function addSidRecord(domain: string, data: string): string {
  return addRecord(domain, data, 'tld_operator', 'SID');
}

function addRecord(
  name: string,
  data: string,
  canisterName: string,
  recordType: string,
): string {
  return exec(`
    dfx canister call ${canisterName} register '(
      "${name}",
      record {
        controllers = vec {};
        records = opt vec {
          record {
            ttl = 1_000 : nat;
            record_type = "${recordType}";
            data = "${data}";
            name = "${name}";
          };
        };
      },
    )'
  `);
}
