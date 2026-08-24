import { describe, expect, it } from 'vitest';
import { prioritizeAttention, type AttentionItem } from './owner-dashboard';

const item = (id: string, severity: AttentionItem['severity'], date: string): AttentionItem => ({ id, severity, date, type: 'TEST', description: 'Synthetic issue', subject: null, href: '/owner', status: 'OPEN', manageable: true });

describe('owner attention prioritization', () => {
  it('orders severity first and oldest due date second without mutating input', () => {
    const input = [item('medium', 'MEDIUM', '2026-08-01'), item('new-high', 'HIGH', '2026-08-10'), item('old-high', 'HIGH', '2026-08-02')];
    expect(prioritizeAttention(input).map(({ id }) => id)).toEqual(['old-high', 'new-high', 'medium']);
    expect(input[0].id).toBe('medium');
  });

  it('returns an empty queue for an empty business state', () => expect(prioritizeAttention([])).toEqual([]));
});
