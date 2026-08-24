import { describe, expect, it } from 'vitest';
import { LocalNotificationProvider } from './notification-provider';
const base={id:'synthetic-id',channel:'SMS' as const,recipient:'+61400000000',subject:null,renderedMessage:'Synthetic message'};
describe('LocalNotificationProvider',()=>{
 it('returns a stable synthetic provider id without network delivery',async()=>expect(await new LocalNotificationProvider().deliver(base)).toEqual({kind:'SUCCESS',providerMessageId:'local:synthetic-id'}));
 it('supports simulated bounded-retry outcomes',async()=>expect((await new LocalNotificationProvider().deliver({...base,recipient:'temporary@example.test'})).kind).toBe('TEMPORARY_FAILURE'));
});
