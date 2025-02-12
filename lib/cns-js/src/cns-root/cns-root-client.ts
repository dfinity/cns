import { Actor, ActorSubclass, HttpAgent } from '@dfinity/agent';
import { Principal } from '@dfinity/principal';
import { _SERVICE, idlFactory } from '../declarations/cns-root/cns_root.did';
import {
  LookupDomainRequest,
  LookupDomainResponse,
  RegisterDomainRequest,
} from './cns-root-types';
import {
  mapDomainLookupResponse,
  mapDomainRegistrationResponse,
  mapRegistrationRecordRequest,
} from './cns-root-mappings';

export interface CnsRootClientArgs {
  agent: HttpAgent;
  canisterId: string | Principal;
}

export class CnsRootClient {
  readonly #actor: ActorSubclass<_SERVICE>;

  constructor({ agent, canisterId }: CnsRootClientArgs) {
    this.#actor = Actor.createActor<_SERVICE>(idlFactory, {
      agent,
      canisterId,
    });
  }

  public async lookupDomain({
    domain,
    recordType,
  }: LookupDomainRequest): Promise<LookupDomainResponse> {
    const canisterRes = await this.#actor.lookup(domain, recordType);
    return mapDomainLookupResponse(canisterRes);
  }

  public async registerDomain({
    domain,
    records,
  }: RegisterDomainRequest): Promise<void> {
    const canisterRes = await this.#actor.register(
      domain,
      mapRegistrationRecordRequest(records),
    );
    return mapDomainRegistrationResponse(canisterRes);
  }
}
