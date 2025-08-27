import { Actor, ActorSubclass, HttpAgent } from '@icp-sdk/core/agent';
import { Principal } from '@icp-sdk/core/principal';
import { _SERVICE, idlFactory } from '../declarations/cns-root/cns_root.did';
import {
  LookupRequest,
  LookupResponse,
  RegisterDomainRequest,
} from './cns-root-types';
import {
  mapLookupResponse,
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

  public async lookup({
    name,
    recordType,
  }: LookupRequest): Promise<LookupResponse> {
    const canisterRes = await this.#actor.lookup(name, recordType);
    return mapLookupResponse(canisterRes);
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
