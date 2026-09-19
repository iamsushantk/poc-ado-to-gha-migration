// Render per-request so APP_ENVIRONMENT/APP_BUILD_ID (injected as App Service settings at deploy
// time) are read at runtime instead of being baked in as "unknown" during the Docker build.
export const dynamic = 'force-dynamic';

export default function Home() {
  const environment = process.env.APP_ENVIRONMENT || 'unknown';
  const buildId = process.env.APP_BUILD_ID || 'unknown';

  return (
    <main style={{ fontFamily: 'sans-serif', padding: '2rem' }}>
      <h1>subscription-portal</h1>
      <p>Next.js app deployed to Azure App Service via GitHub Actions OIDC.</p>
      <p>
        Environment: <strong>{environment}</strong>
      </p>
      <p>
        Build ID: <strong>{buildId}</strong>
      </p>
    </main>
  );
}
