// Fermo — Menu bar popover, 4 states
// Exposes: FermoMenuBar

// ─────────────────────────────────────────────────────────────
// Stage — wallpaper + macOS menu bar + popover dock
// ─────────────────────────────────────────────────────────────
const MBStage = ({ status = 'ok', children, sub }) => {
  const tone = status === 'ok' ? 'var(--f-ok)' : status === 'warn' ? 'var(--f-warn)' : status === 'info' ? 'var(--f-info)' : status === 'danger' ? 'var(--f-danger)' : 'var(--f-fg-2)';
  return (
    <div style={{
      width: '100%', height: '100%',
      background: 'radial-gradient(ellipse at 30% 18%, #1d2632, #0a0e15 55%, #060810)',
      position: 'relative', overflow: 'hidden',
      fontFamily: 'var(--f-font)',
    }} className="fermo">
      {/* macOS menu bar */}
      <div style={{
        position: 'absolute', top: 0, left: 0, right: 0, height: 26,
        background: 'rgba(10,14,20,0.72)',
        backdropFilter: 'blur(18px)',
        WebkitBackdropFilter: 'blur(18px)',
        borderBottom: '0.5px solid rgba(255,255,255,0.06)',
        display: 'flex', alignItems: 'center', padding: '0 14px', gap: 16,
        fontSize: 12, color: 'rgba(255,255,255,0.85)',
        zIndex: 2,
      }}>
        <span style={{ fontWeight: 700, fontSize: 14 }}></span>
        <span style={{ fontWeight: 600 }}>Notes</span>
        <span style={{ opacity: 0.8 }}>File</span>
        <span style={{ opacity: 0.8 }}>Edit</span>
        <span style={{ opacity: 0.8 }}>View</span>
        <span style={{ opacity: 0.8 }}>Window</span>
        <div style={{ flex: 1 }}/>
        {/* Fermo icon in menu bar — highlighted (clicked) */}
        <span style={{
          display: 'inline-flex', alignItems: 'center', gap: 5,
          padding: '2px 7px', borderRadius: 4,
          background: 'rgba(255,255,255,0.12)',
        }}>
          <FIcon name="fermo.mark" size={12} style={{ color: tone }}/>
        </span>
        <span style={{ opacity: 0.7, fontFamily: 'var(--f-font-mono)', fontSize: 11 }}>14:18</span>
      </div>

      {/* Notch indicator + popover */}
      <div style={{
        position: 'absolute', top: 30, right: 78,
        width: 12, height: 12, transform: 'rotate(45deg)',
        background: 'rgba(28,33,42,0.96)',
        border: '0.5px solid rgba(255,255,255,0.08)',
        borderBottom: 'none', borderRight: 'none',
        zIndex: 3,
      }}/>
      <div style={{
        position: 'absolute', top: 36, right: 22,
        zIndex: 3,
      }}>{children}</div>

      {/* Caption */}
      {sub && (
        <div style={{
          position: 'absolute', bottom: 16, left: 22,
          fontSize: 11, fontFamily: 'var(--f-font-mono)',
          color: 'var(--f-fg-3)', letterSpacing: 0.04, textTransform: 'uppercase',
        }}>{sub}</div>
      )}
    </div>
  );
};

const Popover = ({ children, w = 360 }) => (
  <div style={{
    width: w,
    background: 'rgba(28,33,42,0.96)',
    backdropFilter: 'blur(28px) saturate(140%)',
    WebkitBackdropFilter: 'blur(28px) saturate(140%)',
    border: '0.5px solid rgba(255,255,255,0.08)',
    borderRadius: 14,
    boxShadow: '0 24px 56px rgba(0,0,0,0.55), 0 8px 18px rgba(0,0,0,0.4)',
    overflow: 'hidden',
    color: 'var(--f-fg-0)',
    fontFamily: 'var(--f-font)',
    fontSize: 13,
  }}>{children}</div>
);

const PopHeader = ({ status, label, sub }) => {
  const tone = status === 'ok' ? 'var(--f-ok)' : status === 'warn' ? 'var(--f-warn)' : status === 'info' ? 'var(--f-info)' : status === 'danger' ? 'var(--f-danger)' : 'var(--f-fg-2)';
  return (
    <div style={{ padding: '12px 14px', display: 'flex', alignItems: 'center', gap: 10, borderBottom: '1px solid var(--f-line)' }}>
      <div style={{
        width: 28, height: 28, borderRadius: 7,
        background: 'linear-gradient(160deg, #1a2028, #0c1014)',
        border: '0.5px solid rgba(255,255,255,0.08)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        color: tone,
      }}>
        <FIcon name="fermo.mark" size={15}/>
      </div>
      <div style={{ minWidth: 0, flex: 1 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 7 }}>
          <span style={{ fontWeight: 600, fontSize: 13 }}>Fermo</span>
          <span style={{ width: 6, height: 6, borderRadius: '50%', background: tone }}/>
          <span style={{ fontSize: 10.5, fontWeight: 600, color: tone, letterSpacing: 0.04, textTransform: 'uppercase' }}>{label}</span>
        </div>
        <div style={{ fontSize: 11.5, color: 'var(--f-fg-2)', marginTop: 1, lineHeight: 1.35 }}>{sub}</div>
      </div>
      <button className="fermo-btn fermo-btn-ghost fermo-btn-sm" style={{ width: 22, padding: 0 }} title="Open window">
        <FIcon name="arrow.up.right" size={11}/>
      </button>
    </div>
  );
};

const PopSection = ({ label, action, children, style }) => (
  <div style={{ padding: '10px 10px 6px', ...style }}>
    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '0 4px', marginBottom: 4 }}>
      <span style={{ fontSize: 10, fontWeight: 600, color: 'var(--f-fg-3)', letterSpacing: 0.06, textTransform: 'uppercase' }}>{label}</span>
      {action && <span style={{ fontSize: 11, color: 'var(--f-fg-2)', cursor: 'pointer' }}>{action}</span>}
    </div>
    {children}
  </div>
);

const PopPreset = ({ icon, name, sub, kbd }) => (
  <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '6px 6px', borderRadius: 6 }}>
    <div style={{
      width: 24, height: 24, borderRadius: 5,
      background: 'var(--f-bg-3)', border: '1px solid var(--f-line-2)',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      color: 'var(--f-fg-1)',
    }}>
      <FIcon name={icon} size={12}/>
    </div>
    <div style={{ flex: 1, minWidth: 0 }}>
      <div style={{ fontSize: 12.5, fontWeight: 500 }}>{name}</div>
      <div style={{ fontSize: 11, color: 'var(--f-fg-3)' }}>{sub}</div>
    </div>
    {kbd && <Kbd>{kbd}</Kbd>}
  </div>
);

const PopFooter = ({ tone = 'ok', label = 'All checks green', clean = false }) => {
  const color = tone === 'ok' ? 'var(--f-ok)' : tone === 'warn' ? 'var(--f-warn)' : tone === 'danger' ? 'var(--f-danger)' : tone === 'info' ? 'var(--f-info)' : 'var(--f-fg-2)';
  return (
    <div style={{ padding: '8px 12px 8px 14px', display: 'flex', alignItems: 'center', justifyContent: 'space-between', borderTop: '1px solid var(--f-line)', background: 'rgba(0,0,0,0.18)' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 11.5 }}>
        <FIcon name="lock.shield" size={12} style={{ color }}/>
        <span style={{ color: 'var(--f-fg-2)' }}>System Health</span>
        <span style={{ color, fontWeight: 600 }}>· {label}</span>
      </div>
      <button className="fermo-btn fermo-btn-ghost fermo-btn-sm" style={{ fontSize: 11 }}>
        Open Fermo <FIcon name="arrow.up.right" size={10}/>
      </button>
    </div>
  );
};

// ─────────────────────────────────────────────────────────────
// State A — Idle (Ready)
// ─────────────────────────────────────────────────────────────
const PopIdle = () => (
  <Popover>
    <PopHeader status="ok" label="Ready" sub="No active session. System protection is healthy."/>
    <PopSection label="Quick start" action="New contract…">
      <PopPreset icon="square.and.pencil" name="Deep Writing" sub="90 min · Locked · Focus Room" kbd="⌘1"/>
      <PopPreset icon="doc.text" name="Coding · GitHub allowed" sub="120 min · Locked · Focus Room" kbd="⌘2"/>
      <PopPreset icon="tray" name="Admin sweep" sub="45 min · Soft · Blocklist" kbd="⌘3"/>
      <PopPreset icon="target" name="Deep Planning" sub="60 min · Locked · Focus Room" kbd="⌘4"/>
    </PopSection>
    <PopSection label="Last session · Apr 11, 09:30">
      <div style={{ display: 'flex', gap: 10, padding: '8px 10px', background: 'var(--f-bg-3)', borderRadius: 7, border: '1px solid var(--f-line-2)', alignItems: 'center' }}>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontSize: 12.5, fontWeight: 500 }}>Triage support backlog</div>
          <div style={{ fontSize: 11, color: 'var(--f-fg-3)', marginTop: 1 }}>60 min · Soft · proof recorded</div>
        </div>
        <FStatus tone="ok">Done</FStatus>
      </div>
    </PopSection>
    <div style={{ padding: '8px 10px 12px' }}>
      <button className="fermo-btn fermo-btn-primary fermo-btn-lg" style={{ width: '100%' }}>
        <FIcon name="play.fill" size={11}/> Start Deep Writing · 90 min
      </button>
    </div>
    <PopFooter tone="ok" label="All checks green"/>
  </Popover>
);

// ─────────────────────────────────────────────────────────────
// State B — Protected (active session, Locked)
// ─────────────────────────────────────────────────────────────
const PopProtected = () => (
  <Popover>
    <PopHeader status="ok" label="Protected" sub="Locked session. Stop is unavailable until 15:00."/>
    <div style={{ padding: '10px 12px 4px' }}>
      <div style={{
        background: 'oklch(0.74 0.09 168 / 0.06)',
        border: '1px solid oklch(0.74 0.09 168 / 0.28)',
        borderRadius: 8, padding: 12,
        display: 'flex', flexDirection: 'column', gap: 10,
      }}>
        <div>
          <div style={{ fontSize: 12.5, fontWeight: 600 }}>Draft Q3 reliability memo</div>
          <div style={{ fontSize: 11, color: 'var(--f-fg-2)', marginTop: 2, lineHeight: 1.4 }}>Sections 1–3 + one supporting graph.</div>
        </div>
        <div style={{ display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between' }}>
          <div className="fermo-tnum fermo-display" style={{ fontSize: 30, fontWeight: 600, lineHeight: 1, letterSpacing: 0 }}>00:42:18</div>
          <div style={{ fontSize: 10.5, color: 'var(--f-fg-3)', fontFamily: 'var(--f-font-mono)', textAlign: 'right', lineHeight: 1.4 }}>of 1:30:00<br/>ends 15:00</div>
        </div>
        <div style={{ height: 3, background: 'var(--f-bg-1)', borderRadius: 2, position: 'relative', overflow: 'hidden' }}>
          <div style={{ position: 'absolute', inset: '0 53% 0 0', background: 'var(--f-ok)' }}/>
        </div>
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 5 }}>
          <Chip><FIcon name="lock" size={10}/> Locked</Chip>
          <Chip><FIcon name="door.left.hand.closed" size={10}/> Deep Writing</Chip>
          <Chip mono>13 sites · 4 apps</Chip>
        </div>
      </div>
    </div>
    <PopSection label="Protected during this session">
      <div style={{ display: 'flex', flexDirection: 'column', gap: 4, fontSize: 11.5, color: 'var(--f-fg-1)', padding: '2px 6px 4px' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 7, minWidth: 0 }}>
          <FIcon name="globe" size={11} style={{ color: 'var(--f-fg-3)', flexShrink: 0 }}/>
          <span className="fermo-mono" style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>reddit.com · youtube.com · x.com · news.ycombinator.com</span>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 7 }}>
          <FIcon name="app.fill" size={11} style={{ color: 'var(--f-fg-3)' }}/>
          <span>Messages · Discord · Slack · Calculator</span>
        </div>
      </div>
    </PopSection>
    <div style={{ padding: '8px 10px 12px', display: 'flex', gap: 8 }}>
      <button className="fermo-btn fermo-btn-secondary" style={{ flex: 1 }} disabled>
        <FIcon name="stop.fill" size={10}/> Stop · unavailable
      </button>
      <button className="fermo-btn fermo-btn-secondary" style={{ flex: 1 }}>
        <FIcon name="square.and.pencil" size={11}/> Note
      </button>
    </div>
    <PopFooter tone="ok" label="3 protections active"/>
  </Popover>
);

// ─────────────────────────────────────────────────────────────
// State C — Needs Approval
// ─────────────────────────────────────────────────────────────
const PopApproval = () => (
  <Popover>
    <PopHeader status="info" label="Needs approval" sub="macOS needs to approve a system extension."/>
    <div style={{ padding: '10px 12px 4px' }}>
      <PermissionAlert
        tone="info" icon="info.circle"
        title="Network Extension waiting for approval"
        body="Open System Settings → Privacy & Security and allow the Fermo content filter. Sessions will run unprotected until then."
        primary="Open System Settings" secondary="Show me how"
      />
    </div>
    <PopSection label="Quick start · runs unprotected">
      <PopPreset icon="square.and.pencil" name="Deep Writing" sub="90 min · Soft only · proof note required"/>
      <PopPreset icon="tray" name="Admin sweep" sub="45 min · Soft only"/>
    </PopSection>
    <PopSection label="Affected checks">
      <div style={{ display: 'flex', flexDirection: 'column', padding: '0 4px' }}>
        {[
          ['network', 'Network Extension Content Filter', 'approval'],
          ['globe',   'Website Blocking',                'missing'],
        ].map(([icn, t, s]) => (
          <div key={t} style={{ display: 'flex', alignItems: 'center', gap: 7, padding: '5px 4px', fontSize: 11.5 }}>
            <FIcon name={icn} size={11} style={{ color: 'var(--f-fg-3)' }}/>
            <span style={{ flex: 1, color: 'var(--f-fg-1)' }}>{t}</span>
            <FStatus tone={STATE_TONE[s]} dot={false} style={{ height: 18, padding: '0 7px', fontSize: 10 }}>{STATE_LABEL[s]}</FStatus>
          </div>
        ))}
      </div>
    </PopSection>
    <PopFooter tone="info" label="1 check needs approval"/>
  </Popover>
);

// ─────────────────────────────────────────────────────────────
// State D — Degraded (active but partial)
// ─────────────────────────────────────────────────────────────
const PopDegraded = () => (
  <Popover>
    <PopHeader status="warn" label="Degraded" sub="Session is running. One protection is partial."/>
    <div style={{ padding: '10px 12px 4px' }}>
      <div style={{
        background: 'oklch(0.78 0.11 75 / 0.07)',
        border: '1px solid oklch(0.78 0.11 75 / 0.3)',
        borderRadius: 8, padding: 12,
        display: 'flex', flexDirection: 'column', gap: 10,
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 7 }}>
          <FIcon name="exclamationmark.triangle" size={13} style={{ color: 'var(--f-warn)' }}/>
          <span style={{ fontSize: 11.5, fontWeight: 600, color: 'var(--f-warn)' }}>App interruption: degraded</span>
        </div>
        <div>
          <div style={{ fontSize: 12.5, fontWeight: 600 }}>Refactor billing reconciler</div>
          <div style={{ fontSize: 11, color: 'var(--f-fg-2)', marginTop: 2 }}>Firefox could not be paused. Bundle id check pending.</div>
        </div>
        <div style={{ display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between' }}>
          <div className="fermo-tnum fermo-display" style={{ fontSize: 26, fontWeight: 600, lineHeight: 1 }}>01:12:04</div>
          <div style={{ fontSize: 10.5, color: 'var(--f-fg-3)', fontFamily: 'var(--f-font-mono)', textAlign: 'right' }}>Soft rigor<br/>Coding room</div>
        </div>
        <div style={{ display: 'flex', gap: 6 }}>
          <button className="fermo-btn fermo-btn-secondary fermo-btn-sm" style={{ flex: 1 }}>Recheck</button>
          <button className="fermo-btn fermo-btn-secondary fermo-btn-sm" style={{ flex: 1 }}>Quit Firefox</button>
        </div>
      </div>
    </div>
    <PopSection label="Last session">
      <div style={{ display: 'flex', gap: 10, padding: '8px 10px', background: 'var(--f-bg-3)', borderRadius: 7, border: '1px solid var(--f-line-2)', alignItems: 'center' }}>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontSize: 12.5, fontWeight: 500 }}>Draft Q3 reliability memo</div>
          <div style={{ fontSize: 11, color: 'var(--f-warn)', marginTop: 1 }}>Needs evidence — proof not recorded</div>
        </div>
        <button className="fermo-btn fermo-btn-secondary fermo-btn-sm">Record</button>
      </div>
    </PopSection>
    <div style={{ padding: '6px 10px 12px' }}>
      <button className="fermo-btn fermo-btn-secondary" style={{ width: '100%' }}>
        <FIcon name="stop.fill" size={10}/> Stop session
      </button>
    </div>
    <PopFooter tone="warn" label="1 check degraded"/>
  </Popover>
);

// ─────────────────────────────────────────────────────────────
// Showcase: 4 popovers laid out side by side
// ─────────────────────────────────────────────────────────────
const FermoMenuBar = ({ which = 'all' }) => {
  const screens = {
    idle:      { status: 'ok',     comp: <PopIdle/>,     sub: 'State A · Idle (Ready)' },
    protected: { status: 'ok',     comp: <PopProtected/>,sub: 'State B · Protected · Locked rigor' },
    approval:  { status: 'info',   comp: <PopApproval/>, sub: 'State C · Needs Approval' },
    degraded:  { status: 'warn',   comp: <PopDegraded/>, sub: 'State D · Degraded' },
  };
  if (which !== 'all') {
    const s = screens[which];
    return <MBStage status={s.status} sub={s.sub}>{s.comp}</MBStage>;
  }
  return null;
};

Object.assign(window, { FermoMenuBar, PopIdle, PopProtected, PopApproval, PopDegraded, MBStage });
