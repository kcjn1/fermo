// Fermo — composite components & shared sidebar
// Exposes (global): FermoSidebarNav, FermoBrandHeader, RigorPicker, ModePicker,
//   StatusRow, EvidenceRow, ProofCard, PermissionAlert, ActiveHeader,
//   AppIconArt, AppIconLockup, AllowBlockList, FermoSectionHead

// ─────────────────────────────────────────────────────────────
// Brand header inside sidebar (logo lockup, compact)
// ─────────────────────────────────────────────────────────────
const FermoBrandHeader = ({ status = 'ok', label = 'Protected' }) => {
  const toneColor = status === 'ok' ? 'var(--f-ok)' : status === 'warn' ? 'var(--f-warn)' : status === 'danger' ? 'var(--f-danger)' : 'var(--f-fg-2)';
  return (
    <div style={{ padding: '4px 9px 12px', display: 'flex', alignItems: 'center', gap: 9 }}>
      <div style={{
        width: 22, height: 22, borderRadius: 6,
        background: 'linear-gradient(160deg, #1a2028, #0c1014)',
        border: '0.5px solid rgba(255,255,255,0.08)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        color: 'var(--f-ok)',
        boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.03)',
      }}>
        <FIcon name="fermo.mark" size={13} stroke={1.6}/>
      </div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 0, minWidth: 0 }}>
        <span style={{ fontSize: 13, fontWeight: 600, letterSpacing: 0 }}>Fermo</span>
        <span style={{ fontSize: 10, fontWeight: 600, color: toneColor, letterSpacing: 0.04, textTransform: 'uppercase', display: 'flex', alignItems: 'center', gap: 4 }}>
          <span style={{ width: 5, height: 5, borderRadius: '50%', background: toneColor }}/>
          {label}
        </span>
      </div>
    </div>
  );
};

// ─────────────────────────────────────────────────────────────
// Full sidebar nav (used in most main-window screens)
// ─────────────────────────────────────────────────────────────
const FermoSidebarNav = ({ active = 'today', status = 'ok', statusLabel = 'Protected', healthBadge }) => (
  <FermoSidebar>
    <FermoBrandHeader status={status} label={statusLabel}/>

    <div className="fermo-section-label">Session</div>
    <FermoSidebarItem icon="house" label="Today" active={active === 'today'}/>
    <FermoSidebarItem icon="play.fill" label="Start Contract" active={active === 'start'} kbd="⌘N"/>

    <div className="fermo-section-label">Library</div>
    <FermoSidebarItem icon="square.grid.2x2" label="Rooms" active={active === 'rooms'} count={5}/>
    <FermoSidebarItem icon="list.bullet.clipboard" label="Evidence" active={active === 'evidence'} count={42}/>

    <div className="fermo-section-label">System</div>
    <FermoSidebarItem icon="lock.shield" label="System Health" active={active === 'health'} badge={healthBadge}/>
    <FermoSidebarItem icon="gearshape" label="Preferences" active={active === 'prefs'} kbd="⌘,"/>
  </FermoSidebar>
);

// ─────────────────────────────────────────────────────────────
// Screen title / section head pattern
// ─────────────────────────────────────────────────────────────
const FermoSectionHead = ({ title, subtitle, right, style }) => (
  <div style={{
    padding: '14px 22px 12px',
    display: 'flex', alignItems: 'center', justifyContent: 'space-between',
    borderBottom: '1px solid var(--f-line)',
    flexShrink: 0,
    ...style,
  }}>
    <div>
      <div style={{ fontSize: 17, fontWeight: 600, letterSpacing: 0 }}>{title}</div>
      {subtitle && <div style={{ fontSize: 12, color: 'var(--f-fg-2)', marginTop: 2 }}>{subtitle}</div>}
    </div>
    {right && <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>{right}</div>}
  </div>
);

// ─────────────────────────────────────────────────────────────
// Rigor picker — three options, with honest descriptions
// ─────────────────────────────────────────────────────────────
const RIGOR_DEFS = {
  soft:      { icon: 'lock.open',     name: 'Soft',      desc: 'Friction and reminder. You can stop the session at any time.' },
  locked:    { icon: 'lock',          name: 'Locked',    desc: 'No normal early exit during the session. Timer must elapse.' },
  emergency: { icon: 'exclamationmark.triangle', name: 'Emergency', desc: 'Break-glass exit only. Requires a recorded reason.' },
};
const RigorPicker = ({ value = 'locked', onChange, compact }) => (
  <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
    {Object.entries(RIGOR_DEFS).map(([k, d]) => {
      const on = value === k;
      return (
        <div
          key={k}
          onClick={() => onChange && onChange(k)}
          style={{
            display: 'flex', alignItems: 'flex-start', gap: 10,
            padding: compact ? '8px 10px' : '10px 12px',
            border: `1px solid ${on ? 'oklch(0.74 0.09 168 / 0.5)' : 'var(--f-line-2)'}`,
            background: on ? 'oklch(0.74 0.09 168 / 0.08)' : 'var(--f-bg-1)',
            borderRadius: 8,
            cursor: 'pointer',
          }}
        >
          <div style={{
            width: 16, height: 16, borderRadius: '50%',
            border: `1px solid ${on ? 'var(--f-ok)' : 'var(--f-line-3)'}`,
            background: on ? 'var(--f-ok)' : 'transparent',
            flexShrink: 0, marginTop: 1,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            {on && <div style={{ width: 6, height: 6, borderRadius: '50%', background: '#06120c' }}/>}
          </div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
              <FIcon name={d.icon} size={13} style={{ color: on ? 'var(--f-ok)' : 'var(--f-fg-2)' }}/>
              <span style={{ fontWeight: 600, fontSize: 13 }}>{d.name}</span>
            </div>
            <div style={{ fontSize: 11.5, color: 'var(--f-fg-2)', marginTop: 2, lineHeight: 1.4 }}>{d.desc}</div>
          </div>
        </div>
      );
    })}
  </div>
);

// ─────────────────────────────────────────────────────────────
// Mode picker — Blocklist vs Focus Room
// ─────────────────────────────────────────────────────────────
const ModePicker = ({ value = 'room', onChange }) => {
  const opts = [
    { v: 'room',  icon: 'door.left.hand.closed', name: 'Focus Room', desc: 'Allow only the tools that belong here.' },
    { v: 'block', icon: 'minus.circle',          name: 'Blocklist',  desc: 'Block selected distractions, leave the rest.' },
  ];
  return (
    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
      {opts.map(o => {
        const on = value === o.v;
        return (
          <div
            key={o.v}
            onClick={() => onChange && onChange(o.v)}
            style={{
              padding: '10px 12px',
              border: `1px solid ${on ? 'oklch(0.74 0.09 168 / 0.5)' : 'var(--f-line-2)'}`,
              background: on ? 'oklch(0.74 0.09 168 / 0.08)' : 'var(--f-bg-1)',
              borderRadius: 8,
              cursor: 'pointer',
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
              <FIcon name={o.icon} size={14} style={{ color: on ? 'var(--f-ok)' : 'var(--f-fg-1)' }}/>
              <span style={{ fontWeight: 600, fontSize: 13 }}>{o.name}</span>
            </div>
            <div style={{ fontSize: 11.5, color: 'var(--f-fg-2)', marginTop: 4 }}>{o.desc}</div>
          </div>
        );
      })}
    </div>
  );
};

// ─────────────────────────────────────────────────────────────
// Status row — used in System Health screen, permission summaries
// ─────────────────────────────────────────────────────────────
const STATE_TONE = {
  ready:    'ok',
  active:   'ok',
  approval: 'info',
  missing:  'warn',
  degraded: 'warn',
  unverified: 'warn',
  notinstalled: 'muted',
  error:    'danger',
};
const STATE_LABEL = {
  ready: 'Ready',
  active: 'Active',
  approval: 'Needs approval',
  missing: 'Missing permission',
  degraded: 'Degraded',
  unverified: 'Unverified',
  notinstalled: 'Not installed',
  error: 'Error',
};
const STATE_ICON = {
  ready: 'checkmark.circle',
  active: 'checkmark.circle',
  approval: 'info.circle',
  missing: 'exclamationmark.triangle',
  degraded: 'exclamationmark.triangle',
  unverified: 'questionmark.circle',
  notinstalled: 'minus.circle',
  error: 'xmark.circle',
};
const StatusRow = ({ icon, title, state = 'ready', detail, last = 'checked just now', action, dense }) => {
  const tone = STATE_TONE[state] || 'muted';
  const toneColor = tone === 'ok' ? 'var(--f-ok)' : tone === 'info' ? 'var(--f-info)' : tone === 'warn' ? 'var(--f-warn)' : tone === 'danger' ? 'var(--f-danger)' : 'var(--f-fg-3)';
  return (
    <div style={{
      display: 'flex', alignItems: 'center', gap: 12,
      padding: dense ? '10px 14px' : '14px 18px',
    }}>
      <div style={{
        width: 28, height: 28, borderRadius: 6,
        background: 'var(--f-bg-3)',
        border: '1px solid var(--f-line-2)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        color: 'var(--f-fg-1)',
        flexShrink: 0,
      }}>
        <FIcon name={icon} size={14}/>
      </div>
      <div style={{ minWidth: 0, flex: 1 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <span style={{ fontWeight: 600, fontSize: 13 }}>{title}</span>
          <FIcon name={STATE_ICON[state]} size={12} style={{ color: toneColor }}/>
          <span style={{ fontSize: 11, fontWeight: 600, color: toneColor, letterSpacing: 0.01 }}>{STATE_LABEL[state]}</span>
        </div>
        {detail && <div style={{ fontSize: 12, color: 'var(--f-fg-2)', marginTop: 2, lineHeight: 1.45 }}>{detail}</div>}
      </div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, flexShrink: 0 }}>
        <span style={{ fontSize: 11, color: 'var(--f-fg-3)', fontFamily: 'var(--f-font-mono)' }}>{last}</span>
        {action && (
          <button className={`fermo-btn ${action.tone === 'primary' ? 'fermo-btn-primary' : 'fermo-btn-secondary'} fermo-btn-sm`}>
            {action.label}
            {action.icon && <FIcon name={action.icon} size={11}/>}
          </button>
        )}
      </div>
    </div>
  );
};

// ─────────────────────────────────────────────────────────────
// Evidence row — for the evidence log
// ─────────────────────────────────────────────────────────────
const EvidenceRow = ({ date, time, task, outcome = 'completed', duration, rigor, room, proof, reason, dense }) => {
  const tone = outcome === 'completed' ? 'ok' : outcome === 'not-done' ? 'warn' : outcome === 'broke-glass' ? 'danger' : 'muted';
  const label = outcome === 'completed' ? 'Completed' : outcome === 'not-done' ? 'Not done' : outcome === 'partial' ? 'Partial' : outcome === 'broke-glass' ? 'Broke glass' : 'Open';
  return (
    <div style={{
      display: 'grid',
      gridTemplateColumns: '88px 1fr 88px 84px 116px 22px',
      gap: 12,
      alignItems: 'center',
      padding: dense ? '9px 18px' : '12px 18px',
      borderBottom: '1px solid var(--f-line)',
    }}>
      <div style={{ fontSize: 12, color: 'var(--f-fg-2)', fontFamily: 'var(--f-font-mono)' }}>
        <div>{date}</div>
        <div style={{ color: 'var(--f-fg-3)' }}>{time}</div>
      </div>
      <div style={{ minWidth: 0 }}>
        <div style={{ fontSize: 13, fontWeight: 500, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{task}</div>
        <div style={{ fontSize: 11.5, color: 'var(--f-fg-2)', marginTop: 1, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
          {reason ? <span style={{ color: 'var(--f-danger)' }}>{reason}</span> : (proof || '—')}
        </div>
      </div>
      <div style={{ fontSize: 12, color: 'var(--f-fg-1)', fontFamily: 'var(--f-font-mono)' }}>{duration}</div>
      <div style={{ fontSize: 11.5, color: 'var(--f-fg-1)', display: 'flex', alignItems: 'center', gap: 5 }}>
        <FIcon name={RIGOR_DEFS[rigor]?.icon || 'lock'} size={11} style={{ color: 'var(--f-fg-2)' }}/>
        {RIGOR_DEFS[rigor]?.name || rigor}
      </div>
      <div><FStatus tone={tone}>{label}</FStatus></div>
      <div style={{ color: 'var(--f-fg-3)', display: 'flex', justifyContent: 'flex-end' }}>
        <FIcon name="chevron.right" size={12}/>
      </div>
    </div>
  );
};

// ─────────────────────────────────────────────────────────────
// Permission alert — used in panes when something needs attention
// ─────────────────────────────────────────────────────────────
const PermissionAlert = ({ tone = 'warn', icon = 'exclamationmark.triangle', title, body, primary, secondary, style }) => {
  const toneColor = tone === 'ok' ? 'var(--f-ok)' : tone === 'info' ? 'var(--f-info)' : tone === 'danger' ? 'var(--f-danger)' : 'var(--f-warn)';
  const toneBg    = tone === 'ok' ? 'var(--f-ok-bg)' : tone === 'info' ? 'var(--f-info-bg)' : tone === 'danger' ? 'var(--f-danger-bg)' : 'var(--f-warn-bg)';
  const toneBd    = tone === 'ok' ? 'oklch(0.74 0.09 168 / 0.35)' : tone === 'info' ? 'oklch(0.72 0.10 232 / 0.35)' : tone === 'danger' ? 'oklch(0.66 0.16 25 / 0.4)' : 'oklch(0.78 0.11 75 / 0.35)';
  return (
    <div style={{
      display: 'flex', gap: 12,
      padding: '12px 14px',
      background: toneBg,
      border: `1px solid ${toneBd}`,
      borderRadius: 8,
      ...style,
    }}>
      <FIcon name={icon} size={16} style={{ color: toneColor, marginTop: 2, flexShrink: 0 }}/>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 13, fontWeight: 600, color: 'var(--f-fg-0)' }}>{title}</div>
        {body && <div style={{ fontSize: 12, color: 'var(--f-fg-1)', marginTop: 3, lineHeight: 1.45 }}>{body}</div>}
        {(primary || secondary) && (
          <div style={{ marginTop: 10, display: 'flex', gap: 8 }}>
            {primary && <button className="fermo-btn fermo-btn-primary fermo-btn-sm">{primary}</button>}
            {secondary && <button className="fermo-btn fermo-btn-secondary fermo-btn-sm">{secondary}</button>}
          </div>
        )}
      </div>
    </div>
  );
};

// ─────────────────────────────────────────────────────────────
// Active session header — used during running session
// ─────────────────────────────────────────────────────────────
const ActiveHeader = ({ task, outcome, remaining = '00:42:18', total = '90 min', rigor = 'locked', room = 'Deep Writing', mode = 'room', protectedCount }) => (
  <div style={{
    padding: '20px 24px 18px',
    background: 'linear-gradient(180deg, oklch(0.74 0.09 168 / 0.08), transparent)',
    borderBottom: '1px solid var(--f-line)',
  }}>
    <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
      <FStatus tone="ok">PROTECTED</FStatus>
      <span style={{ fontSize: 11.5, color: 'var(--f-fg-2)' }}>This session is protected. Stop is unavailable until the timer ends.</span>
    </div>
    <div style={{ marginTop: 14, display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between', gap: 24 }}>
      <div style={{ minWidth: 0, flex: 1 }}>
        <div style={{ fontSize: 19, fontWeight: 600, letterSpacing: 0 }}>{task}</div>
        <div style={{ fontSize: 12.5, color: 'var(--f-fg-2)', marginTop: 4 }}>{outcome}</div>
      </div>
      <div style={{ textAlign: 'right' }}>
        <div className="fermo-tnum" style={{ fontSize: 38, fontWeight: 600, letterSpacing: 0, lineHeight: 1, fontFamily: 'var(--f-font-display)' }}>{remaining}</div>
        <div style={{ fontSize: 11, color: 'var(--f-fg-3)', marginTop: 4, fontFamily: 'var(--f-font-mono)' }}>of {total} · ends 15:00</div>
      </div>
    </div>
    <div style={{ marginTop: 14, display: 'flex', gap: 14, alignItems: 'center', flexWrap: 'wrap' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 12 }}>
        <FIcon name={RIGOR_DEFS[rigor].icon} size={12} style={{ color: 'var(--f-fg-2)' }}/>
        <span style={{ color: 'var(--f-fg-2)' }}>Rigor</span>
        <span style={{ color: 'var(--f-fg-0)', fontWeight: 500 }}>{RIGOR_DEFS[rigor].name}</span>
      </div>
      <div style={{ width: 1, height: 12, background: 'var(--f-line-2)' }}/>
      <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 12 }}>
        <FIcon name={mode === 'room' ? 'door.left.hand.closed' : 'minus.circle'} size={12} style={{ color: 'var(--f-fg-2)' }}/>
        <span style={{ color: 'var(--f-fg-2)' }}>Mode</span>
        <span style={{ color: 'var(--f-fg-0)', fontWeight: 500 }}>{mode === 'room' ? 'Focus Room' : 'Blocklist'}</span>
      </div>
      <div style={{ width: 1, height: 12, background: 'var(--f-line-2)' }}/>
      <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 12 }}>
        <FIcon name="square.grid.2x2" size={12} style={{ color: 'var(--f-fg-2)' }}/>
        <span style={{ color: 'var(--f-fg-2)' }}>Room</span>
        <span style={{ color: 'var(--f-fg-0)', fontWeight: 500 }}>{room}</span>
      </div>
      {protectedCount && <>
        <div style={{ width: 1, height: 12, background: 'var(--f-line-2)' }}/>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 12 }}>
          <FIcon name="shield" size={12} style={{ color: 'var(--f-ok)' }}/>
          <span style={{ color: 'var(--f-fg-2)' }}>Protecting</span>
          <span className="fermo-mono" style={{ color: 'var(--f-fg-0)', fontWeight: 500 }}>{protectedCount}</span>
        </div>
      </>}
    </div>
  </div>
);

// ─────────────────────────────────────────────────────────────
// Allow/Block list — used in Room Builder + Blocklist Editor
// ─────────────────────────────────────────────────────────────
const AllowBlockList = ({ kind = 'allow', items = [], emptyText, locked }) => {
  const tone = kind === 'allow' ? 'ok' : 'danger';
  const accent = tone === 'ok' ? 'var(--f-ok)' : 'var(--f-danger)';
  return (
    <div style={{ display: 'flex', flexDirection: 'column' }}>
      {items.length === 0 && (
        <div style={{ padding: '24px 18px', textAlign: 'center', color: 'var(--f-fg-3)', fontSize: 12.5, border: '1px dashed var(--f-line-2)', borderRadius: 8 }}>
          {emptyText || (kind === 'allow' ? 'No allowed items yet.' : 'No blocked items yet.')}
        </div>
      )}
      {items.map((it, i) => (
        <div key={i} style={{
          display: 'flex', alignItems: 'center', gap: 10,
          padding: '8px 10px',
          borderBottom: i === items.length - 1 ? 'none' : '1px solid var(--f-line)',
        }}>
          <FIcon name={it.kind === 'app' ? 'app.fill' : 'globe'} size={13} style={{ color: 'var(--f-fg-2)' }}/>
          <span style={{ fontSize: 13, fontFamily: it.kind === 'site' ? 'var(--f-font-mono)' : 'var(--f-font)', color: 'var(--f-fg-0)' }}>{it.name}</span>
          {it.note && <span style={{ fontSize: 11, color: 'var(--f-fg-3)', fontFamily: 'var(--f-font-mono)' }}>{it.note}</span>}
          {it.invalid && <FStatus tone="danger" style={{ marginLeft: 4 }}>invalid</FStatus>}
          <div style={{ marginLeft: 'auto', display: 'flex', alignItems: 'center', gap: 6 }}>
            {it.disabled && <Chip>disabled</Chip>}
            <span style={{
              width: 24, height: 13, borderRadius: 7,
              background: it.disabled ? 'var(--f-bg-4)' : accent,
              position: 'relative', flexShrink: 0,
            }}>
              <span style={{
                position: 'absolute', top: 1, left: it.disabled ? 1 : 12,
                width: 11, height: 11, borderRadius: '50%',
                background: '#0a0d12',
              }}/>
            </span>
            {!locked && (
              <button className="fermo-btn fermo-btn-ghost fermo-btn-sm" style={{ padding: '0 4px', minWidth: 20 }}>
                <FIcon name="ellipsis" size={13}/>
              </button>
            )}
          </div>
        </div>
      ))}
    </div>
  );
};

// ─────────────────────────────────────────────────────────────
// App icon artwork — protected-room metaphor
// Door outline + lock seal + brand accent
// ─────────────────────────────────────────────────────────────
const AppIconArt = ({ size = 128, radius = 0.2237 }) => {
  const r = size * radius;
  const accent = 'oklch(0.78 0.10 172)';
  return (
    <svg width={size} height={size} viewBox="0 0 128 128" style={{ display: 'block', borderRadius: r }}>
      <defs>
        <linearGradient id={`fbg${size}`} x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor="#1c232c"/>
          <stop offset="1" stopColor="#0a0d12"/>
        </linearGradient>
        <linearGradient id={`fring${size}`} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="rgba(255,255,255,0.18)"/>
          <stop offset="1" stopColor="rgba(255,255,255,0)"/>
        </linearGradient>
        <linearGradient id={`facc${size}`} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="oklch(0.84 0.10 172)"/>
          <stop offset="1" stopColor="oklch(0.68 0.10 172)"/>
        </linearGradient>
      </defs>
      {/* squircle background */}
      <rect x="0" y="0" width="128" height="128" rx={128 * radius} fill={`url(#fbg${size})`}/>
      {/* inset highlight */}
      <rect x="0.5" y="0.5" width="127" height="127" rx={128 * radius - 0.5} fill="none" stroke={`url(#fring${size})`} strokeWidth="1"/>
      {/* door outline */}
      <rect x="34" y="22" width="60" height="84" rx="6" fill="none" stroke="#3a4250" strokeWidth="2.4"/>
      {/* inner door panel */}
      <rect x="40" y="28" width="48" height="60" rx="3" fill="none" stroke="#2a313c" strokeWidth="1.5"/>
      {/* handle */}
      <circle cx="84" cy="68" r="2.2" fill="#525a66"/>
      {/* seal — placed on door */}
      <circle cx="64" cy="68" r="20" fill="#0d1218" stroke={accent} strokeWidth="2.6"/>
      <circle cx="64" cy="68" r="14" fill="none" stroke="oklch(0.78 0.10 172 / 0.4)" strokeWidth="0.8" strokeDasharray="2 3"/>
      {/* checkmark inside seal */}
      <path d="M55 68 L62 75 L73 62" fill="none" stroke={`url(#facc${size})`} strokeWidth="3.2" strokeLinecap="round" strokeLinejoin="round"/>
      {/* threshold line */}
      <rect x="30" y="106" width="68" height="3" rx="1" fill="#1f242c"/>
    </svg>
  );
};

const AppIconLockup = ({ size = 128, label = 'Fermo', sub }) => (
  <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 12 }}>
    <AppIconArt size={size}/>
    {label && <div style={{ fontSize: 12, color: 'var(--f-fg-1)', fontWeight: 500 }}>{label}</div>}
    {sub && <div style={{ fontSize: 11, color: 'var(--f-fg-3)', fontFamily: 'var(--f-font-mono)' }}>{sub}</div>}
  </div>
);

// ─────────────────────────────────────────────────────────────
// Proof card — used post-session
// ─────────────────────────────────────────────────────────────
const ProofCard = ({ outcome = 'completed', note, link, file, ts = '14:48 today' }) => {
  const tone = outcome === 'completed' ? 'ok' : outcome === 'not-done' ? 'warn' : 'muted';
  const label = outcome === 'completed' ? 'Completed' : outcome === 'not-done' ? 'Not done' : outcome === 'partial' ? 'Partial' : 'Open';
  return (
    <div className="fermo-card" style={{ padding: 14, display: 'flex', flexDirection: 'column', gap: 10 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
        <FStatus tone={tone}>{label}</FStatus>
        <span style={{ fontSize: 11, color: 'var(--f-fg-3)', fontFamily: 'var(--f-font-mono)' }}>{ts}</span>
      </div>
      {note && (
        <div style={{ fontSize: 13, color: 'var(--f-fg-0)', lineHeight: 1.5 }}>
          {note}
        </div>
      )}
      {(link || file) && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
          {link && <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 12 }}>
            <FIcon name="arrow.up.right" size={12} style={{ color: 'var(--f-fg-2)' }}/>
            <span className="fermo-mono" style={{ color: 'var(--f-ok)' }}>{link}</span>
          </div>}
          {file && <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 12 }}>
            <FIcon name="doc" size={12} style={{ color: 'var(--f-fg-2)' }}/>
            <span className="fermo-mono" style={{ color: 'var(--f-fg-1)' }}>{file}</span>
          </div>}
        </div>
      )}
    </div>
  );
};

Object.assign(window, {
  FermoBrandHeader, FermoSidebarNav, FermoSectionHead,
  RIGOR_DEFS, RigorPicker, ModePicker,
  STATE_TONE, STATE_LABEL, STATE_ICON,
  StatusRow, EvidenceRow, PermissionAlert, ActiveHeader,
  AllowBlockList, AppIconArt, AppIconLockup, ProofCard,
});
