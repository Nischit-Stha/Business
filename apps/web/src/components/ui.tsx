import Link from 'next/link';
import type { ReactNode } from 'react';

export const humanize = (value: string) => value.replaceAll('_', ' ').toLowerCase().replace(/^./, c => c.toUpperCase());

export function PageHeader({eyebrow,title,description,actions,breadcrumbs}:{eyebrow?:string;title:string;description?:string;actions?:ReactNode;breadcrumbs?:{label:string;href?:string}[]}) {
  return <header className="page-header">{breadcrumbs&&<nav className="breadcrumbs" aria-label="Breadcrumb">{breadcrumbs.map((b,i)=><span key={b.label}>{i>0&&<i>/</i>}{b.href?<Link href={b.href}>{b.label}</Link>:<span aria-current="page">{b.label}</span>}</span>)}</nav>}<div className="page-header-row"><div>{eyebrow&&<p className="eyebrow">{eyebrow}</p>}<h1>{title}</h1>{description&&<p className="lede">{description}</p>}</div>{actions&&<div className="page-actions">{actions}</div>}</div></header>;
}
export function MetricCard({label,value,detail,tone='default'}:{label:string;value:ReactNode;detail?:ReactNode;tone?:'default'|'positive'|'warning'|'danger'}) {return <article className={`metric-card tone-${tone}`}><span>{label}</span><strong>{value}</strong>{detail&&<small>{detail}</small>}</article>}
export function StatusBadge({status}:{status:string}) {return <span className={`badge status-${status.toLowerCase().replaceAll('_','-')}`}><span className="badge-dot" aria-hidden="true"/>{humanize(status)}</span>}
export function SeverityBadge({severity}:{severity:string}) {return <span className={`badge severity-${severity.toLowerCase()}`}><span aria-hidden="true">{severity==='CRITICAL'?'⚠ ':''}</span>{humanize(severity)}</span>}
export function EmptyState({title,description,action}:{title:string;description?:string;action?:ReactNode}) {return <section className="empty-state" role="status"><span className="empty-icon" aria-hidden="true">✓</span><h3>{title}</h3>{description&&<p>{description}</p>}{action}</section>}
export function ErrorState({message='Something went wrong. Please try again.'}:{message?:string}) {return <div className="error-state" role="alert"><strong>We couldn’t load this</strong><span>{message}</span></div>}
export function LoadingState({label='Loading'}:{label?:string}) {return <div className="loading-state" role="status"><span className="spinner" aria-hidden="true"/>{label}…</div>}
export function SectionCard({title,description,action,children,className=''}:{title?:string;description?:string;action?:ReactNode;children:ReactNode;className?:string}) {return <section className={`section-card ${className}`}><div className="section-card-header"><div>{title&&<h2>{title}</h2>}{description&&<p>{description}</p>}</div>{action}</div>{children}</section>}
export function ActionButton({href,children,variant='primary'}:{href:string;children:ReactNode;variant?:'primary'|'secondary'|'danger'}) {return <Link href={href} className={`action-button button-${variant}`}>{children}</Link>}
export function FilterBar({children}:{children:ReactNode}) {return <div className="filter-bar" aria-label="Filters">{children}</div>}
export function SearchInput({name='q',defaultValue,placeholder='Search…'}:{name?:string;defaultValue?:string;placeholder?:string}) {return <label className="search-input"><span className="sr-only">Search</span><span aria-hidden="true">⌕</span><input name={name} defaultValue={defaultValue} placeholder={placeholder}/></label>}
export function DataTable({children,label}:{children:ReactNode;label:string}) {return <div className="table-wrap"><table aria-label={label}>{children}</table></div>}
export function FormField({label,hint,children}:{label:string;hint?:string;children:ReactNode}) {return <label className="form-field"><span>{label}</span>{children}{hint&&<small>{hint}</small>}</label>}
export function ActivityTimeline({items}:{items:{id:string;title:string;detail?:string;date:string}[]}) {return <ol className="timeline">{items.map(i=><li key={i.id}><span className="timeline-marker"/><div><strong>{i.title}</strong>{i.detail&&<p>{i.detail}</p>}<time>{i.date}</time></div></li>)}</ol>}
