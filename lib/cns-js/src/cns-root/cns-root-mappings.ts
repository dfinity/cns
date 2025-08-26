import { Principal } from '@icp-sdk/core/principal';
import {
  DomainRecord as CanisterDomainRecord,
  DomainLookup as CanisterDomainLookup,
  RegistrationControllerRole as CanisterControllerRole,
  RegistrationRecords as CanisterRegistrationRecords,
  RegistrationController as CanisterRegistrationController,
  RegisterResult as CanisterRegisterResult,
} from '../declarations/cns-root/cns_root.did';
import {
  ControllerRole,
  LookupResponse,
  DomainRecord,
  RegistrationControllerRequest,
  RegistrationRecordRequest,
} from './cns-root-types';
import { fromCandidOpt, toCandidOpt } from '../utils';

export function mapLookupResponse(res: CanisterDomainLookup): LookupResponse {
  return {
    answers: res.answers.map(mapRecordResponse),
    additionals: res.additionals.map(mapRecordResponse),
    authorities: res.authorities.map(mapRecordResponse),
  };
}

export function mapRegistrationRecordRequest(
  req: RegistrationRecordRequest,
): CanisterRegistrationRecords {
  return {
    controllers: req.controller.map(mapRegistrationControllerRequest),
    records: toCandidOpt(req.records?.map(mapRecordRequest)),
  };
}

export function mapRegistrationControllerRequest(
  req: RegistrationControllerRequest,
): CanisterRegistrationController {
  return {
    controller_id: Principal.from(req.controller_id),
    roles: req.roles.map(mapControllerRoleRequest),
  };
}

export function mapDomainRegistrationResponse(
  res: CanisterRegisterResult,
): void {
  if (!res.success) {
    const errMsg = fromCandidOpt(res.message);

    if (errMsg !== null) {
      throw new Error(res.message[0]);
    }

    throw new Error('Domain registration failed with no error message');
  }
}

export function mapRecordRequest(req: DomainRecord): CanisterDomainRecord {
  return {
    ttl: req.ttl,
    record_type: req.recordType,
    data: req.data,
    name: req.name,
  };
}

export function mapRecordResponse(res: CanisterDomainRecord): DomainRecord {
  return {
    ttl: res.ttl,
    recordType: res.record_type,
    data: res.data,
    name: res.name,
  };
}

export function mapControllerRoleRequest(
  req: ControllerRole,
): CanisterControllerRole {
  switch (req) {
    case ControllerRole.ADMINISTRATIVE:
      return { administrative: null };
    case ControllerRole.TECHNICAL:
      return { technical: null };
    case ControllerRole.REGISTRAR:
      return { registrar: null };
    case ControllerRole.REGISTRANT:
      return { registrant: null };
  }
}
