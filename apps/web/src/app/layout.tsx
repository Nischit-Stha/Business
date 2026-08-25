import type { Metadata } from 'next';
import type { ReactNode } from 'react';
import './styles.css';
import './operations.css';
import './workflows.css';
import './portal.css';
import { TrialBanner } from '@/components/trial-banner';

export const metadata: Metadata = {
  title: { default: 'Veera Operations', template: '%s · Veera' },
  description: 'Commercial fleet and rental operations platform',
};

export default function RootLayout({ children }: Readonly<{ children: ReactNode }>) {
  return (
    <html lang="en">
      <body><TrialBanner/>{children}</body>
    </html>
  );
}
