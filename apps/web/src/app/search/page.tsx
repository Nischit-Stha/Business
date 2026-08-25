import Link from 'next/link';
import { StaffNav } from '@/components/staff-nav';
import { EmptyState, PageHeader, SearchInput, SectionCard, SeverityBadge, StatusBadge } from '@/components/ui';
import { requireStaff } from '@/lib/auth';

export default async function SearchPage({searchParams}:{searchParams:Promise<{q?:string}>}){
 const {q=''}=await searchParams;const term=q.trim().slice(0,80);const {supabase}=await requireStaff();
 const pattern=`%${term.replaceAll('%','')}%`;
 const [vehicles,customers,agreements,issues]=term.length<2?[{data:[]},{data:[]},{data:[]},{data:[]}]:await Promise.all([
  supabase.from('vehicles').select('id,registration,make,model,operational_status').or(`registration.ilike.${pattern},make.ilike.${pattern},model.ilike.${pattern}`).limit(8),
  supabase.from('customers').select('id,full_name,status').ilike('full_name',pattern).limit(8),
  /^[0-9a-f-]{36}$/i.test(term)?supabase.from('agreements').select('id,status,customers(full_name),vehicles(registration,make,model)').eq('id',term).limit(8):Promise.resolve({data:[]}),
  supabase.from('vehicle_issues').select('id,category,description,severity,status,vehicles(registration)').ilike('description',pattern).limit(8)
 ]);
 const total=[vehicles,customers,agreements,issues].reduce((n,r)=>n+(r.data?.length??0),0);
 return <main id="main-content"><StaffNav/><PageHeader eyebrow="Global search" title={term?`Results for “${term}”`:'Find anything'} description="Search operational summaries without exposing private documents or payment descriptions."/><form className="search-page-form"><SearchInput defaultValue={term} placeholder="Registration, make, model, customer or issue"/><button>Search</button></form>{term.length<2?<EmptyState title="Start typing" description="Enter at least two characters to search Veera operations."/>:total===0?<EmptyState title="No matches found" description="Try a registration, customer name, vehicle model, agreement ID or issue description."/>:<div className="search-results">{vehicles.data?.length?<SectionCard title="Vehicles">{vehicles.data.map(v=><Link className="search-result" href={`/fleet/${v.id}`} key={v.id}><span><strong>{v.make} {v.model}</strong><small>{v.registration}</small></span><StatusBadge status={v.operational_status}/></Link>)}</SectionCard>:null}{customers.data?.length?<SectionCard title="Customers">{customers.data.map(c=><Link className="search-result" href={`/customers/${c.id}`} key={c.id}><span><strong>{c.full_name}</strong><small>Customer</small></span><StatusBadge status={c.status}/></Link>)}</SectionCard>:null}{agreements.data?.length?<SectionCard title="Agreements">{agreements.data.map(a=><Link className="search-result" href={`/agreements/${a.id}`} key={a.id}><span><strong>{a.customers?.[0]?.full_name??'Agreement'}</strong><small>{a.vehicles?.[0]?.registration} · {a.id.slice(0,8)}</small></span><StatusBadge status={a.status}/></Link>)}</SectionCard>:null}{issues.data?.length?<SectionCard title="Vehicle issues">{issues.data.map(i=><Link className="search-result" href={`/operations/issues/${i.id}`} key={i.id}><span><strong>{i.category.replaceAll('_',' ')}</strong><small>{i.vehicles?.[0]?.registration} · {i.description}</small></span><SeverityBadge severity={i.severity}/></Link>)}</SectionCard>:null}</div>}</main>
}
