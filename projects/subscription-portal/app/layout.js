import './globals.css';

// Applies to every route in the app (root layout config propagates to all pages), so nothing is
// statically prerendered — all pages are server-rendered per-request instead.
export const dynamic = 'force-dynamic';

export const metadata = {
  title: 'Subscription Portal — Salary-Packaged Car Subscriptions',
  description:
    'A demo portal for browsing novated car subscription plans, where finance, insurance, and servicing are bundled into one predictable payment.',
};

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
