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
    const normalizedDomain = normalizeDomain(domain);
    const existingCanisterId = this.#canisterIds.get(normalizedDomain);
    if (isNotNil(existingCanisterId)) {
      return existingCanisterId;
    }

    const namingCanister = await this.lookupNamingCanister(domain);
    const namingClient = this.getOperatorClient(namingCanister);
    const res = await namingClient.lookupDomain({
      domain: normalizedDomain,
      recordType: RecordType.CID,
    });

    const canisterId = getPrincipalAnswer(
      normalizedDomain,
      res,
      RecordType.CID,
    );
    this.#canisterIds.set(normalizedDomain, canisterId);
    return canisterId;
  }

  public async lookupNamingCanister(domain: string): Promise<Principal> {
    const normalizedTld = normalizeTld(domain);
    const existingNamingCanister = this.#namingCanisters.get(normalizedTld);
    if (isNotNil(existingNamingCanister)) {
      return existingNamingCanister;
    }

    const rootClient = this.getOperatorClient(this.#cnsRoot);
    const res = await rootClient.lookupDomain({
      domain: normalizedTld,
      recordType: RecordType.NC,
    });

    const namingCanister = getPrincipalAnswer(
      normalizedTld,
      res,
      RecordType.NC,
    );
    this.#namingCanisters.set(normalizedTld, namingCanister);
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

function normalizeDomain(domain: string): string {
  const [parts, tld] = getDomainParts(domain);

  if (parts.length === 0) {
    throw new Error(`Invalid domain ${domain}`);
  }

  return `${parts.join('.')}.${tld}.`;
}

function normalizeTld(domain: string): string {
  const [_parts, tld] = getDomainParts(domain);

  return `.${tld}.`;
}

function getDomainParts(domain: string): [string[], string] {
  const parts = domain
    .toLowerCase()
    .split('.')
    .filter(part => part.length > 0);
  const tld = parts.pop();

  if (isNil(tld)) {
    throw new Error(`Invalid TLD ${domain}`);
  }

  return [parts, tld];
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
