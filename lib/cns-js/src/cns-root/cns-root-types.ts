import { Principal } from '@dfinity/principal';

export interface LookupDomainRequest {
  domain: string;
  recordType: string;
}

export interface LookupDomainResponse {
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
  domainRecords?: DomainRecord[] | null;
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
