export function parseTollFineCsv(text: string) {
  const records: string[][]=[]; let row:string[]=[],cell='',quoted=false;
  for(let index=0;index<text.length;index+=1){const char=text[index];if(char==='"'&&quoted&&text[index+1]==='"'){cell+='"';index+=1;}else if(char==='"')quoted=!quoted;else if(char===','&&!quoted){row.push(cell);cell='';}else if((char==='\n'||char==='\r')&&!quoted){if(char==='\r'&&text[index+1]==='\n')index+=1;row.push(cell);if(row.some(v=>v.trim()))records.push(row);row=[];cell='';}else cell+=char;}
  row.push(cell);if(row.some(v=>v.trim()))records.push(row);
  if(quoted||records.length<2)throw new Error('CSV must contain a header and at least one row.');
  const headers=records[0].map(v=>v.trim().toLowerCase());
  const required=['registration','event_at','amount','external_reference','authority_provider','type'];
  if(headers.join('|')!==required.join('|'))throw new Error(`CSV columns must be exactly: ${required.join(', ')}`);
  if(records.length>501)throw new Error('Synthetic imports are limited to 500 rows.');
  return records.slice(1).map(fields=>Object.fromEntries(headers.map((header,index)=>[header,(fields[index]??'').trim()])));
}
