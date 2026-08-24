import { NextResponse } from 'next/server';

export const dynamic = 'force-dynamic';

export function GET() {
  return NextResponse.json(
    { service: 'veera-v2-web', status: 'ok' },
    { headers: { 'Cache-Control': 'no-store' } },
  );
}
