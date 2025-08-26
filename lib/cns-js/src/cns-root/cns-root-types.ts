import { Principal } from '@icp-sdk/core/principal';

export interface LookupRequest {
  name: string;
  recordType: string;
}

export interface LookupResponse {
  answers: DomainRecord[];
  additionals: DomainRecord[];
  authorities: DomainRecord[];
}

export interface RegisterDomainRequest {
  domain: string;
  records: RegistrationRecordRequest;
}

export interface RegistrationRecordRequest {
  controller: RegistrationControllerRequest[];
  records?: DomainRecord[] | null;
}

export interface RegistrationControllerRequest {
  controller_id: string | Principal;
  roles: ControllerRole[];
}

export interface DomainRecord {
  ttl: bigint;
  recordType: string;
  data: string;
  name: string;
}

export enum ControllerRole {
  ADMINISTRATIVE = 'administrative',
  TECHNICAL = 'technical',
  REGISTRAR = 'registrar',
  REGISTRANT = 'registrant',
}
