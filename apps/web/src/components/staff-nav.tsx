import { requireStaff } from '@/lib/auth';
import { StaffNavigation } from './staff-navigation';
export async function StaffNav() { const {profile}=await requireStaff(); return <StaffNavigation name={profile.full_name} role={profile.role}/>; }
