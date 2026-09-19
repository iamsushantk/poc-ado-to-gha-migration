export default function Home() {
  const environment = process.env.APP_ENVIRONMENT || 'unknown';
  const buildId = process.env.APP_BUILD_ID || 'unknown';

  return (
    <>
      <nav className="nav">
        <span className="nav-logo">subscription-portal</span>
        <ul className="nav-links">
          <li>
            <a href="#features">How it works</a>
          </li>
          <li>
            <a href="#">Vehicles</a>
          </li>
          <li>
            <a href="#">FAQs</a>
          </li>
        </ul>
      </nav>

      <header className="hero">
        <h1>Your new car, one monthly payment.</h1>
        <p>
          A novated car subscription bundles finance, insurance, servicing,
          tyres, and registration into a single predictable payment — taken
          straight from your pre-tax salary.
        </p>
        <a className="cta-button" href="#features">
          Get Started
        </a>
      </header>

      <section id="features" className="features">
        <div className="feature-card">
          <h3>All-inclusive pricing</h3>
          <p>
            Subscription cost, servicing, tyres, maintenance, comprehensive
            insurance, and re-registration are all budgeted into your weekly
            price.
          </p>
        </div>
        <div className="feature-card">
          <h3>Salary packaging benefits</h3>
          <p>
            Pay using pre-tax and post-tax salary via the Employee Contribution
            Method, with GST credits applied where eligible.
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
