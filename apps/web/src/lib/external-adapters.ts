import 'server-only';

export type ExternalResult<T>={kind:'SUCCESS';value:T}|{kind:'NOT_SUPPORTED'|'TEMPORARY_FAILURE'|'PERMANENT_FAILURE';safeMessage:string};
export type RentaContractPayload={internalAgreementId:string;customer:{externalReference?:string;legalName:string;email?:string;phone?:string};vehicle:{externalReference?:string;registration:string;vin?:string};terms:{startDate:string;endDate?:string;weeklyAmount:string;agreementType:string}};
export interface RentaAdapter{
 createOrUpdateContract(payload:RentaContractPayload):Promise<ExternalResult<{externalDocumentReference:string}>>;
 sendForSignature(externalDocumentReference:string):Promise<ExternalResult<{signingReference:string}>>;
 retrieveSigningStatus(signingReference:string):Promise<ExternalResult<{status:'PENDING'|'SIGNED'|'DECLINED'|'EXPIRED';updatedAt:string}>>;
 retrieveSignedPdf(signingReference:string):Promise<ExternalResult<{bytes:Uint8Array;mimeType:'application/pdf';checksumSha256:string}>>;
}
export type StarrLookup={customerExternalReference?:string;vehicleExternalReference?:string;registration?:string};
export interface Starr365Adapter{
 lookup(query:StarrLookup):Promise<ExternalResult<{customerReference?:string;vehicleReference?:string}>>;
 importTollsAndFines(cursor?:string):Promise<ExternalResult<{records:ReadonlyArray<unknown>;nextCursor?:string}>>;
 updateTransferStatus(externalNoticeReference:string,status:string):Promise<ExternalResult<{updatedAt:string}>>;
 synchronizeOperationalRecord(recordType:string,internalId:string,payload:Readonly<Record<string,unknown>>):Promise<ExternalResult<{externalReference:string}>>;
}
export class DisabledRentaAdapter implements RentaAdapter{private no():ExternalResult<never>{return{kind:'NOT_SUPPORTED',safeMessage:'RENTA integration is disabled'}}async createOrUpdateContract(){return this.no()}async sendForSignature(){return this.no()}async retrieveSigningStatus(){return this.no()}async retrieveSignedPdf(){return this.no()}}
export class DisabledStarr365Adapter implements Starr365Adapter{private no():ExternalResult<never>{return{kind:'NOT_SUPPORTED',safeMessage:'STARR365 integration is disabled'}}async lookup(){return this.no()}async importTollsAndFines(){return this.no()}async updateTransferStatus(){return this.no()}async synchronizeOperationalRecord(){return this.no()}}
