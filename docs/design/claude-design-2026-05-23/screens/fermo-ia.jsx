// Fermo — Information architecture map
// Exposes: FermoIAMap

const IAGroup = ({ title, items, accent = 'var(--f-ok)' }) => (
  <div style={{
    padding: 18, background: 'var(--f-bg-2)', border: '1px solid var(--f-line)',
    borderRadius: 10, display: 'flex', flexDirection: 'column', gap: 14,
  }}>
    <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
      <span style={{ width: 6, height: 6, borderRadius: '50%', background: accent }}/>
      <span style={{ fontSize: 10.5, fontWeight: 700, color: 'var(--f-fg-3)', textTransform: 'uppercase', letterSpacing: 0.08 }}>{title}</span>
    </div>
    <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
      {items.map(it => (
        <div key={it.label} style={{ paddingLeft: it.indent ? 16 : 0 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '6px 0' }}>
            {it.icon && <FIcon name={it.icon} size={12} style={{ color: it.indent ? 'var(--f-fg-3)' : 'var(--f-fg-1)' }}/>}
            <span style={{ fontSize: 12.5, fontWeight: it.indent ? 400 : 500, color: it.indent ? 'var(--f-fg-2)' : 'var(--f-fg-0)' }}>{it.label}</span>
            {it.note && <span style={{ marginLeft: 'auto', fontSize: 10.5, color: 'var(--f-fg-3)', fontFamily: 'var(--f-font-mono)' }}>{it.note}</span>}
          </div>
        </div>
      ))}
    </div>
  </div>
);

const FermoIAMap = () => (
  <div style={{
    width: '100%', height: '100%', overflow: 'auto',
    background: 'var(--f-bg-1)', color: 'var(--f-fg-0)',
    fontFamily: 'var(--f-font)',
    padding: '40px 48px',
  }} className="fermo">
    <div style={{ fontSize: 12, fontWeight: 600, color: 'var(--f-fg-3)', textTransform: 'uppercase', letterSpacing: 0.06 }}>Information architecture</div>
    <div style={{ fontSize: 24, fontWeight: 600, marginTop: 4, letterSpacing: 0 }}>Two surfaces. One contract.</div>
    <div style={{ fontSize: 13, color: 'var(--f-fg-2)', marginTop: 8, maxWidth: 760, lineHeight: 1.55 }}>
      Fermo lives in two places: a menu bar utility for daily use, and a full window for setup, review, and honest status. Both surface the same six areas in the same order, so muscle memory transfers between them.
    </div>

    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 18, marginTop: 28 }}>
      <IAGroup
        title="Menu bar · daily flow"
        items={[
          { icon: 'fermo.mark', label: 'Protection state', note: 'idle · protected · degraded · approval' },
          { icon: 'play.fill',  label: 'Quick Start',      note: '4 recent presets' },
          { icon: 'clock',      label: 'Active session',   note: 'if running' },
          { label: 'task + time + rigor + mode', indent: true },
          { label: 'protected sites + apps summary', indent: true },
          { label: 'Stop / Break Glass action', indent: true },
          { icon: 'list.bullet.clipboard', label: 'Last session result', note: 'proof recorded · not done · needs evidence' },
          { icon: 'lock.shield', label: 'System Health indicator', note: 'compact pill' },
          { icon: 'arrow.up.right', label: 'Open Fermo window' },
        ]}
      />
      <IAGroup
        title="Main window · 6 areas"
        accent="var(--f-info)"
        items={[
          { icon: 'house',                label: 'Today',          note: 'dashboard · status strip · next contract · health · evidence' },
          { icon: 'play.fill',            label: 'Start Contract', note: 'preset → task → outcome → mode → room → duration → rigor → proof' },
          { icon: 'square.grid.2x2',      label: 'Rooms',          note: 'list + detail · allow/block lists · room builder' },
          { label: 'Focus Room Mode · allow only what belongs',  indent: true },
          { label: 'Blocklist Mode · block selected distractions', indent: true },
          { icon: 'list.bullet.clipboard',label: 'Evidence',       note: 'work ledger · filters · markdown export' },
          { icon: 'lock.shield',          label: 'System Health',  note: '8 checks · approvals · blocking · manual checks' },
          { icon: 'gearshape',            label: 'Preferences',    note: 'defaults · helper · evidence · privacy · diagnostics' },
        ]}
      />
    </div>

    {/* Flow */}
    <div style={{ fontSize: 11, fontWeight: 700, color: 'var(--f-fg-3)', textTransform: 'uppercase', letterSpacing: 0.08, margin: '32px 0 12px' }}>Primary flow · one protected contract</div>
    <div style={{
      padding: 22, background: 'var(--f-bg-2)', border: '1px solid var(--f-line)', borderRadius: 10,
      display: 'grid', gridTemplateColumns: 'repeat(5, 1fr)', gap: 0, alignItems: 'stretch',
    }}>
      {[
        { i: 'house',                  t: 'Today',           s: 'See state. Ready to start.' },
        { i: 'play.fill',              t: 'Start Contract',  s: 'Task + outcome + room + rigor.' },
        { i: 'lock.shield',            t: 'Active Session',  s: 'Protected. Notes. Live health.' },
        { i: 'square.and.pencil',      t: 'Proof Capture',   s: 'Record what happened.' },
        { i: 'list.bullet.clipboard',  t: 'Evidence Log',    s: 'Markdown ledger updates.' },
      ].map((step, i, arr) => (
        <div key={step.t} style={{ display: 'flex', alignItems: 'stretch', gap: 0 }}>
          <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 8 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
              <span style={{ fontSize: 10, fontFamily: 'var(--f-font-mono)', color: 'var(--f-fg-3)' }}>{String(i + 1).padStart(2, '0')}</span>
              <div style={{
                width: 26, height: 26, borderRadius: 6,
                background: 'var(--f-bg-3)', border: '1px solid var(--f-line-2)',
                display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--f-ok)',
              }}>
                <FIcon name={step.i} size={13}/>
              </div>
            </div>
            <div style={{ fontSize: 13, fontWeight: 600 }}>{step.t}</div>
            <div style={{ fontSize: 11.5, color: 'var(--f-fg-2)', lineHeight: 1.45 }}>{step.s}</div>
          </div>
          {i < arr.length - 1 && (
            <div style={{ flexShrink: 0, padding: '0 14px', display: 'flex', alignItems: 'center', color: 'var(--f-fg-3)' }}>
              <FIcon name="arrow.right" size={14}/>
            </div>
          )}
        </div>
      ))}
    </div>

    {/* Rigor states with diversions */}
    <div style={{ fontSize: 11, fontWeight: 700, color: 'var(--f-fg-3)', textTransform: 'uppercase', letterSpacing: 0.08, margin: '32px 0 12px' }}>Rigor branches · what happens at session-end</div>
    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 14 }}>
      {[
        { r: 'soft',      title: 'Soft',      desc: 'Stop is available. Friction nudges you to record proof but the path is open.', icon: 'lock.open' },
        { r: 'locked',    title: 'Locked',    desc: 'No normal stop. Timer must elapse. Then proof capture runs.', icon: 'lock' },
        { r: 'emergency', title: 'Emergency', desc: 'Stop only via Break Glass dialog — reason required, recorded as broke-glass.', icon: 'exclamationmark.triangle' },
      ].map(b => (
        <div key={b.r} style={{ padding: 16, background: 'var(--f-bg-2)', border: '1px solid var(--f-line)', borderRadius: 10 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <FIcon name={b.icon} size={14} style={{ color: 'var(--f-ok)' }}/>
            <span style={{ fontSize: 13, fontWeight: 600 }}>{b.title}</span>
          </div>
          <div style={{ fontSize: 12, color: 'var(--f-fg-2)', marginTop: 8, lineHeight: 1.55 }}>{b.desc}</div>
        </div>
      ))}
    </div>
  </div>
);

Object.assign(window, { FermoIAMap });
