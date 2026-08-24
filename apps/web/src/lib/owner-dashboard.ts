export type Severity = 'CRITICAL' | 'HIGH' | 'MEDIUM' | 'LOW';

export type AttentionItem = {
  id: string;
  type: string;
  severity: Severity;
  description: string;
  subject: string | null;
  date: string;
  href: string;
  status: 'OPEN' | 'ASSIGNED';
  manageable: boolean;
};

export type OwnerDashboard = {
  payments: { expected_today: number; received_today: number; overdue_count: number; overdue_amount: number; manual_review: number; failed_or_ambiguous: number };
  fleet: { total: number; rented: number; available: number; pickup_today: number; returning_today: number; workshop: number; unavailable: number };
  maintenance: { approaching_service: number; due_service: number; overdue_service: number; in_workshop: number };
  customers: { pending_approval: number; active: number; with_overdue_payments: number; missing_or_expiring_documents: number };
  attention: AttentionItem[];
};

const severityRank: Record<Severity, number> = { CRITICAL: 0, HIGH: 1, MEDIUM: 2, LOW: 3 };

export function prioritizeAttention(items: AttentionItem[]) {
  return [...items].sort((a, b) => severityRank[a.severity] - severityRank[b.severity] || a.date.localeCompare(b.date) || a.id.localeCompare(b.id));
}
