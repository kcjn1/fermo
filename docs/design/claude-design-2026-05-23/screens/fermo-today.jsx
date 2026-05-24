// Fermo — Today dashboard (status strip + next contract + health + evidence)
// Used inside FermoWindow. Variants: ready, protected, approval, degraded, post-session
// Exposes: FermoToday

const StatusStrip = ({ tone = 'ok', label, reason, action }) => {
  const color = tone === 'ok' ? 'var(--f-ok)' : tone === 'warn' ? 'var(--f-warn)' : tone === 'info' ? 'var(--f-info)' : tone === 'danger' ? 'var(--f-danger)' : 'var(--f-fg-2)';
  const bg    = tone === 'ok' ? 'var(--f-ok-bg)' : tone === 'warn' ? 'var(--f-warn-bg)' : tone === 'info' ? 'var(--f-info-bg)' : tone === 'danger' ? 'var(--f-danger-bg)' : 'var(--f-muted-bg)';
  return (
    <div style={{
      display: 'flex', alignItems: 'center', gap: 12,
      padding: '10px 22px',
      background: bg,
      borderBottom: `1px solid ${color === 'var(--f-fg-2)' ? 'var(--f-line)' : color}`,
      borderTopColor: 'transparent',
    }}>
      <span style={{ width: 7, height: 7, borderRadius: '50%', background: color, boxShadow: `0 0 0 4px ${bg}` }}/>
      <span style={{ fontSize: 12, fontWeight: 600, color, letterSpacing: 0.02, textTransform: 'uppercase' }}>{label}</span>
      <span style={{ fontSize: 12, color: 'var(--f-fg-1)' }}>{reason}</span>
      {action && <button className="fermo-btn fermo-btn-secondary fermo-btn-sm" style={{ marginLeft: 'auto' }}>{action}</button>}
    </div>
  );
};

const Card = ({ title, action, children, style }) => (
  <div className="fermo-card" style={{ overflow: 'hidden', ...style }}>
    {title && (
      <div style={{ padding: '12px 16px', display: 'flex', alignItems: 'center', justifyContent: 'space-between', borderBottom: '1px solid var(--f-line)' }}>
        <div style={{ fontSize: 12.5, fontWeight: 600, letterSpacing: 0 }}>{title}</div>
        {action}
      </div>
    )}
    {children}
  </div>
);

// ─────────────────────────────────────────────────────────────
// Next contract panel (idle / next session preview)
// ─────────────────────────────────────────────────────────────
const NextContract = ({ task, outcome, room, duration, rigor, mode = 'room', primary }) => (
  <div className="fermo-card" style={{ padding: 20, display: 'flex', flexDirection: 'column', gap: 16 }}>
    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
        <FIcon name="doc.text" size={13} style={{ color: 'var(--f-fg-2)' }}/>
        <span style={{ fontSize: 11, fontWeight: 600, color: 'var(--f-fg-3)', letterSpacing: 0.06, textTransform: 'uppercase' }}>Next contract · saved draft</span>
      </div>
      <button className="fermo-btn fermo-btn-ghost fermo-btn-sm"><FIcon name="square.and.pencil" size={11}/> Edit</button>
    </div>
    <div>
      <div style={{ fontSize: 19, fontWeight: 600, letterSpacing: 0 }}>{task}</div>
      <div style={{ fontSize: 13, color: 'var(--f-fg-1)', marginTop: 6, maxWidth: 640, lineHeight: 1.5 }}>{outcome}</div>
    </div>
    <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
      <Chip><FIcon name={mode === 'room' ? 'door.left.hand.closed' : 'minus.circle'} size={10}/> {mode === 'room' ? 'Focus Room' : 'Blocklist'} · {room}</Chip>
      <Chip mono><FIcon name="clock" size={10}/> {duration}</Chip>
      <Chip><FIcon name={RIGOR_DEFS[rigor].icon} size={10}/> {RIGOR_DEFS[rigor].name}</Chip>
      <Chip><FIcon name="checkmark.seal" size={10}/> Proof: Markdown note</Chip>
    </div>
    <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
      {primary}
      <button className="fermo-btn fermo-btn-secondary"><FIcon name="forward.end.fill" size={10}/> Change rigor or duration</button>
    </div>
  </div>
);

// ─────────────────────────────────────────────────────────────
// Compact health summary (5 rows, dense)
// ─────────────────────────────────────────────────────────────
const HealthSummary = ({ overrides = {} }) => {
  const base = [
    { icon: 'network',         t: 'Network Extension',  s: 'active',     d: 'Filter loaded, allow-list active.' },
    { icon: 'app.dashed',      t: 'App Interruption',   s: 'active',     d: '4 apps will be paused on start.' },
    { icon: 'externaldrive',   t: 'Helper / Login Item',s: 'active',     d: 'Persists after Fermo quit. Reboot restore unverified.' },
    { icon: 'lock.shield',     t: 'System Extension',   s: 'active',     d: 'Loaded and approved.' },
    { icon: 'tray.full',       t: 'App Group state',    s: 'ready',      d: 'Shared state readable across helper.' },
  ];
  return (
    <Card title={<span>System Health <span style={{ color: 'var(--f-fg-3)', fontWeight: 500, marginLeft: 6 }}>· last checked 11s ago</span></span>}
      action={<button className="fermo-btn fermo-btn-ghost fermo-btn-sm"><FIcon name="arrow.clockwise" size={11}/> Recheck</button>}
    >
      {base.map((r, i) => {
        const o = overrides[r.t] || {};
        const state = o.s || r.s;
        const detail = o.d || r.d;
        const tone = STATE_TONE[state];
        const c = tone === 'ok' ? 'var(--f-ok)' : tone === 'info' ? 'var(--f-info)' : tone === 'warn' ? 'var(--f-warn)' : tone === 'danger' ? 'var(--f-danger)' : 'var(--f-fg-3)';
        return (
          <div key={r.t} style={{
            display: 'flex', alignItems: 'center', gap: 12,
            padding: '9px 16px',
            borderTop: i === 0 ? 'none' : '1px solid var(--f-line)',
          }}>
            <FIcon name={r.icon} size={14} style={{ color: 'var(--f-fg-2)' }}/>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontSize: 12.5, fontWeight: 500 }}>{r.t}</div>
              <div style={{ fontSize: 11.5, color: 'var(--f-fg-2)', marginTop: 1 }}>{detail}</div>
            </div>
            <FIcon name={STATE_ICON[state]} size={12} style={{ color: c }}/>
            <span style={{ fontSize: 11, fontWeight: 600, color: c, minWidth: 78, textAlign: 'right' }}>{STATE_LABEL[state]}</span>
          </div>
        );
      })}
    </Card>
  );
};

// ─────────────────────────────────────────────────────────────
// Recent evidence (4 rows)
// ─────────────────────────────────────────────────────────────
const RecentEvidence = () => (
  <Card title="Recent evidence" action={<button className="fermo-btn fermo-btn-ghost fermo-btn-sm">Open log <FIcon name="arrow.up.right" size={10}/></button>}>
    <EvidenceRow date="Apr 11" time="09:30" task="Triage support backlog"
      outcome="partial" duration="60:00" rigor="soft" room="Admin"
      proof="Closed 9 of 14 tickets. Stopped 22 min early." dense/>
    <EvidenceRow date="Apr 10" time="16:00" task="Finish migration runbook"
      outcome="broke-glass" duration="73:00" rigor="emergency" room="Coding"
      reason="On-call paged for SEV-2. Resumed after handoff." dense/>
    <EvidenceRow date="Apr 09" time="10:00" task="Draft brand language doc"
      outcome="completed" duration="90:00" rigor="locked" room="Deep Writing"
      proof="brand-voice-v3.md · 4 sections, 2 examples each" dense/>
    <EvidenceRow date="Apr 08" time="13:30" task="Inbox zero"
      outcome="completed" duration="45:00" rigor="soft" room="Admin"
      proof="0 unread · 12 archived · 3 deferred" dense/>
  </Card>
);

// ─────────────────────────────────────────────────────────────
// Suggested rooms (small sidebar widget)
// ─────────────────────────────────────────────────────────────
const SuggestedRooms = () => (
  <Card title="Rooms used this week">
    {[
      { name: 'Deep Writing', icon: 'square.and.pencil', count: '5 sessions', dur: '6h 12m', last: 'Apr 12' },
      { name: 'Coding',       icon: 'doc.text',          count: '3 sessions', dur: '4h 20m', last: 'Apr 10' },
      { name: 'Admin',        icon: 'tray',              count: '2 sessions', dur: '1h 40m', last: 'Apr 11' },
    ].map((r, i) => (
      <div key={r.name} style={{
        padding: '10px 16px', borderTop: i === 0 ? 'none' : '1px solid var(--f-line)',
        display: 'flex', alignItems: 'center', gap: 10,
      }}>
        <div style={{ width: 24, height: 24, borderRadius: 5, background: 'var(--f-bg-3)', border: '1px solid var(--f-line-2)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--f-fg-1)' }}>
          <FIcon name={r.icon} size={12}/>
        </div>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontSize: 12.5, fontWeight: 500 }}>{r.name}</div>
          <div style={{ fontSize: 11, color: 'var(--f-fg-3)', fontFamily: 'var(--f-font-mono)' }}>{r.count} · {r.dur}</div>
        </div>
        <span style={{ fontSize: 11, color: 'var(--f-fg-3)', fontFamily: 'var(--f-font-mono)' }}>{r.last}</span>
      </div>
    ))}
  </Card>
);

// ─────────────────────────────────────────────────────────────
// Quick presets row (compact, on Today)
// ─────────────────────────────────────────────────────────────
const QuickStartRow = () => (
  <Card title="Quick start" action={<button className="fermo-btn fermo-btn-ghost fermo-btn-sm"><FIcon name="plus" size={11}/> New preset</button>}>
    <div style={{ padding: 14, display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 10 }}>
      {[
        { name: 'Deep Writing', icon: 'square.and.pencil', dur: '90 min', rigor: 'locked', mode: 'room' },
        { name: 'Coding',       icon: 'doc.text',          dur: '120 min', rigor: 'locked', mode: 'room' },
        { name: 'Admin',        icon: 'tray',              dur: '45 min', rigor: 'soft', mode: 'block' },
        { name: 'Deep Planning',icon: 'target',            dur: '60 min', rigor: 'locked', mode: 'room' },
      ].map(p => (
        <div key={p.name} style={{
          padding: 12, border: '1px solid var(--f-line-2)', borderRadius: 8,
          background: 'var(--f-bg-1)', display: 'flex', flexDirection: 'column', gap: 8, cursor: 'pointer',
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <FIcon name={p.icon} size={13} style={{ color: 'var(--f-fg-1)' }}/>
            <span style={{ fontSize: 12.5, fontWeight: 600 }}>{p.name}</span>
          </div>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 5 }}>
            <Chip mono>{p.dur}</Chip>
            <Chip><FIcon name={RIGOR_DEFS[p.rigor].icon} size={9}/> {RIGOR_DEFS[p.rigor].name}</Chip>
          </div>
        </div>
      ))}
    </div>
  </Card>
);

// ─────────────────────────────────────────────────────────────
// Today screen body — variants
// ─────────────────────────────────────────────────────────────
const FermoToday = ({ variant = 'ready' }) => {
  // shared content config
  const next = {
    task: 'Draft Q3 reliability memo',
    outcome: 'A complete first draft. Sections 1–3 written end to end, with one supporting graph plotted for §2.',
    room: 'Deep Writing',
    duration: '90 min',
    rigor: 'locked',
    mode: 'room',
  };

  let strip, primaryBtn;
  if (variant === 'ready') {
    strip = <StatusStrip tone="ok" label="Ready" reason="System protection is healthy. Fermo can protect this session."/>;
    primaryBtn = (
      <button className="fermo-btn fermo-btn-primary fermo-btn-lg">
        <FIcon name="play.fill" size={11}/> Start Contract
      </button>
    );
  } else if (variant === 'protected') {
    strip = <StatusStrip tone="ok" label="Protected" reason="Locked session in progress. Stop is unavailable until 15:00."/>;
    primaryBtn = (
      <button className="fermo-btn fermo-btn-primary fermo-btn-lg">
        <FIcon name="eye" size={11}/> View Active Session
      </button>
    );
  } else if (variant === 'approval') {
    strip = <StatusStrip tone="info" label="Needs approval"
      reason="Network Extension is waiting for allow in System Settings. Sessions will run Soft only."
      action="Open System Settings"/>;
    primaryBtn = (
      <button className="fermo-btn fermo-btn-secondary fermo-btn-lg">
        <FIcon name="play.fill" size={11}/> Start anyway · Soft only
      </button>
    );
  } else if (variant === 'evidence-missing') {
    strip = <StatusStrip tone="warn" label="Needs evidence"
      reason="Last session ended at 14:48. Proof has not been recorded."
      action="Record proof"/>;
    primaryBtn = (
      <button className="fermo-btn fermo-btn-primary fermo-btn-lg">
        <FIcon name="square.and.pencil" size={11}/> Record Proof
      </button>
    );
  } else if (variant === 'degraded') {
    strip = <StatusStrip tone="warn" label="Degraded"
      reason="App interruption is partial: Firefox could not be paused. Bundle id check pending."
      action="Open System Health"/>;
    primaryBtn = (
      <button className="fermo-btn fermo-btn-secondary fermo-btn-lg">
        <FIcon name="play.fill" size={11}/> Start anyway
      </button>
    );
  }

  const overrides = variant === 'approval'
    ? { 'Network Extension': { s: 'approval', d: 'Awaiting allow in System Settings → Privacy & Security.' },
        'System Extension': { s: 'active', d: 'Loaded and approved.' } }
    : variant === 'degraded'
    ? { 'App Interruption': { s: 'degraded', d: 'Firefox could not be paused. Bundle id check pending.' } }
    : {};

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%', overflow: 'hidden' }}>
      {strip}
      <FermoSectionHead
        title="Today"
        subtitle="One protected contract at a time."
        right={
          <>
            <button className="fermo-btn fermo-btn-ghost fermo-btn-sm"><FIcon name="ellipsis" size={13}/></button>
            <button className="fermo-btn fermo-btn-secondary fermo-btn-sm"><FIcon name="plus" size={11}/> New contract</button>
          </>
        }
      />
      <div style={{ flex: 1, overflow: 'auto', padding: '20px 22px 26px', display: 'grid', gridTemplateColumns: '1.4fr 1fr', gap: 20, alignContent: 'start' }}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
          <NextContract {...next} primary={primaryBtn}/>
          <QuickStartRow/>
          <RecentEvidence/>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
          <HealthSummary overrides={overrides}/>
          <SuggestedRooms/>
          {/* Privacy/local data note */}
          <div style={{ padding: 14, border: '1px solid var(--f-line)', borderRadius: 10, background: 'var(--f-bg-2)', display: 'flex', gap: 10 }}>
            <FIcon name="hand.raised" size={14} style={{ color: 'var(--f-fg-2)', marginTop: 2 }}/>
            <div>
              <div style={{ fontSize: 12, fontWeight: 600 }}>Local data only</div>
              <div style={{ fontSize: 11.5, color: 'var(--f-fg-2)', marginTop: 3, lineHeight: 1.5 }}>
                Rooms, evidence and logs live on this Mac. No cloud sync in v1. No analytics. No AI dependency.
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

Object.assign(window, { FermoToday, StatusStrip, NextContract, HealthSummary, RecentEvidence, SuggestedRooms, QuickStartRow });
