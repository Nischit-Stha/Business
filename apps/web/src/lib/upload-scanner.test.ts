import { describe,expect,it } from 'vitest';
import { scanUpload } from './upload-scanner';
describe('upload scanning boundary',()=>{
 it('allows structural-only synthetic development testing',async()=>expect((await scanUpload(new Uint8Array(),{VEERA_RUNTIME_MODE:'development'})).verdict).toBe('clean'));
 it('fails closed in staging and production, including misleading configuration',async()=>{
  expect((await scanUpload(new Uint8Array(),{VEERA_RUNTIME_MODE:'trial'})).verdict).toBe('unavailable');
  expect((await scanUpload(new Uint8Array(),{VEERA_RUNTIME_MODE:'production',UPLOAD_SCANNER:'configured'})).verdict).toBe('unavailable');
 });
});
