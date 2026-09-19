export default function Home() {
  const environment = process.env.APP_ENVIRONMENT || 'unknown';
  const buildId = process.env.APP_BUILD_ID || 'unknown';

  return (
    <>
      <nav className="nav">
        <span className="nav-logo">subscription-portal</span>
        <ul className="nav-links">
          <li>
            <a href="#features">Features</a>
          </li>
          <li>
            <a href="#">Pricing</a>
          </li>
          <li>
            <a href="#">About</a>
          </li>
        </ul>
      </nav>

      <header className="hero">
        <h1>Manage your subscriptions, simplified.</h1>
        <p>
          One dashboard for every subscription your team relies on — deployed
          via GitHub Actions OIDC straight to Azure App Service.
        </p>
        <a className="cta-button" href="#features">
          Get Started
        </a>
      </header>

      <section id="features" className="features">
        <div className="feature-card">
          <h3>Automated deployments</h3>
          <p>
            Every commit is built, pushed to ACR, and deployed through a
            centralized workflow with no manual steps.
          </p>
        </div>
        <div className="feature-card">
          <h3>Secure by default</h3>
          <p>
            Azure OIDC federated credentials replace long-lived secrets across
            every environment.
          </p>
        </div>
        <div className="feature-card">
          <h3>Environment aware</h3>
          <p>
            Currently running in <strong>{environment}</strong>, so you always
            know what you&apos;re looking at.
          </p>
        </div>
      </section>

      <footer className="footer">
        <p>
          Environment: <strong>{environment}</strong> &middot; Build ID:{' '}
          <strong>{buildId}</strong>
        </p>
      </footer>
    </>
  );
}
