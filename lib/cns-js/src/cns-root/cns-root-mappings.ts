import { Principal } from '@dfinity/principal';
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
  LookupDomainResponse,
  DomainRecord,
  RegistrationControllerRequest,
  RegistrationRecordRequest,
} from './cns-root-types';
import { fromCandidOpt, toCandidOpt } from '../utils';

export function mapDomainLookupResponse(
  res: CanisterDomainLookup,
): LookupDomainResponse {
  return {
    answers: res.answers.map(mapDomainRecordResponse),
    additionals: res.additionals.map(mapDomainRecordResponse),
    authorities: res.authorities.map(mapDomainRecordResponse),
  };
}

export function mapRegistrationRecordRequest(
  req: RegistrationRecordRequest,
): CanisterRegistrationRecords {
  return {
    controller: req.controller.map(mapRegistrationControllerRequest),
    records: toCandidOpt(req.domainRecords?.map(mapDomainRecordRequest)),
  };
}

export function mapRegistrationControllerRequest(
  req: RegistrationControllerRequest,
): CanisterRegistrationController {
  return {
    principal: Principal.from(req.principal),
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

export function mapDomainRecordRequest(
  req: DomainRecord,
): CanisterDomainRecord {
  return {
    ttl: req.ttl,
    record_type: req.recordType,
    data: req.data,
    name: req.name,
  };
}

export function mapDomainRecordResponse(
  res: CanisterDomainRecord,
): DomainRecord {
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
