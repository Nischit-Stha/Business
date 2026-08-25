'use client';

import { useState } from 'react';
import { importTollFineCsv } from '@/lib/collections-actions';

export function TollFineCsvImport(){
  const [name,setName]=useState('');
  return <form action={importTollFineCsv} className="form-card">
    <label>Synthetic CSV<input name="file" type="file" accept=".csv,text/csv" required onChange={event=>setName(event.target.files?.[0]?.name??'')}/></label>
    {name&&<small>Ready to validate and import: {name}</small>}
    <small>Columns: registration, event_at, amount, external_reference, authority_provider, type. Maximum 500 rows / 500 KB.</small>
    <button>Import and match</button>
  </form>;
}
