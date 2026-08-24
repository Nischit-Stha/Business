import Link from 'next/link';

export default function HomePage() {
  return (
    <main>
      <p className="eyebrow">Veera Rentals</p>
      <h1>Fleet operations</h1>
      <p>
        Staff-only visibility for customers, vehicles, and vehicle custody history.
      </p>
      <nav className="home-links"><Link href="/fleet">Fleet</Link><Link href="/customers">Customers</Link><Link href="/assignments">Assignments</Link></nav>
    </main>
  );
}
