'use client';

import Image from 'next/image';
import { useRouter } from 'next/navigation';
import { useEffect, useMemo, useState } from 'react';
import { createSupabaseBrowserClient } from '@/lib/supabase/browser';

export function MfaManager({ mode }: { mode: 'enroll' | 'challenge' }) {
  const [factorId,setFactorId]=useState(''); const [qr,setQr]=useState(''); const [code,setCode]=useState(''); const [message,setMessage]=useState('');
  const supabase=useMemo(()=>createSupabaseBrowserClient(),[]); const router=useRouter();
  useEffect(()=>{void (async()=>{const {data}=await supabase.auth.mfa.listFactors();const verified=data?.totp.find(f=>f.status==='verified');if(verified){setFactorId(verified.id);return;}if(mode==='enroll'){const {data:enrolled,error}=await supabase.auth.mfa.enroll({factorType:'totp',friendlyName:'Veera administrator'});if(error)setMessage('MFA enrollment could not start. Sign out and try again.');else{setFactorId(enrolled.id);setQr(enrolled.totp.qr_code);}}})();},[mode,supabase.auth.mfa]);
  async function verify(){setMessage('');const challenge=await supabase.auth.mfa.challenge({factorId});if(challenge.error){setMessage('The verification challenge could not start.');return;}const result=await supabase.auth.mfa.verify({factorId,challengeId:challenge.data.id,code});if(result.error){setMessage('That code was not accepted. Try the current code.');return;}router.push('/admin/environment');router.refresh();}
  return <section className="form-card" aria-labelledby="mfa-heading"><h2 id="mfa-heading">{mode==='enroll'?'Enroll an authenticator':'Verify your authenticator'}</h2>{qr&&<><p>Scan this QR code with a trusted authenticator app. Do not screenshot or share it.</p><Image src={qr} alt="Authenticator enrollment QR code" width={220} height={220} unoptimized/></>}<label>Six-digit code<input value={code} onChange={e=>setCode(e.target.value.replace(/\D/g,'').slice(0,6))} inputMode="numeric" autoComplete="one-time-code" pattern="[0-9]{6}" required/></label><button type="button" disabled={!factorId||code.length!==6} onClick={()=>void verify()}>Verify MFA</button>{message&&<p role="alert" className="error">{message}</p>}</section>;
}
