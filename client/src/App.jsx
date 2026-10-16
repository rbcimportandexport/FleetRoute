const ArrowUpRight = () => (
  <svg viewBox="0 0 24 24" aria-hidden="true">
    <path d="M7 17 17 7M8 7h9v9" />
  </svg>
);

const RouteMark = () => (
  <svg viewBox="0 0 40 40" aria-hidden="true" className="route-mark">
    <path d="M8 29.5c0-5.2 3.7-7.2 7.8-7.2h8.4c4.1 0 7.8-2 7.8-7.3" />
    <circle cx="8" cy="29.5" r="3.2" />
    <circle cx="32" cy="14.5" r="3.2" />
  </svg>
);

export default function App() {
  return (
    <main className="site-shell">
      <nav className="nav" aria-label="Primary navigation">
        <a className="brand" href="#top" aria-label="FleetRoute home">
          <span className="brand-mark"><RouteMark /></span>
          <span>FleetRoute</span>
        </a>
        <div className="nav-links">
          <a href="#platform">Platform</a>
          <a href="#approach">Approach</a>
          <a href="#integrate">Integrate</a>
        </div>
        <a className="nav-action" href="#integrate">
          Explore
          <ArrowUpRight />
        </a>
      </nav>

      <section className="hero" id="top">
        <div className="hero-copy">
          <div className="eyebrow"><span /> Built for movement</div>
          <h1>Every route.<br /><span>One clear direction.</span></h1>
          <p>
            A focused digital foundation for modern fleet operations—designed to
            bring vehicles, people, and journeys into one calm workspace.
          </p>
          <div className="hero-actions">
            <a className="primary-button" href="#platform">
              Discover FleetRoute
              <ArrowUpRight />
            </a>
            <a className="text-link" href="#approach">See our approach</a>
          </div>
        </div>

        <div className="route-canvas" aria-label="Abstract route network illustration">
          <div className="canvas-label">ROUTE / 01</div>
          <svg viewBox="0 0 620 600" role="img" aria-hidden="true">
            <defs>
              <linearGradient id="routeGradient" x1="0" y1="1" x2="1" y2="0">
                <stop offset="0" stopColor="#94f3c0" />
                <stop offset="1" stopColor="#d8ff69" />
              </linearGradient>
            </defs>
            <path className="ghost-route" d="M-30 472C94 472 81 348 197 348h130c102 0 79-162 201-162h120" />
            <path className="active-route" d="M-30 472C94 472 81 348 197 348h130c102 0 79-162 201-162h120" />
            <circle className="route-node node-one" cx="198" cy="348" r="8" />
            <circle className="route-node node-two" cx="471" cy="204" r="8" />
            <g className="vehicle" transform="translate(310 323)">
              <rect width="58" height="38" rx="10" />
              <path d="M13 14h24l8 9H13z" />
              <circle cx="17" cy="34" r="4" />
              <circle cx="43" cy="34" r="4" />
            </g>
          </svg>
          <div className="canvas-note">A connected operating layer</div>
        </div>
      </section>

      <section className="statement" id="platform">
        <p className="section-index">01 / Platform</p>
        <h2>Complex operations deserve a simple interface.</h2>
        <p className="statement-copy">
          FleetRoute is shaped as a modular experience, ready to fit within a
          larger product without bringing unnecessary screens, sample records,
          or rigid workflows with it.
        </p>
      </section>

      <section className="principles" id="approach">
        <p className="section-index">02 / Approach</p>
        <div className="principle-grid">
          <article>
            <span>01</span>
            <h3>Clear by default</h3>
            <p>Quiet visual hierarchy keeps the important action visible and the interface easy to scan.</p>
          </article>
          <article>
            <span>02</span>
            <h3>Built in modules</h3>
            <p>Independent sections can grow with the product without forcing the whole experience to change.</p>
          </article>
          <article>
            <span>03</span>
            <h3>Ready to adapt</h3>
            <p>A responsive foundation designed to feel considered on desktop, tablet, and mobile screens.</p>
          </article>
        </div>
      </section>

      <section className="integrate" id="integrate">
        <div>
          <p className="section-index">03 / Next step</p>
          <h2>Designed to become<br />your interface.</h2>
        </div>
        <p>
          This is a presentation-only foundation. Connect your own components,
          product logic, and visual system when you are ready.
        </p>
      </section>

      <footer>
        <a className="brand footer-brand" href="#top">
          <span className="brand-mark"><RouteMark /></span>
          <span>FleetRoute</span>
        </a>
        <p>Structure for motion.</p>
        <a href="#top">Back to top</a>
      </footer>
    </main>
  );
}
