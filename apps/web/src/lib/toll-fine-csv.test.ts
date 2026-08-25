import {describe,expect,it} from 'vitest';
import {parseTollFineCsv} from './toll-fine-csv';

describe('toll/fine CSV parsing',()=>{
 it('parses quoted provider-neutral synthetic rows',()=>{const rows=parseTollFineCsv('registration,event_at,amount,external_reference,authority_provider,type\nABC123,2026-08-14T16:42:00+10:00,12.50,T-1,"Synthetic, Roads",TOLL');expect(rows[0]).toMatchObject({registration:'ABC123',external_reference:'T-1',authority_provider:'Synthetic, Roads',type:'TOLL'});});
 it('rejects unexpected columns',()=>{expect(()=>parseTollFineCsv('registration,amount\nABC123,1')).toThrow(/columns must be exactly/);});
});
