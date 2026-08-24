import { getAssignmentHistory } from '@/lib/fleet';
import { StaffNav } from '@/components/staff-nav';

export const dynamic = 'force-dynamic';

export default async function AssignmentsPage() {
  const assignments = await getAssignmentHistory();
  return <main><StaffNav/><p className="eyebrow">Custody history</p><h1>Assignments</h1><div className="table-wrap"><table><thead><tr><th>Vehicle</th><th>Customer</th><th>Assigned</th><th>Returned</th><th>Odometer</th><th>Status</th></tr></thead><tbody>{assignments.map((assignment) => <tr key={assignment.id}><td>{assignment.vehicles?.[0]?.registration ?? '—'}</td><td>{assignment.customers?.[0]?.full_name ?? '—'}</td><td>{new Date(assignment.assigned_at).toLocaleString('en-AU')}</td><td>{assignment.returned_at ? new Date(assignment.returned_at).toLocaleString('en-AU') : 'Current'}</td><td>{assignment.pickup_odometer.toLocaleString()} → {assignment.return_odometer?.toLocaleString() ?? '—'}</td><td>{assignment.assignment_status}</td></tr>)}</tbody></table></div>{assignments.length === 0 && <p className="empty">No assignment history yet.</p>}</main>;
}
