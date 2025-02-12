import { HttpAgent } from '@dfinity/agent';
import { Principal } from '@dfinity/principal';

import { CnsRootClient, DomainRecord, LookupDomainResponse } from './cns-root';
import { isNil, isNotNil } from './utils';

export interface CnsClientArgs {
  agent?: HttpAgent | null;
  cnsRoot?: string | Principal | null;
}

const DEFAULT_API_GATEWAY = 'https://icp-api.io';
const DEFAULT_CNS_ROOT = 'rdmx6-jaaaa-aaaaa-aaadq-cai';

enum RecordType {
  CID = 'CID',
  NC = 'NC',
}

export class CnsClient {
  readonly #agent: HttpAgent;
  readonly #cnsRoot: Principal;

  readonly #operatorClients: Map<Principal, CnsRootClient> = new Map();
  readonly #namingCanisters: Map<string, Principal> = new Map();
  readonly #canisterIds: Map<string, Principal> = new Map();

  constructor({ agent, cnsRoot }: CnsClientArgs = {}) {
    this.#agent = agent ?? HttpAgent.createSync({ host: DEFAULT_API_GATEWAY });

    this.#cnsRoot = cnsRoot
      ? Principal.from(cnsRoot)
      : Principal.fromText(DEFAULT_CNS_ROOT);
  }

  public async lookupCanisterId(domain: string): Promise<Principal> {
    const existingCanisterId = this.#canisterIds.get(domain);
    if (isNotNil(existingCanisterId)) {
      return existingCanisterId;
    }

    const namingCanister = await this.lookupNamingCanister(domain);
    const namingClient = this.getOperatorClient(namingCanister);
    const res = await namingClient.lookupDomain({
      domain,
      recordType: RecordType.CID,
    });

    const canisterId = getPrincipalAnswer(domain, res, RecordType.CID);
    this.#canisterIds.set(domain, canisterId);
    return canisterId;
  }

  public async lookupNamingCanister(domain: string): Promise<Principal> {
    const existingNamingCanister = this.#namingCanisters.get(domain);
    if (isNotNil(existingNamingCanister)) {
      return existingNamingCanister;
    }

    const rootClient = this.getOperatorClient(this.#cnsRoot);
    const res = await rootClient.lookupDomain({
      domain,
      recordType: RecordType.NC,
    });

    const namingCanister = getPrincipalAnswer(domain, res, RecordType.NC);
    this.#namingCanisters.set(domain, namingCanister);
    return namingCanister;
  }

  private getOperatorClient(canisterId: Principal): CnsRootClient {
    const existingClient = this.#operatorClients.get(canisterId);
    if (isNotNil(existingClient)) {
      return existingClient;
    }

    const operatorClient = new CnsRootClient({
      agent: this.#agent,
      canisterId,
    });
    this.#operatorClients.set(canisterId, operatorClient);

    return operatorClient;
  }
}

function getPrincipalAnswer(
  domain: string,
  res: LookupDomainResponse,
  recordType: RecordType,
): Principal {
  const answer = getAnswer(domain, res, recordType);
  return Principal.fromText(answer.data);
}

function getAnswer(
  domain: string,
  res: LookupDomainResponse,
  recordType: RecordType,
): DomainRecord {
  const answer = res.answers.find(answer => answer.recordType === recordType);
  if (isNil(answer)) {
    throw new Error(`No ${recordType} record found for domain ${domain}`);
  }

  return answer;
}
