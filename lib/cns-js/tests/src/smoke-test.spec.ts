import { HttpAgent } from '@dfinity/agent';
import { describe, it, expect, inject } from 'vitest';
import { CnsClient } from '../../src';
import { exec } from './util';
import { Principal } from '@dfinity/principal';

describe('Smoke test', () => {
  const rawTld = '.icp.';
  const rawDomain = 'test.icp.';
  const domain = 'test.icp';

  const tldOperator = inject('TLD_OPERATOR');
  const cnsRoot = inject('CNS_ROOT');
  const dfxUrl = inject('DFX_URL');

  const domainCanister = Principal.fromText('r7inp-6aaaa-aaaaa-aaabq-cai');

  it('should lookup .test.icp NC and CID records', async () => {
    console.debug(addNcRecord(rawTld, tldOperator));
    console.debug(addCidRecord(rawDomain, domainCanister.toText()));

    const agent = HttpAgent.createSync({ host: dfxUrl });
    await agent.fetchRootKey();

    const cnsClient = new CnsClient({ agent, cnsRoot });

    const icpNamingCanister = await cnsClient.lookupNamingCanister(domain);
    expect(icpNamingCanister.toText()).toEqual(tldOperator);

    const testIcpDomainCanister = await cnsClient.lookupCanisterId(domain);
    expect(testIcpDomainCanister.toText()).toEqual(domainCanister.toText());
  });
});

function addNcRecord(tld: string, data: string): string {
  return exec(`
    dfx canister call cns_root register '(
      "${tld}",
      record {
        controllers = vec {};
        records = opt vec {
          record {
            ttl = 1_000 : nat;
            record_type = "NC";
            data = "${data}";
            name = "${tld}";
          };
        };
      },
    )'
  `);
}

function addCidRecord(domain: string, data: string): string {
  return exec(`
    dfx canister call tld_operator register '(
      "${domain}",
      record {
        controllers = vec {};
        records = opt vec {
          record {
            ttl = 1_000 : nat;
            record_type = "CID";
            data = "${data}";
            name = "${domain}";
          };
        };
      },
    )'
  `);
}
