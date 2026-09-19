import './globals.css';

// Applies to every route in the app (root layout config propagates to all pages), so nothing is
// statically prerendered — all pages are server-rendered per-request instead.
export const dynamic = 'force-dynamic';

export const metadata = {
  title: 'subscription-portal',
  description:
    'Next.js scaffold deployed via GitHub Actions OIDC to Azure App Service',
};

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
