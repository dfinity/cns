import { HttpAgent } from '@icp-sdk/core/agent';
import { Principal } from '@icp-sdk/core/principal';

import { CnsRootClient, DomainRecord, LookupResponse } from './cns-root';
import { isNil, isNotNil } from './utils';

/**
 * Arguments for creating a CNS client.
 */
export interface CnsClientArgs {
  /**
   * The HTTP agent to use for making requests.
   * Defaults to an internally created agent.
   */
  agent?: HttpAgent | null;

  /**
   * The CNS root canister ID to use.
   * Defaults to the mainnet CNS root canister ID (rupqg-4qaaa-aaaad-qhosa-cai).
   */
  cnsRoot?: string | Principal | null;
}

const DEFAULT_API_GATEWAY = 'https://icp-api.io';
const DEFAULT_CNS_ROOT = 'rupqg-4qaaa-aaaad-qhosa-cai'; // Mainnet CNS Root Canister ID

enum RecordType {
  CID = 'CID',
  SID = 'SID',
  NC = 'NC',
  PTR = 'PTR',
}

/**
 * Client for interacting with the Chain Name System (CNS).
 *
 * This client provides methods for common functionality
 * provided by CNS, including looking up canister IDs and
 * naming canisters associated with a given domain.
 *
 * @example
 * ```ts
 * import { HttpAgent } from '@icp-sdk/core/agent';
 *
 * const agent = HttpAgent.createSync();
 * const cnsClient = new CnsClient({ agent });
 *
 * const canisterId = await cnsClient.lookupCanisterId('example.icp');
 * ```
 */
export class CnsClient {
  readonly #agent: HttpAgent;
  readonly #cnsRoot: Principal;

  readonly #operatorClients: Map<Principal, CnsRootClient> = new Map();
  readonly #namingCanisters: Map<string, Principal> = new Map();
  readonly #canisterIds: Map<string, Principal> = new Map();
  readonly #subnetIds: Map<string, Principal> = new Map();

  constructor({ agent, cnsRoot }: CnsClientArgs = {}) {
    this.#agent = agent ?? HttpAgent.createSync({ host: DEFAULT_API_GATEWAY });

    this.#cnsRoot = cnsRoot
      ? Principal.from(cnsRoot)
      : Principal.fromText(DEFAULT_CNS_ROOT);
  }

  /**
   * Looks up the canister ID for a given domain.
   *
   * @param domain The domain to look up.
   * @returns The canister ID associated with the domain.
   *
   * @example
   * ```ts
   * const canisterId = await cnsClient.lookupCanisterId('example.icp');
   * ```
   */
  public async lookupCanisterId(domain: string): Promise<Principal> {
    const normalizedDomain = normalizeDomain(domain);
    const existingCanisterId = this.#canisterIds.get(normalizedDomain);
    if (isNotNil(existingCanisterId)) {
      return existingCanisterId;
    }

    const namingCanister = await this.lookupNamingCanister(domain);
    const namingClient = this.getOperatorClient(namingCanister);
    const res = await namingClient.lookup({
      name: normalizedDomain,
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

  /**
   * Looks up the subnet ID for a given subnet name.
   *
   * @param domain The subnet name to look up.
   * @returns The subnet ID associated with the subnet name.
   *
   * @example
   * ```ts
   * const subnetId = await cnsClient.lookupSubnetId('example.icp');
   * ```
   */
  public async lookupSubnetId(domain: string): Promise<Principal> {
    const normalizedDomain = normalizeDomain(domain);
    const existingSubnetId = this.#subnetIds.get(normalizedDomain);
    if (isNotNil(existingSubnetId)) {
      return existingSubnetId;
    }

    const namingCanister = await this.lookupNamingCanister(normalizedDomain);
    const namingClient = this.getOperatorClient(namingCanister);
    const res = await namingClient.lookup({
      name: normalizedDomain,
      recordType: RecordType.SID,
    });

    const subnetId = getPrincipalAnswer(normalizedDomain, res, RecordType.SID);
    this.#subnetIds.set(domain, subnetId);
    return subnetId;
  }

  /**
   * Looks up the naming canister for a given domain.
   *
   * @param domain The domain to look up.
   * @returns The naming canister ID associated with the domain.
   *
   * @example
   * ```ts
   * const namingCanisterId = await cnsClient.lookupNamingCanister('example.icp');
   * ```
   */
  public async lookupNamingCanister(domain: string): Promise<Principal> {
    const normalizedTld = normalizeTld(domain);
    const existingNamingCanister = this.#namingCanisters.get(normalizedTld);
    if (isNotNil(existingNamingCanister)) {
      return existingNamingCanister;
    }

    const rootClient = this.getOperatorClient(this.#cnsRoot);
    const res = await rootClient.lookup({
      name: normalizedTld,
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

  /**
   * Looks up the PTR (Pointer) records for a given domain and ID.
   * These records map the given ID to a registered name,
   * essentially performing a reverse CNS lookup.
   *
   * @param tld The TLD to perform the reverse look up on. Note, if a full domain is passed,
   * only the TLD portion of the domain is used.
   * @param id The ID to perform the reverse look up for.
   * @returns The PTR (Pointer) records associated with the domain and ID.
   *
   * @example
   * ```ts
   * const ptrRecords = await cnsClient.reverseLookup('.icp', 'oa7fk-maaaa-aaaam-abgka-cai');
   * ```
   */
  public async reverseLookup(
    tld: string,
    id: Principal | string,
  ): Promise<DomainRecord[]> {
    const normalizedTld = normalizeTld(tld);
    const principal = Principal.from(id);

    const namingCanister = await this.lookupNamingCanister(tld);
    const namingClient = this.getOperatorClient(namingCanister);
    const res = await namingClient.lookup({
      name: `${principal.toText()}.reverse${normalizedTld}`,
      recordType: RecordType.PTR,
    });

    return res.answers;
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
  res: LookupResponse,
  recordType: RecordType,
): Principal {
  const answer = getAnswer(domain, res, recordType);
  return Principal.fromText(answer.data);
}

function getAnswer(
  domain: string,
  res: LookupResponse,
  recordType: RecordType,
): DomainRecord {
  const answer = res.answers.find(answer => answer.recordType === recordType);
  if (isNil(answer)) {
    throw new Error(`No ${recordType} record found for domain ${domain}`);
  }

  return answer;
}
