import type { TestProject } from 'vitest/node';
import { exec } from './src/util';

export async function setup(ctx: TestProject): Promise<void> {
  const port = exec('dfx info webserver-port');
  const url = `http://localhost:${port}`;

  const cnsRoot = exec('dfx canister id cns_root');
  const tldOperator = exec('dfx canister id tld_operator');

  ctx.provide('DFX_URL', url);
  ctx.provide('CNS_ROOT', cnsRoot);
  ctx.provide('TLD_OPERATOR', tldOperator);
}
