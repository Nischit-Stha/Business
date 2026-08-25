import { describe, expect, it } from 'vitest';
import { LocalNotificationProvider, ResendEmailProvider } from './notification-provider';
const base={id:'synthetic-id',channel:'SMS' as const,recipient:'+61400000000',subject:null,renderedMessage:'Synthetic message'};
describe('LocalNotificationProvider',()=>{
 it('returns a stable synthetic provider id without network delivery',async()=>expect(await new LocalNotificationProvider().deliver(base)).toEqual({kind:'SUCCESS',providerMessageId:'local:synthetic-id'}));
 it('supports simulated bounded-retry outcomes',async()=>expect((await new LocalNotificationProvider().deliver({...base,recipient:'temporary@example.test'})).kind).toBe('TEMPORARY_FAILURE'));
});
describe('ResendEmailProvider',()=>{
 it('sends email with an idempotency key and returns the provider id',async()=>{let headers:HeadersInit|undefined;const fetch=async(_input:RequestInfo|URL,init?:RequestInit)=>{headers=init?.headers;return new Response(JSON.stringify({id:'email_synthetic'}),{status:200,headers:{'content-type':'application/json'}})};const result=await new ResendEmailProvider({apiKey:'synthetic',from:'trial@example.test',fetch:fetch as typeof globalThis.fetch}).deliver({...base,channel:'EMAIL',recipient:'person@example.test'});expect(result).toEqual({kind:'SUCCESS',providerMessageId:'email_synthetic'});expect(headers).toMatchObject({'Idempotency-Key':'veera-notification-synthetic-id'});});
 it('maps provider details to a safe rate-limit category',async()=>{const fetch=async()=>new Response('sensitive provider body',{status:429});expect(await new ResendEmailProvider({apiKey:'synthetic',from:'trial@example.test',fetch:fetch as typeof globalThis.fetch}).deliver({...base,channel:'EMAIL',recipient:'person@example.test'})).toEqual({kind:'TEMPORARY_FAILURE',message:'RATE_LIMIT'});});
});
