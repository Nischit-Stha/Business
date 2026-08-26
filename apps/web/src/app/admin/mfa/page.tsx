import { MfaManager } from '@/components/mfa-manager';
import { StaffNav } from '@/components/staff-nav';
import { requireStaff } from '@/lib/auth';

export default async function MfaPage({searchParams}:{searchParams:Promise<{mode?:string}>}){const {profile}=await requireStaff();if(profile.role!=='ADMIN')return <main className="page-shell"><h1>Access denied</h1></main>;const mode=(await searchParams).mode==='challenge'?'challenge':'enroll';return <><StaffNav/><main className="page-shell"><h1>Administrator multi-factor authentication</h1><MfaManager mode={mode}/><section><h2>Recovery guidance</h2><p>Keep a second verified authenticator factor where operationally possible. If all factors are lost, a separately authenticated project owner must verify identity, remove the lost factor through the Supabase administration boundary, require password reset, and record the recovery. Never ask for or store authenticator secrets or one-time codes.</p></section></main></>}
