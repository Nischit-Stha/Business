'use client';

import { useState } from 'react';
import { importSyntheticCsv } from '@/lib/reconciliation-actions';

export function SyntheticCsvImport() {
  const [preview, setPreview] = useState<string[][]>([]);
  return <form action={importSyntheticCsv} className="form-card">
    <label>Synthetic CSV only<input name="file" type="file" accept=".csv,text/csv" required onChange={async (event) => {
      const file=event.target.files?.[0]; if(!file){setPreview([]);return;}
      const lines=(await file.text()).split(/\r?\n/).filter(Boolean).slice(0,6).map(line=>line.split(',')); setPreview(lines);
    }}/></label>
    {preview.length>0&&<div className="table-wrap"><table><tbody>{preview.map((row,index)=><tr key={index}>{row.map((cell,cellIndex)=><td key={cellIndex}>{cell}</td>)}</tr>)}</tbody></table></div>}
    <small>Preview shows up to five data rows. Quoted values are parsed authoritatively on the server.</small>
    <button>Import synthetic transactions</button>
  </form>;
}
