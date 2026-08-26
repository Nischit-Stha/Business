import 'server-only';

export type BankFeedTransaction={externalTransactionId:string;occurredAt:string;receivedAt:string;amount:string;currency:string;description?:string;reference?:string;reversesExternalTransactionId?:string};
export type BankFeedPage={transactions:readonly BankFeedTransaction[];nextCursor?:string};
export type BankFeedResult={kind:'SUCCESS';page:BankFeedPage}|{kind:'DISABLED'|'TEMPORARY_FAILURE'|'PERMANENT_FAILURE';safeMessage:string};
export interface BankFeedAdapter{readonly providerName:string;fetchTransactions(cursor?:string):Promise<BankFeedResult>}
export class DisabledBankFeedAdapter implements BankFeedAdapter{readonly providerName='DISABLED';async fetchTransactions():Promise<BankFeedResult>{return{kind:'DISABLED',safeMessage:'Bank feed integration is disabled; use reviewed synthetic CSV import in local/staging'}}}
