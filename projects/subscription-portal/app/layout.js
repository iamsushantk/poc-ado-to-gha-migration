export const metadata = {
  title: 'subscription-portal',
  description: 'Next.js scaffold deployed via GitHub Actions OIDC to Azure App Service',
};

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
