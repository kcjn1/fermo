// Fermo — SF Symbols-style icons, status atoms, window chrome.
// Exports (global): FIcon, FStatus, FermoWindow, FermoSidebar, FermoSidebarItem,
//                   FermoTrafficLights, FermoTitlebar, Kbd, Chip, Seg

// ─────────────────────────────────────────────────────────────
// FIcon — SF Symbols-style line icons (1.6px strokes, 24-grid)
// Tuned to read calm and native at 14–22px display sizes.
// ─────────────────────────────────────────────────────────────
const FIcon = ({ name, size = 16, stroke = 1.5, style, fill }) => {
  const common = {
    width: size, height: size, viewBox: '0 0 24 24',
    fill: fill || 'none', stroke: 'currentColor',
    strokeWidth: stroke, strokeLinecap: 'round', strokeLinejoin: 'round',
    style: { flexShrink: 0, ...style },
  };
  switch (name) {
    // Brand / app metaphors
    case 'lock.shield': return <svg {...common}>
      <path d="M12 3 4 6v6c0 4.5 3.4 8.5 8 9 4.6-.5 8-4.5 8-9V6Z"/>
      <rect x="9" y="11" width="6" height="5" rx="1"/>
      <path d="M10.5 11V9.5a1.5 1.5 0 0 1 3 0V11"/>
    </svg>;
    case 'door.left.hand.closed': return <svg {...common}>
      <path d="M4 21h16"/>
      <path d="M6 21V5a2 2 0 0 1 2-2h8a2 2 0 0 1 2 2v16"/>
      <circle cx="14" cy="13" r="0.6" fill="currentColor"/>
    </svg>;
    case 'checkmark.seal': return <svg {...common}>
      <path d="M12 3l2 1.6 2.5-.3.6 2.4 2.2 1.3-.6 2.4L20 12l-1.3 2.2-.6 2.4-2.5-.3L13.5 18 12 16.4 10.5 18l-1.6-1.3-2.5.3-.6-2.4L4.7 13 4 12l.7-2.6L4 7l1.6-1.3.6-2.4 2.5.3Z"/>
      <path d="m9 12 2.2 2L15 10"/>
    </svg>;
    case 'shield': return <svg {...common}><path d="M12 3 4 6v6c0 4.5 3.4 8.5 8 9 4.6-.5 8-4.5 8-9V6Z"/></svg>;
    case 'lock': return <svg {...common}><rect x="5" y="11" width="14" height="9" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/></svg>;
    case 'lock.open': return <svg {...common}><rect x="5" y="11" width="14" height="9" rx="2"/><path d="M8 11V8a4 4 0 0 1 7.5-2"/></svg>;
    case 'target': return <svg {...common}><circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="5"/><circle cx="12" cy="12" r="1.5" fill="currentColor"/></svg>;
    case 'doc.text': return <svg {...common}><path d="M14 3H7a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V8Z"/><path d="M14 3v5h5"/><path d="M9 13h6M9 16h4"/></svg>;
    case 'doc': return <svg {...common}><path d="M14 3H7a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V8Z"/><path d="M14 3v5h5"/></svg>;
    case 'list.bullet.clipboard': return <svg {...common}><rect x="5" y="4" width="14" height="17" rx="2"/><rect x="9" y="2" width="6" height="3" rx="1"/><path d="M9 10h7M9 14h7M9 18h5"/></svg>;
    case 'square.and.pencil': return <svg {...common}><path d="M4 20h4l11-11-4-4L4 16Z"/><path d="m13 6 4 4"/></svg>;
    case 'copy': return <svg {...common}><rect x="8" y="8" width="12" height="12" rx="2"/><rect x="4" y="4" width="12" height="12" rx="2"/></svg>;
    case 'download': return <svg {...common}><path d="M12 4v11"/><path d="m8 11 4 4 4-4"/><path d="M5 20h14"/></svg>;
    case 'trash': return <svg {...common}><path d="M4 7h16"/><path d="M10 11v6M14 11v6"/><path d="M6 7l1 14h10l1-14"/><path d="M9 7V4h6v3"/></svg>;

    // Time
    case 'clock': return <svg {...common}><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg>;
    case 'hourglass': return <svg {...common}><path d="M7 3h10M7 21h10M8 3v3c0 2 2 3 4 6 2-3 4-4 4-6V3M8 21v-3c0-2 2-3 4-6 2 3 4 4 4 6v3"/></svg>;
    case 'timer': return <svg {...common}><circle cx="12" cy="13" r="8"/><path d="M9 2h6M12 13l3-3M12 5v1"/></svg>;

    // Nav / chrome
    case 'house': return <svg {...common}><path d="M3 11 12 4l9 7v9a1 1 0 0 1-1 1h-5v-7H10v7H5a1 1 0 0 1-1-1Z"/></svg>;
    case 'sidebar.left': return <svg {...common}><rect x="3" y="5" width="18" height="14" rx="2"/><path d="M9 5v14"/></svg>;
    case 'magnifyingglass': return <svg {...common}><circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/></svg>;
    case 'gearshape': return <svg {...common}><circle cx="12" cy="12" r="3"/><path d="M12 3v2M12 19v2M5.6 5.6l1.4 1.4M17 17l1.4 1.4M3 12h2M19 12h2M5.6 18.4 7 17M17 7l1.4-1.4"/></svg>;
    case 'plus': return <svg {...common}><path d="M12 5v14M5 12h14"/></svg>;
    case 'minus': return <svg {...common}><path d="M5 12h14"/></svg>;
    case 'xmark': return <svg {...common}><path d="m6 6 12 12M18 6 6 18"/></svg>;
    case 'xmark.circle': return <svg {...common}><circle cx="12" cy="12" r="9"/><path d="m9 9 6 6M15 9l-6 6"/></svg>;
    case 'chevron.right': return <svg {...common}><path d="m9 6 6 6-6 6"/></svg>;
    case 'chevron.down': return <svg {...common}><path d="m6 9 6 6 6-6"/></svg>;
    case 'chevron.updown': return <svg {...common}><path d="m8 10 4-4 4 4M8 14l4 4 4-4"/></svg>;
    case 'arrow.up.right': return <svg {...common}><path d="M7 17 17 7M9 7h8v8"/></svg>;
    case 'arrow.right': return <svg {...common}><path d="M5 12h14M13 6l6 6-6 6"/></svg>;
    case 'arrow.clockwise': return <svg {...common}><path d="M20 12a8 8 0 1 1-2.3-5.6L20 9"/><path d="M20 4v5h-5"/></svg>;
    case 'ellipsis': return <svg {...common}><circle cx="6" cy="12" r="1.2" fill="currentColor"/><circle cx="12" cy="12" r="1.2" fill="currentColor"/><circle cx="18" cy="12" r="1.2" fill="currentColor"/></svg>;
    case 'ellipsis.circle': return <svg {...common}><circle cx="12" cy="12" r="9"/><circle cx="8" cy="12" r="1" fill="currentColor"/><circle cx="12" cy="12" r="1" fill="currentColor"/><circle cx="16" cy="12" r="1" fill="currentColor"/></svg>;

    // State / signal
    case 'checkmark': return <svg {...common}><path d="m5 12 5 5 9-11"/></svg>;
    case 'checkmark.circle': return <svg {...common}><circle cx="12" cy="12" r="9"/><path d="m8 12 3 3 5-6"/></svg>;
    case 'checkmark.circle.fill': return <svg {...common} fill="currentColor"><circle cx="12" cy="12" r="9"/><path d="m8 12 3 3 5-6" stroke="#06120c" strokeWidth="1.8" fill="none"/></svg>;
    case 'exclamationmark.triangle': return <svg {...common}><path d="m12 4 9 16H3Z"/><path d="M12 10v4M12 17v.5"/></svg>;
    case 'exclamationmark.circle': return <svg {...common}><circle cx="12" cy="12" r="9"/><path d="M12 7v6M12 16v.5"/></svg>;
    case 'info.circle': return <svg {...common}><circle cx="12" cy="12" r="9"/><path d="M12 11v5M12 8v.5"/></svg>;
    case 'questionmark.circle': return <svg {...common}><circle cx="12" cy="12" r="9"/><path d="M9.5 10a2.5 2.5 0 0 1 5 0c0 2-2.5 2-2.5 3.5M12 17v.5"/></svg>;
    case 'minus.circle': return <svg {...common}><circle cx="12" cy="12" r="9"/><path d="M8 12h8"/></svg>;

    // System / hardware metaphors
    case 'network': return <svg {...common}><circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3a14 14 0 0 1 0 18M12 3a14 14 0 0 0 0 18"/></svg>;
    case 'app.dashed': return <svg {...common}><path d="M5 5h2M9 5h2M13 5h2M17 5h2v2M19 9v2M19 13v2M19 17v2h-2M15 19h-2M11 19H9M7 19H5v-2M5 15v-2M5 11V9M5 7V5"/></svg>;
    case 'app.badge': return <svg {...common}><rect x="3" y="3" width="14" height="14" rx="3"/><circle cx="18" cy="6" r="3" fill="currentColor" stroke="none"/></svg>;
    case 'app.fill': return <svg {...common} fill="currentColor"><rect x="3" y="3" width="18" height="18" rx="4" stroke="none"/></svg>;
    case 'externaldrive': return <svg {...common}><rect x="3" y="13" width="18" height="7" rx="1.5"/><path d="M3 13l3-7h12l3 7M7 17h.5"/></svg>;
    case 'externaldrive.badge.checkmark': return <svg {...common}><rect x="3" y="13" width="18" height="7" rx="1.5"/><path d="M3 13l3-7h12l3 7M7 17h.5"/><circle cx="19" cy="20" r="3" fill="var(--f-bg-1)"/><path d="m17.5 20 1 1 2-2"/></svg>;
    case 'wifi': return <svg {...common}><path d="M2 9a16 16 0 0 1 20 0M5 12.5a12 12 0 0 1 14 0M8 16a8 8 0 0 1 8 0"/><circle cx="12" cy="19.5" r="0.8" fill="currentColor"/></svg>;
    case 'antenna': return <svg {...common}><path d="M5 4a10 10 0 0 0 0 14M19 4a10 10 0 0 1 0 14M8 7a6 6 0 0 0 0 8M16 7a6 6 0 0 1 0 8"/><circle cx="12" cy="11" r="1.5" fill="currentColor"/><path d="M12 13v8"/></svg>;
    case 'bolt': return <svg {...common}><path d="m13 2-9 12h7l-1 8 9-12h-7Z"/></svg>;
    case 'power': return <svg {...common}><path d="M12 4v8"/><path d="M6.3 7.7a8 8 0 1 0 11.4 0"/></svg>;

    // Sidebar / menu
    case 'tray': return <svg {...common}><path d="M3 14v4a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-4M3 14h6l1 2h4l1-2h6M3 14l3-9h12l3 9"/></svg>;
    case 'tray.full': return <svg {...common}><path d="M3 14v4a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-4M3 14h6l1 2h4l1-2h6M3 14l3-9h12l3 9"/><path d="M9 8h6"/></svg>;
    case 'play.fill': return <svg {...common} fill="currentColor"><path d="M7 4v16l13-8Z"/></svg>;
    case 'pause.fill': return <svg {...common} fill="currentColor"><rect x="6" y="5" width="4" height="14" rx="1"/><rect x="14" y="5" width="4" height="14" rx="1"/></svg>;
    case 'stop.fill': return <svg {...common} fill="currentColor"><rect x="5" y="5" width="14" height="14" rx="2"/></svg>;
    case 'forward.end.fill': return <svg {...common} fill="currentColor"><path d="M5 5v14l9-7Z"/><rect x="16" y="5" width="2" height="14" rx="0.5"/></svg>;

    // Eye / privacy
    case 'eye.slash': return <svg {...common}><path d="M3 3l18 18M9.5 5.4A11 11 0 0 1 12 5c6 0 10 7 10 7a16 16 0 0 1-3 4M6 8a16 16 0 0 0-4 4s4 7 10 7c2 0 3.6-.5 5-1.2"/><circle cx="12" cy="12" r="2.5"/></svg>;
    case 'eye': return <svg {...common}><path d="M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12Z"/><circle cx="12" cy="12" r="3"/></svg>;
    case 'hand.raised': return <svg {...common}><path d="M9 13V4.5a1.5 1.5 0 1 1 3 0V11M12 11V3.5a1.5 1.5 0 1 1 3 0V12M15 12V5.5a1.5 1.5 0 1 1 3 0V14a8 8 0 0 1-8 8h-1a8 8 0 0 1-7-7l-1-4.5a1.5 1.5 0 1 1 2.6-1.4L6 13"/></svg>;

    // Tools
    case 'paperplane': return <svg {...common}><path d="M3 11 21 3l-8 18-2-8Z"/><path d="m11 13 10-10"/></svg>;
    case 'tag': return <svg {...common}><path d="M3 12V4h8l10 10-8 8z"/><circle cx="8" cy="9" r="1.5"/></svg>;
    case 'flag': return <svg {...common}><path d="M5 21V4h12l-3 4 3 4H5"/></svg>;
    case 'pin': return <svg {...common}><path d="M9 4h6l-1 5 4 4-3 1-3 7-3-7-3-1 4-4Z"/></svg>;
    case 'square.grid.2x2': return <svg {...common}><rect x="4" y="4" width="7" height="7" rx="1.5"/><rect x="13" y="4" width="7" height="7" rx="1.5"/><rect x="4" y="13" width="7" height="7" rx="1.5"/><rect x="13" y="13" width="7" height="7" rx="1.5"/></svg>;
    case 'switch.2': return <svg {...common}><rect x="3" y="6" width="18" height="6" rx="3"/><circle cx="17" cy="9" r="2" fill="currentColor"/><rect x="3" y="14" width="18" height="6" rx="3"/><circle cx="7" cy="17" r="2" fill="currentColor"/></svg>;
    case 'slider': return <svg {...common}><path d="M4 7h7M16 7h4M4 17h2M11 17h9"/><circle cx="13" cy="7" r="2" fill="var(--f-bg-1)"/><circle cx="8" cy="17" r="2" fill="var(--f-bg-1)"/></svg>;
    case 'globe': return <svg {...common}><circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3a14 14 0 0 1 0 18M12 3a14 14 0 0 0 0 18"/></svg>;

    // Brand symbol — Fermo door+seal mark
    case 'fermo.mark': return <svg {...common}>
      <rect x="5" y="3" width="14" height="18" rx="2"/>
      <path d="M9 12h6"/>
      <circle cx="12" cy="12" r="2.4"/>
    </svg>;

    default: return null;
  }
};

// ─────────────────────────────────────────────────────────────
// Status pill
// ─────────────────────────────────────────────────────────────
const FStatus = ({ tone = 'ok', children, dot = true, style }) => (
  <span className={`fermo-status fermo-status-${tone}`} style={style}>
    {dot && <span className="dot solid"/>}
    <span>{children}</span>
  </span>
);

// ─────────────────────────────────────────────────────────────
// Chip / Kbd / Seg
// ─────────────────────────────────────────────────────────────
const Chip = ({ children, mono, tone, style }) => (
  <span
    className={`fermo-chip ${mono ? 'fermo-chip-mono' : ''}`}
    style={{
      ...(tone === 'ok' ? { background: 'var(--f-ok-bg)', color: 'var(--f-ok)', borderColor: 'oklch(0.74 0.09 168 / 0.3)' } : {}),
      ...(tone === 'warn' ? { background: 'var(--f-warn-bg)', color: 'var(--f-warn)', borderColor: 'oklch(0.78 0.11 75 / 0.3)' } : {}),
      ...(tone === 'danger' ? { background: 'var(--f-danger-bg)', color: 'var(--f-danger)', borderColor: 'oklch(0.66 0.16 25 / 0.3)' } : {}),
      ...style,
    }}
  >{children}</span>
);

const Kbd = ({ children, style }) => (
  <span className="fermo-kbd" style={style}>{children}</span>
);

const Seg = ({ options, value, onChange, style }) => (
  <div className="fermo-seg" style={style}>
    {options.map(o => (
      <button
        key={o.value}
        className={value === o.value ? 'is-on' : ''}
        onClick={() => onChange && onChange(o.value)}
      >{o.label}</button>
    ))}
  </div>
);

// ─────────────────────────────────────────────────────────────
// Window chrome — dark macOS, compact, sidebar + content
// ─────────────────────────────────────────────────────────────
const FermoTrafficLights = ({ inactive = false }) => {
  const dot = (bg) => (
    <div style={{
      width: 12, height: 12, borderRadius: '50%',
      background: inactive ? '#3a3f47' : bg,
      boxShadow: inactive ? 'inset 0 0 0 0.5px rgba(255,255,255,0.06)' : 'inset 0 0 0 0.5px rgba(0,0,0,0.25)',
    }}/>
  );
  return (
    <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
      {dot('#ff5f57')}{dot('#febc2e')}{dot('#28c840')}
    </div>
  );
};

// Titlebar — slim, dark, with traffic lights + title + optional right slot
const FermoTitlebar = ({ title = 'Fermo', subtitle, right }) => (
  <div style={{
    height: 38, flexShrink: 0,
    background: 'linear-gradient(180deg, #181c23, #131720)',
    borderBottom: '1px solid var(--f-line)',
    display: 'flex', alignItems: 'center', padding: '0 14px',
    position: 'relative',
  }}>
    <FermoTrafficLights/>
    <div style={{
      position: 'absolute', left: 0, right: 0, textAlign: 'center',
      fontSize: 12.5, fontWeight: 500, color: 'var(--f-fg-1)',
      letterSpacing: 0, pointerEvents: 'none',
    }}>
      <span style={{ color: 'var(--f-fg-0)' }}>{title}</span>
      {subtitle && <span style={{ color: 'var(--f-fg-3)', marginLeft: 8 }}>· {subtitle}</span>}
    </div>
    <div style={{ marginLeft: 'auto', display: 'flex', alignItems: 'center', gap: 6 }}>
      {right}
    </div>
  </div>
);

// Sidebar — vertical, slim, native macOS dark style
const FermoSidebar = ({ children, footer, width = 200 }) => (
  <div style={{
    width, flexShrink: 0,
    background: 'linear-gradient(180deg, #15191f, #11141a)',
    borderRight: '1px solid var(--f-line)',
    display: 'flex', flexDirection: 'column',
    padding: '8px 8px 10px',
  }}>
    <div style={{ flex: 1, overflow: 'hidden' }}>{children}</div>
    {footer && <>
      <hr className="fermo-hr" style={{ margin: '8px 0' }}/>
      <div>{footer}</div>
    </>}
  </div>
);

const FermoSidebarItem = ({ icon, label, active, kbd, count, badge }) => (
  <div className={`fermo-side ${active ? 'active' : ''}`}>
    <span className="icn" style={{ display: 'inline-flex' }}>
      {icon && <FIcon name={icon} size={15}/>}
    </span>
    <span>{label}</span>
    {badge && <span style={{
      marginLeft: 'auto',
      width: 6, height: 6, borderRadius: '50%',
      background: badge === 'warn' ? 'var(--f-warn)' : badge === 'danger' ? 'var(--f-danger)' : 'var(--f-ok)',
    }}/>}
    {!badge && count != null && <span style={{
      marginLeft: 'auto',
      font: '500 11px var(--f-font-mono)',
      color: 'var(--f-fg-3)',
    }}>{count}</span>}
    {!badge && count == null && kbd && <span className="kbd">{kbd}</span>}
  </div>
);

// Window shell — sidebar + titlebar + content
const FermoWindow = ({
  width = 1100, height = 720,
  title = 'Fermo', subtitle, sidebar, children,
  desktop = true, contentStyle = {},
  rightChrome,
}) => {
  const win = (
    <div style={{
      width, height, borderRadius: 12, overflow: 'hidden',
      background: 'var(--f-bg-1)',
      boxShadow: '0 0 0 0.5px rgba(255,255,255,0.07), 0 28px 80px rgba(0,0,0,0.55), 0 8px 22px rgba(0,0,0,0.4)',
      display: 'flex', flexDirection: 'column',
      fontFamily: 'var(--f-font)',
      color: 'var(--f-fg-0)',
    }} className="fermo">
      <FermoTitlebar title={title} subtitle={subtitle} right={rightChrome}/>
      <div style={{ flex: 1, minHeight: 0, display: 'flex' }}>
        {sidebar}
        <div style={{
          flex: 1, minWidth: 0, overflow: 'hidden',
          display: 'flex', flexDirection: 'column',
          ...contentStyle,
        }}>{children}</div>
      </div>
    </div>
  );
  if (!desktop) return win;
  return (
    <div style={{
      width: '100%', height: '100%',
      background: 'radial-gradient(ellipse at 25% 18%, #1a2230, #0a0e15 55%, #060810)',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      padding: 24, position: 'relative', overflow: 'hidden',
      fontFamily: 'var(--f-font)',
    }}>
      {/* macOS top menu bar (slim) */}
      <div style={{
        position: 'absolute', top: 0, left: 0, right: 0, height: 26,
        background: 'rgba(10,14,20,0.72)',
        backdropFilter: 'blur(18px)',
        borderBottom: '0.5px solid rgba(255,255,255,0.06)',
        display: 'flex', alignItems: 'center', padding: '0 14px', gap: 16,
        fontSize: 12, color: 'rgba(255,255,255,0.85)',
      }}>
        <FIcon name="fermo.mark" size={13} style={{ color: 'var(--f-ok)' }}/>
        <span style={{ fontWeight: 600 }}>Fermo</span>
        <span style={{ opacity: 0.85 }}>File</span>
        <span style={{ opacity: 0.85 }}>Edit</span>
        <span style={{ opacity: 0.85 }}>Session</span>
        <span style={{ opacity: 0.85 }}>Room</span>
        <span style={{ opacity: 0.85 }}>Window</span>
        <span style={{ opacity: 0.85 }}>Help</span>
        <div style={{ flex: 1 }}/>
        <span style={{ opacity: 0.7, fontFamily: 'var(--f-font-mono)', fontSize: 11, color: 'var(--f-ok)' }}>● Protected</span>
        <span style={{ opacity: 0.75 }}>Sun 12 Apr · 14:18</span>
      </div>
      {win}
    </div>
  );
};

Object.assign(window, {
  FIcon, FStatus, Chip, Kbd, Seg,
  FermoWindow, FermoSidebar, FermoSidebarItem,
  FermoTrafficLights, FermoTitlebar,
});
