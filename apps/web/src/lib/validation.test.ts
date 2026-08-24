import { describe, expect, it } from 'vitest';
import { customerInput, vehicleInput } from './validation';

function form(values: Record<string, string>) { const data = new FormData(); Object.entries(values).forEach(([key,value]) => data.set(key,value)); return data; }
describe('management validation', () => {
  it('accepts a complete synthetic customer', () => { const { errors } = customerInput(form({ fullName:'Taylor Example', phone:'0400 000 222', email:'taylor@example.test', licenceNumber:'SYN-22', licenceExpiry:'2030-01-01', address:'22 Example Street' })); expect(errors).toEqual({}); });
  it('rejects invalid customer fields', () => { const { errors } = customerInput(form({ fullName:'', phone:'abc', email:'bad', licenceNumber:'', licenceExpiry:'', address:'' })); expect(Object.keys(errors)).toEqual(['fullName','phone','email','licenceNumber','licenceExpiry','address']); });
  it('rejects assignment status in vehicle authoring', () => { const { errors } = vehicleInput(form({ registration:'SYN22', make:'Test', model:'Car', year:'2024', odometer:'10', weeklyRate:'400', operationalStatus:'ASSIGNED' })); expect(errors.operationalStatus).toMatch(/non-assignment/); });
});
