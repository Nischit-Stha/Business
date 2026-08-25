import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { EmptyState, MetricCard, PageHeader, SeverityBadge, StatusBadge } from './ui';

describe('shared operations UI',()=>{
 it('renders a structured page heading and action area',()=>{const html=renderToStaticMarkup(<PageHeader eyebrow="Fleet operations" title="Fleet" description="Vehicle readiness" actions={<button>Add vehicle</button>}/>);expect(html).toContain('<h1>Fleet</h1>');expect(html).toContain('Vehicle readiness');expect(html).toContain('page-actions')});
 it('presents statuses with text as well as colour',()=>{const html=renderToStaticMarkup(<><StatusBadge status="OFF_ROAD"/><SeverityBadge severity="CRITICAL"/></>);expect(html).toContain('Off road');expect(html).toContain('Critical');expect(html).toContain('⚠')});
 it('provides an accessible empty state',()=>{const html=renderToStaticMarkup(<EmptyState title="Everyone is up to date." description="No overdue payments."/>);expect(html).toContain('role="status"');expect(html).toContain('Everyone is up to date.')});
 it('supports attention tones on metric cards',()=>{const html=renderToStaticMarkup(<MetricCard label="Overdue" value={3} tone="danger"/>);expect(html).toContain('tone-danger');expect(html).toContain('<strong>3</strong>')});
});
