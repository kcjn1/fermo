// Fermo — brand / tokens / component inventory artboards
// Exposes: FermoCover, FermoTokens, FermoIconStudy, FermoComponentInventory, FermoHandoff

const Sw = ({ color, label, value }) => (
  <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
    <div style={{ width: '100%', height: 64, background: color, borderRadius: 8, border: '0.5px solid rgba(255,255,255,0.06)' }}/>
    <div style={{ fontSize: 11.5, fontWeight: 600, color: 'var(--f-fg-0)' }}>{label}</div>
    <div style={{ fontSize: 10.5, color: 'var(--f-fg-3)', fontFamily: 'var(--f-font-mono)' }}>{value}</div>
  </div>
);

// ─────────────────────────────────────────────────────────────
// Cover — direction statement
// ─────────────────────────────────────────────────────────────
const FermoCover = () => (
  <div style={{
    width: '100%', height: '100%',
    background: 'radial-gradient(ellipse at 30% 20%, #161d28, #0a0d12 60%, #050709)',
    padding: '64px 64px',
    display: 'flex', flexDirection: 'column', justifyContent: 'space-between',
    fontFamily: 'var(--f-font)',
    color: 'var(--f-fg-0)',
  }} className="fermo">
    <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
      <AppIconArt size={56}/>
      <div>
        <div style={{ fontSize: 22, fontWeight: 600, letterSpacing: 0 }}>Fermo</div>
        <div style={{ fontSize: 12, color: 'var(--f-fg-3)', fontFamily: 'var(--f-font-mono)' }}>TOOLARY · NATIVE MACOS · PRE-BETA</div>
      </div>
      <div style={{ marginLeft: 'auto', display: 'flex', alignItems: 'center', gap: 8 }}>
        <FStatus tone="muted">Pre-beta · not for release</FStatus>
      </div>
    </div>

    <div style={{ maxWidth: 820 }}>
      <div style={{ fontSize: 40, fontWeight: 600, letterSpacing: 0, lineHeight: 1.08, color: 'var(--f-fg-0)' }}>
        A quiet local macOS control room for one protected work contract.
      </div>
      <div style={{ marginTop: 18, fontSize: 14, color: 'var(--f-fg-1)', lineHeight: 1.55, maxWidth: 720 }}>
        Fermo is not a blocker, not a productivity dashboard, not a parental-control tool.
        You define one task, the intended outcome, the rules of the room, and the rigor.
        Fermo protects the session and helps you leave with honest proof — or an honest reason it did not ship.
      </div>
    </div>

    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 28, maxWidth: 1080 }}>
      {[
        { i: 'doc.text',  t: 'Focus Contract', d: 'Task, outcome, duration, rigor, proof.' },
        { i: 'door.left.hand.closed', t: 'Focus Room', d: 'Allowlist of what belongs.' },
        { i: 'lock.shield', t: 'Honest enforcement', d: 'System Health is a first-class screen.' },
        { i: 'list.bullet.clipboard', t: 'Evidence log', d: 'Local Markdown work ledger.' },
      ].map(c => (
        <div key={c.t} style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          <FIcon name={c.i} size={20} style={{ color: 'var(--f-ok)' }}/>
          <div style={{ fontSize: 14, fontWeight: 600 }}>{c.t}</div>
          <div style={{ fontSize: 12.5, color: 'var(--f-fg-2)', lineHeight: 1.5 }}>{c.d}</div>
        </div>
      ))}
    </div>
  </div>
);

// ─────────────────────────────────────────────────────────────
// Tokens — colors, type, radius, spacing, state colors
// ─────────────────────────────────────────────────────────────
const FermoTokens = () => (
  <div style={{
    width: '100%', height: '100%',
    background: 'var(--f-bg-1)', color: 'var(--f-fg-0)',
    padding: '40px 48px',
    fontFamily: 'var(--f-font)',
    overflow: 'auto',
  }} className="fermo">
    <div style={{ fontSize: 12, fontWeight: 600, color: 'var(--f-fg-3)', textTransform: 'uppercase', letterSpacing: 0.06 }}>Design tokens</div>
    <div style={{ fontSize: 24, fontWeight: 600, marginTop: 4, letterSpacing: 0 }}>Visual language</div>

    {/* SURFACES */}
    <div style={{ fontSize: 11, fontWeight: 600, color: 'var(--f-fg-3)', textTransform: 'uppercase', letterSpacing: 0.06, marginTop: 28, marginBottom: 10 }}>Surfaces (dark graphite ink)</div>
    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(6, 1fr)', gap: 12 }}>
      <Sw color="#07090c" label="bg/0 desktop" value="#07090C"/>
      <Sw color="#0d1014" label="bg/1 window" value="#0D1014"/>
      <Sw color="#14181e" label="bg/2 sidebar" value="#14181E"/>
      <Sw color="#1a1f27" label="bg/3 row" value="#1A1F27"/>
      <Sw color="#232932" label="bg/4 popover" value="#232932"/>
      <Sw color="#2c333d" label="bg/5 hover" value="#2C333D"/>
    </div>

    {/* STATE */}
    <div style={{ fontSize: 11, fontWeight: 600, color: 'var(--f-fg-3)', textTransform: 'uppercase', letterSpacing: 0.06, marginTop: 28, marginBottom: 10 }}>State (restrained, only used for meaning)</div>
    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12 }}>
      <Sw color="oklch(0.74 0.09 168)" label="ok · Protected, Ready" value="oklch(.74 .09 168)"/>
      <Sw color="oklch(0.72 0.10 232)" label="info · Needs approval" value="oklch(.72 .10 232)"/>
      <Sw color="oklch(0.78 0.11 75)"  label="warn · Degraded, Unverified" value="oklch(.78 .11 75)"/>
      <Sw color="oklch(0.66 0.16 25)"  label="danger · Real failure only" value="oklch(.66 .16 25)"/>
    </div>

    {/* FG */}
    <div style={{ fontSize: 11, fontWeight: 600, color: 'var(--f-fg-3)', textTransform: 'uppercase', letterSpacing: 0.06, marginTop: 28, marginBottom: 10 }}>Foreground</div>
    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(5, 1fr)', gap: 12 }}>
      <Sw color="#e8eaee" label="fg/0 primary" value="#E8EAEE"/>
      <Sw color="#b6bac2" label="fg/1 secondary" value="#B6BAC2"/>
      <Sw color="#868c96" label="fg/2 label" value="#868C96"/>
      <Sw color="#5b626d" label="fg/3 tertiary" value="#5B626D"/>
      <Sw color="#3d434c" label="fg/4 disabled" value="#3D434C"/>
    </div>

    {/* TYPE */}
    <div style={{ fontSize: 11, fontWeight: 600, color: 'var(--f-fg-3)', textTransform: 'uppercase', letterSpacing: 0.06, marginTop: 32, marginBottom: 12 }}>Typography · Apple system stack</div>
    <div style={{ background: 'var(--f-bg-2)', border: '1px solid var(--f-line)', borderRadius: 10, padding: 20 }}>
      <div style={{ display: 'grid', gridTemplateColumns: '80px 1fr 1fr', rowGap: 12, columnGap: 18, alignItems: 'baseline' }}>
        {[
          ['11/600', 'Section label', '0.08em tracking', 11, 600, 'uppercase'],
          ['12/500', 'Caption / secondary text', '−0.005em', 12, 500],
          ['13/500', 'Body, controls (default)', '−0.005em', 13, 500],
          ['13/600', 'Row title', '−0.005em', 13, 600],
          ['17/600', 'Screen title', '−0.012em', 17, 600],
          ['26/600', 'Time remaining (display)', '−0.018em', 26, 600],
          ['44/600', 'Hero number (display)', '−0.022em', 44, 600],
        ].map((row, i) => (
          <React.Fragment key={i}>
            <div style={{ fontSize: 11, color: 'var(--f-fg-3)', fontFamily: 'var(--f-font-mono)' }}>{row[0]}</div>
            <div style={{ fontSize: row[3], fontWeight: row[4], color: 'var(--f-fg-0)', textTransform: row[5] || 'none', letterSpacing: row[5] === 'uppercase' ? 0.08 : -0.005 }}>{row[1]}</div>
            <div style={{ fontSize: 11.5, color: 'var(--f-fg-3)', fontFamily: 'var(--f-font-mono)' }}>{row[2]}</div>
          </React.Fragment>
        ))}
      </div>
    </div>

    {/* RADIUS + SPACE */}
    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 28, marginTop: 32 }}>
      <div>
        <div style={{ fontSize: 11, fontWeight: 600, color: 'var(--f-fg-3)', textTransform: 'uppercase', letterSpacing: 0.06, marginBottom: 10 }}>Radii — modest, native</div>
        <div style={{ display: 'flex', gap: 12, alignItems: 'flex-end' }}>
          {[4, 6, 8, 10, 12].map(r => (
            <div key={r} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6 }}>
              <div style={{ width: 48, height: 48, background: 'var(--f-bg-3)', border: '1px solid var(--f-line-2)', borderRadius: r }}/>
              <div style={{ fontSize: 10.5, color: 'var(--f-fg-3)', fontFamily: 'var(--f-font-mono)' }}>{r}px</div>
            </div>
          ))}
        </div>
      </div>
      <div>
        <div style={{ fontSize: 11, fontWeight: 600, color: 'var(--f-fg-3)', textTransform: 'uppercase', letterSpacing: 0.06, marginBottom: 10 }}>Spacing scale</div>
        <div style={{ display: 'flex', gap: 12, alignItems: 'flex-end' }}>
          {[4, 8, 12, 16, 20, 24].map(s => (
            <div key={s} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6 }}>
              <div style={{ width: s, height: 48, background: 'var(--f-ok)' }}/>
              <div style={{ fontSize: 10.5, color: 'var(--f-fg-3)', fontFamily: 'var(--f-font-mono)' }}>{s}</div>
            </div>
          ))}
        </div>
      </div>
    </div>

    {/* Iconography */}
    <div style={{ fontSize: 11, fontWeight: 600, color: 'var(--f-fg-3)', textTransform: 'uppercase', letterSpacing: 0.06, marginTop: 32, marginBottom: 10 }}>Iconography — SF Symbols-style, 1.5px, 24-grid</div>
    <div style={{ background: 'var(--f-bg-2)', border: '1px solid var(--f-line)', borderRadius: 10, padding: 18, display: 'grid', gridTemplateColumns: 'repeat(8, 1fr)', gap: 14 }}>
      {[
        'lock.shield','door.left.hand.closed','checkmark.seal','doc.text','target',
        'network','app.dashed','exclamationmark.triangle','clock','gearshape',
        'switch.2','eye.slash','list.bullet.clipboard','square.and.pencil','hand.raised','timer',
      ].map(n => (
        <div key={n} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6 }}>
          <div style={{ width: 36, height: 36, background: 'var(--f-bg-3)', border: '1px solid var(--f-line-2)', borderRadius: 7, display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--f-fg-1)' }}>
            <FIcon name={n} size={18}/>
          </div>
          <div style={{ fontSize: 9.5, color: 'var(--f-fg-3)', fontFamily: 'var(--f-font-mono)', textAlign: 'center', lineHeight: 1.2 }}>{n}</div>
        </div>
      ))}
    </div>
  </div>
);

// ─────────────────────────────────────────────────────────────
// App icon studies — Dock sizes, lockups, do/don't
// ─────────────────────────────────────────────────────────────
const FermoIconStudy = () => (
  <div style={{
    width: '100%', height: '100%',
    background: 'var(--f-bg-1)', color: 'var(--f-fg-0)',
    padding: '40px 48px',
    fontFamily: 'var(--f-font)',
    overflow: 'auto',
  }} className="fermo">
    <div style={{ fontSize: 12, fontWeight: 600, color: 'var(--f-fg-3)', textTransform: 'uppercase', letterSpacing: 0.06 }}>App icon</div>
    <div style={{ fontSize: 24, fontWeight: 600, marginTop: 4, letterSpacing: 0 }}>Protected room · contract seal</div>
    <div style={{ fontSize: 13, color: 'var(--f-fg-2)', marginTop: 8, maxWidth: 720, lineHeight: 1.5 }}>
      Dark graphite squircle. A subtle door outline. A circular seal sits on the door, with a calm checkmark drawn in restrained teal. No mascots, cages, chains, lightning. Reads as a serious utility at Dock size.
    </div>

    {/* Hero + sizes */}
    <div style={{ display: 'flex', alignItems: 'center', gap: 64, marginTop: 36 }}>
      <AppIconArt size={256}/>
      <div style={{ display: 'flex', gap: 24, alignItems: 'flex-end' }}>
        {[128, 96, 64, 48, 32, 24, 16].map(s => (
          <div key={s} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8 }}>
            <AppIconArt size={s}/>
            <div style={{ fontSize: 10.5, color: 'var(--f-fg-3)', fontFamily: 'var(--f-font-mono)' }}>{s}</div>
          </div>
        ))}
      </div>
    </div>

    {/* In context — Dock */}
    <div style={{ fontSize: 11, fontWeight: 600, color: 'var(--f-fg-3)', textTransform: 'uppercase', letterSpacing: 0.06, marginTop: 36, marginBottom: 12 }}>In context · macOS Dock</div>
    <div style={{
      padding: 14,
      background: 'rgba(20, 25, 32, 0.65)',
      backdropFilter: 'blur(20px)',
      border: '0.5px solid rgba(255,255,255,0.07)',
      borderRadius: 22,
      display: 'inline-flex', gap: 12, alignItems: 'flex-end',
    }}>
      {[
        { c: 'linear-gradient(135deg,#4f7df7,#1d3ec0)', l: 'Finder' },
        { c: 'linear-gradient(135deg,#27c9d1,#0d97a8)', l: 'Mail' },
        { c: 'linear-gradient(135deg,#ffb53d,#ff6c2a)', l: 'Notes' },
        { c: 'fermo' },
        { c: 'linear-gradient(135deg,#f8f8f8,#dcdcdc)', l: 'Numbers' },
        { c: 'linear-gradient(135deg,#5b5b5b,#222)', l: 'Terminal' },
      ].map((d, i) => d.c === 'fermo' ? (
        <AppIconArt key={i} size={56}/>
      ) : (
        <div key={i} style={{ width: 56, height: 56, borderRadius: 12.5, background: d.c, boxShadow: '0 4px 10px rgba(0,0,0,0.35)' }}/>
      ))}
    </div>

    {/* Avoid */}
    <div style={{ fontSize: 11, fontWeight: 600, color: 'var(--f-fg-3)', textTransform: 'uppercase', letterSpacing: 0.06, marginTop: 36, marginBottom: 12 }}>Avoid</div>
    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 14 }}>
      {[
        'Bright red panic lock',
        'Cages or chains',
        'Lightning bolts',
        'Confetti / streak marks',
      ].map(t => (
        <div key={t} style={{ display: 'flex', alignItems: 'center', gap: 10, padding: 10, border: '1px solid var(--f-line-2)', borderRadius: 8 }}>
          <FIcon name="xmark.circle" size={14} style={{ color: 'var(--f-danger)' }}/>
          <span style={{ fontSize: 12.5, color: 'var(--f-fg-1)' }}>{t}</span>
        </div>
      ))}
    </div>
  </div>
);

// ─────────────────────────────────────────────────────────────
// Component inventory — molecules / button family / form atoms
// ─────────────────────────────────────────────────────────────
const InvSection = ({ title, children }) => (
  <div style={{ marginTop: 28 }}>
    <div style={{ fontSize: 11, fontWeight: 600, color: 'var(--f-fg-3)', textTransform: 'uppercase', letterSpacing: 0.06, marginBottom: 10 }}>{title}</div>
    <div style={{ background: 'var(--f-bg-2)', border: '1px solid var(--f-line)', borderRadius: 10, padding: 18 }}>
      {children}
    </div>
  </div>
);

const FermoComponentInventory = () => (
  <div style={{
    width: '100%', height: '100%',
    background: 'var(--f-bg-1)', color: 'var(--f-fg-0)',
    padding: '40px 48px',
    fontFamily: 'var(--f-font)',
    overflow: 'auto',
  }} className="fermo">
    <div style={{ fontSize: 12, fontWeight: 600, color: 'var(--f-fg-3)', textTransform: 'uppercase', letterSpacing: 0.06 }}>Components</div>
    <div style={{ fontSize: 24, fontWeight: 600, marginTop: 4, letterSpacing: 0 }}>Inventory</div>

    <InvSection title="Status pills">
      <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
        <FStatus tone="ok">Protected</FStatus>
        <FStatus tone="ok">Ready</FStatus>
        <FStatus tone="info">Needs approval</FStatus>
        <FStatus tone="warn">Degraded</FStatus>
        <FStatus tone="warn">Unverified</FStatus>
        <FStatus tone="danger">Error</FStatus>
        <FStatus tone="muted">Idle</FStatus>
      </div>
    </InvSection>

    <InvSection title="Buttons">
      <div style={{ display: 'flex', gap: 10, alignItems: 'center', flexWrap: 'wrap' }}>
        <button className="fermo-btn fermo-btn-primary fermo-btn-lg"><FIcon name="play.fill" size={11}/>Start Contract</button>
        <button className="fermo-btn fermo-btn-secondary fermo-btn-lg">View Active Session</button>
        <button className="fermo-btn fermo-btn-secondary">Record proof</button>
        <button className="fermo-btn fermo-btn-ghost">Skip</button>
        <button className="fermo-btn fermo-btn-danger">Break glass</button>
        <button className="fermo-btn fermo-btn-secondary fermo-btn-sm"><FIcon name="plus" size={11}/>Add</button>
        <button className="fermo-btn fermo-btn-primary" disabled>Stop (Locked)</button>
      </div>
    </InvSection>

    <InvSection title="Segmented control · selectors">
      <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
        <Seg options={[{value:'today', label:'Today'},{value:'week', label:'This week'},{value:'all', label:'All time'}]} value="today" onChange={()=>{}}/>
        <div style={{ display: 'flex', gap: 24 }}>
          <div style={{ flex: 1, maxWidth: 320 }}>
            <div className="fermo-kv-label" style={{ marginBottom: 6 }}>Mode</div>
            <ModePicker value="room" onChange={()=>{}}/>
          </div>
          <div style={{ flex: 1, maxWidth: 360 }}>
            <div className="fermo-kv-label" style={{ marginBottom: 6 }}>Rigor</div>
            <RigorPicker value="locked" compact/>
          </div>
        </div>
      </div>
    </InvSection>

    <InvSection title="Inputs">
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14, maxWidth: 720 }}>
        <div>
          <div className="fermo-kv-label" style={{ marginBottom: 6 }}>Task title</div>
          <input className="fermo-input" defaultValue="Draft Q3 reliability memo"/>
        </div>
        <div>
          <div className="fermo-kv-label" style={{ marginBottom: 6 }}>Duration</div>
          <input className="fermo-input fermo-mono" defaultValue="90 min"/>
        </div>
        <div style={{ gridColumn: '1 / -1' }}>
          <div className="fermo-kv-label" style={{ marginBottom: 6 }}>Intended outcome</div>
          <textarea className="fermo-textarea" defaultValue="A complete first draft. Sections 1–3 written end to end, with one supporting graph plotted."/>
        </div>
      </div>
    </InvSection>

    <InvSection title="Permission alert">
      <div style={{ display: 'flex', flexDirection: 'column', gap: 10, maxWidth: 640 }}>
        <PermissionAlert
          tone="info" icon="info.circle"
          title="System extension waiting for approval"
          body="macOS requires approval in System Settings → Privacy & Security for Fermo to filter network traffic during a session."
          primary="Open System Settings" secondary="Show me how"
        />
        <PermissionAlert
          tone="warn" icon="questionmark.circle"
          title="Helper restore after reboot — unverified"
          body="Fermo could not confirm the helper rebinds after a full restart. This check is manual until the spike completes."
        />
      </div>
    </InvSection>

    <InvSection title="Status row (System Health)">
      <div style={{ background: 'var(--f-bg-1)', border: '1px solid var(--f-line)', borderRadius: 8 }}>
        <StatusRow icon="lock.shield" title="System Extension"
          state="active" detail="Loaded by macOS and approved locally. Reboot restore remains a manual check before beta."
          last="11s ago" dense/>
        <hr className="fermo-hr"/>
        <StatusRow icon="network" title="Network Extension Content Filter"
          state="approval" detail="Awaiting allow in System Settings → Privacy & Security."
          last="2m ago" action={{ label: 'Open Settings', tone: 'primary' }} dense/>
        <hr className="fermo-hr"/>
        <StatusRow icon="app.dashed" title="App interruption"
          state="degraded" detail="One app could not be paused: Firefox. Bundle id check pending."
          last="just now" action={{ label: 'Recheck' }} dense/>
      </div>
    </InvSection>

    <InvSection title="Evidence row">
      <div style={{ background: 'var(--f-bg-1)', border: '1px solid var(--f-line)', borderRadius: 8 }}>
        <EvidenceRow date="Apr 12" time="14:18" task="Draft Q3 reliability memo"
          outcome="completed" duration="90:00" rigor="locked" room="Deep Writing"
          proof="memo-q3-draft.md · 3 sections + 1 graph"/>
        <EvidenceRow date="Apr 11" time="09:30" task="Triage support backlog"
          outcome="partial" duration="60:00" rigor="soft" room="Admin"
          proof="Closed 9 of 14 tickets. Stopped 22 min early."/>
        <EvidenceRow date="Apr 10" time="16:00" task="Finish migration runbook"
          outcome="broke-glass" duration="73:00" rigor="emergency" room="Coding"
          reason="On-call paged for SEV-2 incident. Resumed work after handoff."/>
      </div>
    </InvSection>

    <InvSection title="Proof card · empty / full">
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14 }}>
        <ProofCard outcome="completed" ts="14:48 today"
          note="Drafted §1–3 of the reliability memo end to end, plus the SLA-vs-actual graph for §2. Holes left: §4 needs the new error-budget numbers from Mira."
          file="evidence/2026-04-12-q3-reliability.md" link="github.com/team/notes/pull/482"/>
        <ProofCard outcome="not-done" ts="—"
          note="Did not ship. Got pulled into the on-call rotation. Will retry tomorrow with a Locked 90-min slot."/>
      </div>
    </InvSection>
  </div>
);

// ─────────────────────────────────────────────────────────────
// Handoff — SwiftUI notes
// ─────────────────────────────────────────────────────────────
const FermoHandoff = () => (
  <div style={{
    width: '100%', height: '100%',
    background: 'var(--f-bg-1)', color: 'var(--f-fg-0)',
    padding: '40px 48px',
    fontFamily: 'var(--f-font)',
    overflow: 'auto',
  }} className="fermo">
    <div style={{ fontSize: 12, fontWeight: 600, color: 'var(--f-fg-3)', textTransform: 'uppercase', letterSpacing: 0.06 }}>Implementation</div>
    <div style={{ fontSize: 24, fontWeight: 600, marginTop: 4, letterSpacing: 0 }}>SwiftUI handoff</div>

    <div style={{ display: 'grid', gridTemplateColumns: '1.1fr 0.9fr', gap: 24, marginTop: 24 }}>
      <div className="fermo-card" style={{ padding: 20 }}>
        <div style={{ fontSize: 13, fontWeight: 600, marginBottom: 12 }}>View hierarchy</div>
        <pre className="fermo-mono" style={{ fontSize: 11.5, lineHeight: 1.55, color: 'var(--f-fg-1)', margin: 0, whiteSpace: 'pre-wrap' }}>{`FermoApp                       (App)
├─ MenuBarExtra("Fermo", …)    (popover scene)
│   └─ MenuBarPopoverView      (compact, 360pt wide)
└─ WindowGroup("Fermo")
    └─ MainWindowView          (NavigationSplitView)
        ├─ Sidebar             (List of FermoArea cases)
        └─ ContentView         (switch on area)
            ├─ TodayView
            ├─ StartContractView
            ├─ RoomsView ─ RoomDetailView
            ├─ BlocklistEditorView
            ├─ FocusRoomBuilderView
            ├─ ActiveSessionView
            ├─ ProofCaptureView
            ├─ EvidenceLogView
            ├─ SystemHealthView
            └─ PreferencesView`}</pre>
      </div>

      <div className="fermo-card" style={{ padding: 20 }}>
        <div style={{ fontSize: 13, fontWeight: 600, marginBottom: 12 }}>State model</div>
        <pre className="fermo-mono" style={{ fontSize: 11.5, lineHeight: 1.55, color: 'var(--f-fg-1)', margin: 0, whiteSpace: 'pre-wrap' }}>{`@MainActor
final class FermoStore: ObservableObject {
  @Published var protection: ProtectionState
  @Published var activeSession: Session?
  @Published var rooms: [Room]
  @Published var evidence: [EvidenceEntry]
  @Published var health: SystemHealth
}

enum ProtectionState {
  case idle, protected, degraded, needsApproval
}

enum Rigor { case soft, locked, emergency }
enum Mode  { case focusRoom, blocklist }

struct Session: Identifiable, Codable {
  let id: UUID
  var task: String
  var intendedOutcome: String
  var duration: Duration
  var rigor: Rigor
  var mode: Mode
  var roomID: UUID?
  var proofRequirement: ProofRequirement
  var startedAt: Date
}`}</pre>
      </div>

      <div className="fermo-card" style={{ padding: 20 }}>
        <div style={{ fontSize: 13, fontWeight: 600, marginBottom: 12 }}>Reusable components</div>
        <ul style={{ margin: 0, paddingLeft: 18, fontSize: 12.5, color: 'var(--f-fg-1)', lineHeight: 1.7 }}>
          <li><span className="fermo-mono" style={{ color: 'var(--f-ok)' }}>StatusBadge(tone:label:)</span> · status pill</li>
          <li><span className="fermo-mono" style={{ color: 'var(--f-ok)' }}>RigorPicker(selection:)</span> · radio cards</li>
          <li><span className="fermo-mono" style={{ color: 'var(--f-ok)' }}>ModePicker(selection:)</span> · two-card segmented</li>
          <li><span className="fermo-mono" style={{ color: 'var(--f-ok)' }}>HealthRow(icon:title:state:action:)</span></li>
          <li><span className="fermo-mono" style={{ color: 'var(--f-ok)' }}>EvidenceRow(entry:)</span></li>
          <li><span className="fermo-mono" style={{ color: 'var(--f-ok)' }}>PermissionAlert(tone:title:body:)</span></li>
          <li><span className="fermo-mono" style={{ color: 'var(--f-ok)' }}>ActiveSessionHeader(session:)</span></li>
          <li><span className="fermo-mono" style={{ color: 'var(--f-ok)' }}>BreakGlassDialog(reason:onConfirm:)</span></li>
        </ul>
      </div>

      <div className="fermo-card" style={{ padding: 20 }}>
        <div style={{ fontSize: 13, fontWeight: 600, marginBottom: 12 }}>Keep native</div>
        <ul style={{ margin: 0, paddingLeft: 18, fontSize: 12.5, color: 'var(--f-fg-1)', lineHeight: 1.7 }}>
          <li>NavigationSplitView for sidebar — use AppKit-style list rows.</li>
          <li>MenuBarExtra for the popover — let macOS handle dismissal & focus.</li>
          <li>System Settings deep-links via <span className="fermo-mono">x-apple.systempreferences:</span> URLs.</li>
          <li>SF Symbols (real ones) for every icon. No custom icon fonts.</li>
          <li>Material backgrounds (.regularMaterial) for popover only; flat panels elsewhere.</li>
          <li>NSTouchBar / Help menu items: standard.</li>
          <li>Markdown evidence export uses Foundation's AttributedString.</li>
          <li>Local-only persistence should start from the existing FermoCore JSON/app-group stores; no iCloud sync in v1.</li>
        </ul>
      </div>
    </div>

    {/* Assumptions */}
    <div className="fermo-card" style={{ padding: 20, marginTop: 20 }}>
      <div style={{ fontSize: 13, fontWeight: 600, marginBottom: 10 }}>Design assumptions &amp; open questions</div>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 18 }}>
        <ul style={{ margin: 0, paddingLeft: 18, fontSize: 12.5, color: 'var(--f-fg-1)', lineHeight: 1.6 }}>
          <li><b style={{ color: 'var(--f-fg-0)' }}>Assumed:</b> dark mode is the default; light theme deferred.</li>
          <li><b style={{ color: 'var(--f-fg-0)' }}>Assumed:</b> evidence is plain Markdown on disk, indexed locally; no DB.</li>
          <li><b style={{ color: 'var(--f-fg-0)' }}>Assumed:</b> menu bar popover is daily-use surface; window is for setup &amp; review.</li>
          <li><b style={{ color: 'var(--f-fg-0)' }}>Assumed:</b> Locked rigor does not pretend to be tamper-proof; honest copy is required.</li>
        </ul>
        <ul style={{ margin: 0, paddingLeft: 18, fontSize: 12.5, color: 'var(--f-fg-1)', lineHeight: 1.6 }}>
          <li><b style={{ color: 'var(--f-fg-0)' }}>Open:</b> visualization of remaining time — ring, bar, or numeric only?</li>
          <li><b style={{ color: 'var(--f-fg-0)' }}>Open:</b> how aggressive should the app-interruption affordance be?</li>
          <li><b style={{ color: 'var(--f-fg-0)' }}>Open:</b> shortcut for break-glass — should it require ⌘⌥⌃ to confirm?</li>
          <li><b style={{ color: 'var(--f-fg-0)' }}>Open:</b> evidence export — single file per session vs. monthly digest?</li>
        </ul>
      </div>
    </div>
  </div>
);

Object.assign(window, { FermoCover, FermoTokens, FermoIconStudy, FermoComponentInventory, FermoHandoff });
