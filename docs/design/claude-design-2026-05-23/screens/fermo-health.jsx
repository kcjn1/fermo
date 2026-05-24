// Fermo — Evidence log, System Health, Preferences
// Exposes: FermoEvidenceLog, FermoSystemHealth, FermoPreferences

// ─────────────────────────────────────────────────────────────
// EVIDENCE LOG — work ledger with filters
// ─────────────────────────────────────────────────────────────
const EVIDENCE = [
  { d: 'Apr 12', t: '14:18', task: 'Draft Q3 reliability memo',     outcome: 'completed',  duration: '90:00', rigor: 'locked',   room: 'Deep Writing', proof: 'memo-q3-draft.md · 3 sections + 1 graph' },
  { d: 'Apr 12', t: '09:10', task: 'Inbox zero',                    outcome: 'completed',  duration: '30:00', rigor: 'soft',     room: 'Admin',        proof: '0 unread · 17 archived · 4 deferred' },
  { d: 'Apr 11', t: '14:00', task: 'Refactor billing reconciler',   outcome: 'partial',    duration: '120:00',rigor: 'locked',   room: 'Coding',       proof: 'Got the new error envelope merged. Did not finish reconciliation table.' },
  { d: 'Apr 11', t: '09:30', task: 'Triage support backlog',        outcome: 'partial',    duration: '60:00', rigor: 'soft',     room: 'Admin',        proof: 'Closed 9 of 14 tickets. Stopped 22 min early.' },
  { d: 'Apr 10', t: '16:00', task: 'Finish migration runbook',      outcome: 'broke-glass',duration: '73:00', rigor: 'emergency',room: 'Coding',       reason: 'On-call paged for SEV-2 incident. Resumed work after handoff.' },
  { d: 'Apr 10', t: '10:00', task: 'Plan Q3 hiring',                outcome: 'completed',  duration: '60:00', rigor: 'locked',   room: 'Deep Planning',proof: 'plan-hiring-q3.md · 3 roles scoped, JD links saved' },
  { d: 'Apr 09', t: '10:00', task: 'Draft brand language doc',      outcome: 'completed',  duration: '90:00', rigor: 'locked',   room: 'Deep Writing', proof: 'brand-voice-v3.md · 4 sections, 2 examples each' },
  { d: 'Apr 09', t: '08:00', task: 'Code review queue',             outcome: 'not-done',   duration: '00:00', rigor: 'soft',     room: 'Coding',       reason: 'Skipped — partner sick, took kid to school.' },
  { d: 'Apr 08', t: '13:30', task: 'Inbox zero',                    outcome: 'completed',  duration: '45:00', rigor: 'soft',     room: 'Admin',        proof: '0 unread · 12 archived · 3 deferred' },
  { d: 'Apr 08', t: '09:30', task: 'Write SOC2 evidence policy',    outcome: 'completed',  duration: '90:00', rigor: 'locked',   room: 'Deep Writing', proof: 'policy-evidence-v1.md · 7 controls covered' },
  { d: 'Apr 07', t: '14:00', task: 'Schema migration plan',         outcome: 'partial',    duration: '60:00', rigor: 'locked',   room: 'Coding',       proof: 'Plan drafted. Did not validate against prod schema yet.' },
  { d: 'Apr 07', t: '09:00', task: 'Review compensation grid',      outcome: 'completed',  duration: '60:00', rigor: 'locked',   room: 'Deep Planning',proof: 'Grid signed off. Three salary bands adjusted.' },
];

const FilterPill = ({ icon, label, value, on, onCount }) => (
  <button className="fermo-btn fermo-btn-secondary fermo-btn-sm" style={{
    background: on ? 'oklch(0.74 0.09 168 / 0.10)' : undefined,
    borderColor: on ? 'oklch(0.74 0.09 168 / 0.4)' : undefined,
    color: on ? 'var(--f-ok)' : undefined,
  }}>
    {icon && <FIcon name={icon} size={10}/>}
    <span style={{ color: 'var(--f-fg-2)' }}>{label}</span>
    <span style={{ fontWeight: 600, color: on ? 'var(--f-ok)' : 'var(--f-fg-0)' }}>{value}</span>
    {onCount != null && <span style={{ fontSize: 10.5, color: 'var(--f-fg-3)', fontFamily: 'var(--f-font-mono)' }}>{onCount}</span>}
    <FIcon name="chevron.down" size={10} style={{ color: 'var(--f-fg-3)' }}/>
  </button>
);

const FermoEvidenceLog = () => (
  <div style={{ display: 'flex', flexDirection: 'column', height: '100%', overflow: 'hidden' }}>
    <FermoSectionHead
      title="Evidence"
      subtitle="A local Markdown ledger of every session you ran."
      right={
        <>
          <button className="fermo-btn fermo-btn-ghost fermo-btn-sm"><FIcon name="magnifyingglass" size={11}/></button>
          <button className="fermo-btn fermo-btn-secondary fermo-btn-sm"><FIcon name="download" size={11}/> Export…</button>
        </>
      }
    />

    {/* Filter bar */}
    <div style={{ padding: '12px 22px', borderBottom: '1px solid var(--f-line)', display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
      <FilterPill label="Date" value="Apr 1 – 12" on={true}/>
      <FilterPill label="Outcome" value="All" onCount="4"/>
      <FilterPill label="Rigor" value="All" onCount="3"/>
      <FilterPill label="Room" value="All rooms" onCount="5"/>
      <div style={{ marginLeft: 'auto', display: 'flex', alignItems: 'center', gap: 10 }}>
        <span style={{ fontSize: 11, color: 'var(--f-fg-3)' }}>12 sessions · 738 min of focus · 9 with proof · 1 broke-glass · 1 not done</span>
      </div>
    </div>

    {/* Table header */}
    <div style={{
      display: 'grid',
      gridTemplateColumns: '88px 1fr 88px 84px 116px 22px',
      gap: 12,
      padding: '8px 18px',
      borderBottom: '1px solid var(--f-line)',
      background: 'var(--f-bg-2)',
      fontSize: 10.5, fontWeight: 600, color: 'var(--f-fg-3)',
      textTransform: 'uppercase', letterSpacing: 0.06,
    }}>
      <span>Date</span>
      <span>Task · proof / reason</span>
      <span>Duration</span>
      <span>Rigor</span>
      <span>Outcome</span>
      <span/>
    </div>

    <div style={{ flex: 1, overflow: 'auto' }}>
      {EVIDENCE.map((e, i) => (
        <EvidenceRow key={i} date={e.d} time={e.t} task={e.task}
          outcome={e.outcome} duration={e.duration} rigor={e.rigor} room={e.room}
          proof={e.proof} reason={e.reason}/>
      ))}
    </div>

    {/* Footer */}
    <div style={{ padding: '10px 22px', borderTop: '1px solid var(--f-line)', background: 'var(--f-bg-2)', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
      <span style={{ fontSize: 11, color: 'var(--f-fg-3)', fontFamily: 'var(--f-font-mono)' }}>
        ~/Fermo/evidence/ · 12 files · 84.2 KB
      </span>
      <div style={{ display: 'flex', gap: 8 }}>
        <button className="fermo-btn fermo-btn-ghost fermo-btn-sm">Reveal in Finder</button>
        <button className="fermo-btn fermo-btn-ghost fermo-btn-sm">Copy as Markdown</button>
      </div>
    </div>
  </div>
);

// ─────────────────────────────────────────────────────────────
// SYSTEM HEALTH — full screen, first-class
// ─────────────────────────────────────────────────────────────
const HealthGroup = ({ title, sub, action, children }) => (
  <div>
    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 8 }}>
      <div>
        <div style={{ fontSize: 12.5, fontWeight: 600, letterSpacing: 0 }}>{title}</div>
        {sub && <div style={{ fontSize: 11.5, color: 'var(--f-fg-2)', marginTop: 2 }}>{sub}</div>}
      </div>
      {action}
    </div>
    <div className="fermo-card" style={{ overflow: 'hidden' }}>{children}</div>
  </div>
);

const RowDivider = () => <div style={{ height: 1, background: 'var(--f-line)' }}/>;

const FermoSystemHealth = () => {
  const headline = {
    tone: 'warn',
    label: 'Mostly protected · 1 needs approval, 3 unverified',
    body: 'Fermo can run sessions, but cannot make every guarantee until the manual checks below are complete. This is what you can rely on right now.',
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%', overflow: 'hidden' }}>
      <FermoSectionHead
        title="System Health"
        subtitle="What macOS lets Fermo enforce, in plain language."
        right={
          <>
            <span style={{ fontSize: 11, color: 'var(--f-fg-3)', fontFamily: 'var(--f-font-mono)' }}>last full check · 14:18:02</span>
            <button className="fermo-btn fermo-btn-secondary fermo-btn-sm"><FIcon name="arrow.clockwise" size={11}/> Run all checks</button>
          </>
        }
      />
      <div style={{ flex: 1, overflow: 'auto', padding: '18px 22px 26px', display: 'flex', flexDirection: 'column', gap: 18 }}>
        {/* Headline */}
        <div style={{
          padding: '14px 16px',
          background: 'oklch(0.78 0.11 75 / 0.06)',
          border: '1px solid oklch(0.78 0.11 75 / 0.3)',
          borderRadius: 10,
          display: 'flex', gap: 14, alignItems: 'flex-start',
        }}>
          <div style={{
            width: 36, height: 36, borderRadius: 8,
            background: 'oklch(0.78 0.11 75 / 0.14)',
            border: '1px solid oklch(0.78 0.11 75 / 0.35)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            color: 'var(--f-warn)', flexShrink: 0,
          }}>
            <FIcon name="lock.shield" size={18}/>
          </div>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 14, fontWeight: 600, color: 'var(--f-warn)' }}>{headline.label}</div>
            <div style={{ fontSize: 12.5, color: 'var(--f-fg-1)', marginTop: 4, lineHeight: 1.5, maxWidth: 720 }}>{headline.body}</div>
            <div style={{ display: 'flex', gap: 16, marginTop: 12, flexWrap: 'wrap' }}>
              {[
                { k: 'Blocked websites', v: 'protected', tone: 'ok' },
                { k: 'Paused apps',      v: 'protected', tone: 'ok' },
                { k: 'Helper restore',   v: 'unverified', tone: 'warn' },
                { k: 'Reboot recovery',  v: 'unverified', tone: 'warn' },
              ].map(s => {
                const c = s.tone === 'ok' ? 'var(--f-ok)' : 'var(--f-warn)';
                return (
                  <div key={s.k} style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                    <FIcon name={s.tone === 'ok' ? 'checkmark.circle' : 'questionmark.circle'} size={12} style={{ color: c }}/>
                    <span style={{ fontSize: 12, color: 'var(--f-fg-2)' }}>{s.k}</span>
                    <span style={{ fontSize: 12, fontWeight: 600, color: c }}>{s.v}</span>
                  </div>
                );
              })}
            </div>
          </div>
        </div>

        {/* Group 1 — Approvals & Extensions */}
        <HealthGroup
          title="Approvals &amp; system extensions"
          sub="These need macOS-level allow. Granted once per user."
        >
          <StatusRow icon="lock.shield" title="System Extension"
            state="active" detail="Loaded by macOS and approved locally. Reboot restore remains a manual check before beta."
            last="11s ago"/>
          <RowDivider/>
          <StatusRow icon="network" title="Network Extension Content Filter"
            state="approval" detail="Awaiting allow in System Settings → Privacy &amp; Security. Until then, website blocking is inactive."
            last="2m ago" action={{ label: 'Open Settings', tone: 'primary', icon: 'arrow.up.right' }}/>
          <RowDivider/>
          <StatusRow icon="checkmark.seal" title="Signing / Developer Team"
            state="ready" detail="Team ID MP3AWS77U3 — local development signing. Production will use Apple Distribution."
            last="checked at launch"/>
          <RowDivider/>
          <StatusRow icon="doc.text" title="Notarization"
            state="notinstalled" detail="Notarization status for the public build. Available after first beta is cut."
            last="—"/>
        </HealthGroup>

        {/* Group 2 — Blocking & interruption */}
        <HealthGroup
          title="Blocking &amp; interruption"
          sub="What Fermo can actually do while a session is running."
        >
          <StatusRow icon="globe" title="Website Blocking"
            state="ready" detail="13 domains and 4 wildcards loaded into the content filter. Includes spike example reddit.com / youtube.com."
            last="just now"/>
          <RowDivider/>
          <StatusRow icon="app.dashed" title="App Interruption"
            state="ready" detail="4 apps will be paused (Messages, Discord, Slack, Calculator). Bundle ids resolved at session start."
            last="just now"/>
          <RowDivider/>
          <StatusRow icon="externaldrive" title="Helper / Login Item"
            state="active" detail="Helper has its own process. Persists after the main app quits — signed proof verified locally."
            last="9s ago"/>
          <RowDivider/>
          <StatusRow icon="tray.full" title="App Group shared state"
            state="active" detail="Helper and main app read the same session state."
            last="9s ago" action={{ label: 'Diagnostics' }}/>
        </HealthGroup>

        {/* Group 3 — Unverified manual checks */}
        <HealthGroup
          title="Manual checks · unverified"
          sub="Fermo cannot self-verify these. We will mark each one verified after the spike covers it."
          action={<button className="fermo-btn fermo-btn-ghost fermo-btn-sm">Open checklist</button>}
        >
          <StatusRow icon="power"   title="Sleep / wake restore"
            state="unverified" detail="Fermo could not confirm the helper rebinds after the Mac sleeps."
            last="never"  action={{ label: 'Mark verified' }}/>
          <RowDivider/>
          <StatusRow icon="arrow.clockwise" title="Reboot / login restore"
            state="unverified" detail="Fermo could not confirm helper restore after a full restart and login."
            last="never"  action={{ label: 'Mark verified' }}/>
          <RowDivider/>
          <StatusRow icon="wifi"    title="Wi-Fi change"
            state="unverified" detail="Filter rebind across Wi-Fi changes not yet tested."
            last="never"  action={{ label: 'Mark verified' }}/>
          <RowDivider/>
          <StatusRow icon="globe"   title="Firefox check"
            state="unverified" detail="Domain blocking in Firefox is not yet verified for this build."
            last="never"  action={{ label: 'Mark verified' }}/>
          <RowDivider/>
          <StatusRow icon="eye.slash" title="Safari / Chrome private windows"
            state="unverified" detail="Blocking behaviour in private / incognito modes pending."
            last="never"/>
        </HealthGroup>

        {/* Disclaimer */}
        <div style={{
          padding: 14, border: '1px dashed var(--f-line-2)', borderRadius: 8,
          fontSize: 11.5, color: 'var(--f-fg-2)', lineHeight: 1.55,
          display: 'flex', gap: 10,
        }}>
          <FIcon name="info.circle" size={13} style={{ color: 'var(--f-fg-3)', marginTop: 1, flexShrink: 0 }}/>
          <div>
            <b style={{ color: 'var(--f-fg-1)' }}>Fermo does not claim it cannot be bypassed.</b> macOS gives apps real tools to slow you down — content filters, app interruption, helpers — but a determined user with admin rights can always work around them. Fermo's job is to make that effort visible and recorded, not invisible.
          </div>
        </div>
      </div>
    </div>
  );
};

// ─────────────────────────────────────────────────────────────
// PREFERENCES — simple, native settings
// ─────────────────────────────────────────────────────────────
const PrefRow = ({ label, hint, control }) => (
  <div style={{
    display: 'grid', gridTemplateColumns: '220px 1fr', gap: 16,
    padding: '12px 0',
    borderBottom: '1px solid var(--f-line)',
    alignItems: 'flex-start',
  }}>
    <div>
      <div style={{ fontSize: 13, fontWeight: 500 }}>{label}</div>
      {hint && <div style={{ fontSize: 11.5, color: 'var(--f-fg-3)', marginTop: 2, lineHeight: 1.4 }}>{hint}</div>}
    </div>
    <div>{control}</div>
  </div>
);

const Toggle = ({ on = true }) => (
  <span style={{
    display: 'inline-block',
    width: 32, height: 18, borderRadius: 9,
    background: on ? 'var(--f-ok)' : 'var(--f-bg-4)',
    position: 'relative', verticalAlign: 'middle',
    cursor: 'pointer',
  }}>
    <span style={{
      position: 'absolute', top: 2, left: on ? 16 : 2,
      width: 14, height: 14, borderRadius: '50%',
      background: '#0c1014', transition: 'left 0.15s',
    }}/>
  </span>
);

const PrefSection = ({ title, children }) => (
  <div style={{ marginTop: 22 }}>
    <div style={{ fontSize: 10.5, fontWeight: 700, color: 'var(--f-fg-3)', textTransform: 'uppercase', letterSpacing: 0.06, marginBottom: 4 }}>{title}</div>
    <div style={{ borderTop: '1px solid var(--f-line)' }}>{children}</div>
  </div>
);

const FermoPreferences = ({ tab = 'general' }) => (
  <div style={{ display: 'flex', flexDirection: 'column', height: '100%', overflow: 'hidden' }}>
    <FermoSectionHead title="Preferences" subtitle="Defaults, storage, and developer diagnostics."/>
    <div style={{ display: 'flex', flex: 1, minHeight: 0 }}>
      {/* Side tabs */}
      <div style={{ width: 160, borderRight: '1px solid var(--f-line)', padding: '12px 8px', display: 'flex', flexDirection: 'column', gap: 2 }}>
        {[
          { id: 'general',  label: 'General',     icon: 'gearshape' },
          { id: 'defaults', label: 'Defaults',    icon: 'switch.2' },
          { id: 'storage',  label: 'Storage',     icon: 'externaldrive' },
          { id: 'privacy',  label: 'Privacy',     icon: 'hand.raised' },
          { id: 'advanced', label: 'Diagnostics', icon: 'list.bullet.clipboard' },
        ].map(t => (
          <FermoSidebarItem key={t.id} icon={t.icon} label={t.label} active={t.id === tab}/>
        ))}
      </div>
      <div style={{ flex: 1, overflow: 'auto', padding: '14px 24px 28px' }}>
        <PrefSection title="Defaults">
          <PrefRow label="Default duration"
            hint="Used when you start a contract without a preset."
            control={<DurationPicker value="90 min"/>}/>
          <PrefRow label="Default preset"
            hint="Pre-selected on the Start screen."
            control={
              <Seg options={[{value:'writing',label:'Writing'},{value:'coding',label:'Coding'},{value:'admin',label:'Admin'},{value:'plan',label:'Plan'}]} value="writing" onChange={()=>{}}/>
            }/>
          <PrefRow label="Default rigor"
            hint="Locked is the calm-but-firm default."
            control={<Seg options={[{value:'soft',label:'Soft'},{value:'locked',label:'Locked'},{value:'emergency',label:'Emergency'}]} value="locked" onChange={()=>{}}/>}/>
          <PrefRow label="Default proof requirement"
            hint="A Markdown evidence note is generated for every session."
            control={<Seg options={[{value:'note',label:'Short note'},{value:'md',label:'Markdown'},{value:'link',label:'Link / file'}]} value="md" onChange={()=>{}}/>}/>
        </PrefSection>

        <PrefSection title="Launch &amp; helper">
          <PrefRow label="Launch at login"
            hint="Fermo's helper starts automatically. Needed for reboot/login restore, which still requires manual validation."
            control={<div style={{ display: 'flex', alignItems: 'center', gap: 8 }}><Toggle on/> <span style={{ fontSize: 12, color: 'var(--f-fg-2)' }}>On · helper registered</span></div>}/>
          <PrefRow label="Keep helper running after quit"
            hint="Recommended. Helper persistence is part of the spike's signed-proof check."
            control={<div style={{ display: 'flex', alignItems: 'center', gap: 8 }}><Toggle on/> <span style={{ fontSize: 12, color: 'var(--f-fg-2)' }}>On</span></div>}/>
          <PrefRow label="Show in menu bar"
            hint="Recommended for daily use. Window stays available."
            control={<div style={{ display: 'flex', alignItems: 'center', gap: 8 }}><Toggle on/> <span style={{ fontSize: 12, color: 'var(--f-fg-2)' }}>On</span></div>}/>
        </PrefSection>

        <PrefSection title="Evidence log">
          <PrefRow label="Evidence log location"
            hint="Where Markdown evidence files are written. Local only."
            control={
              <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
                <input className="fermo-input fermo-mono" defaultValue="~/Fermo/evidence/" style={{ maxWidth: 280 }}/>
                <button className="fermo-btn fermo-btn-secondary fermo-btn-sm">Choose…</button>
                <button className="fermo-btn fermo-btn-ghost fermo-btn-sm">Reveal</button>
              </div>
            }/>
          <PrefRow label="Markdown export"
            hint="One file per session, named YYYY-MM-DD-<slug>.md."
            control={
              <Seg options={[{value:'session',label:'One file per session'},{value:'digest',label:'Monthly digest'}]} value="session" onChange={()=>{}}/>
            }/>
          <PrefRow label="Open evidence after session"
            hint="Reveals the new Markdown file when proof is saved."
            control={<div style={{ display: 'flex', alignItems: 'center', gap: 8 }}><Toggle on={false}/> <span style={{ fontSize: 12, color: 'var(--f-fg-2)' }}>Off</span></div>}/>
        </PrefSection>

        <PrefSection title="Privacy &amp; local data">
          <div style={{ padding: '14px 0', display: 'flex', gap: 10 }}>
            <FIcon name="hand.raised" size={14} style={{ color: 'var(--f-fg-2)', marginTop: 2 }}/>
            <div style={{ fontSize: 12.5, color: 'var(--f-fg-1)', lineHeight: 1.6, maxWidth: 640 }}>
              Fermo stores rooms, sessions, and evidence on this Mac. <b>No cloud sync</b> in v1. <b>No analytics</b>. <b>No AI calls</b> — paid or free. Helper-to-app communication uses a local socket only.
              Diagnostic logs below are written to <span className="fermo-mono">~/Fermo/logs/</span> and never leave your machine.
            </div>
          </div>
        </PrefSection>

        <PrefSection title="Developer diagnostics">
          <PrefRow label="Verbose helper logging"
            hint="Writes per-event records to ~/Fermo/logs/helper.log."
            control={<div style={{ display: 'flex', alignItems: 'center', gap: 8 }}><Toggle on={false}/> <span style={{ fontSize: 12, color: 'var(--f-fg-2)' }}>Off · default</span></div>}/>
          <PrefRow label="Signed-proof artifacts"
            hint="Keep on while verifying the spike. Stored next to logs."
            control={<div style={{ display: 'flex', alignItems: 'center', gap: 8 }}><Toggle on/> <span style={{ fontSize: 12, color: 'var(--f-fg-2)' }}>On</span></div>}/>
          <PrefRow label="Reveal logs folder"
            hint="Opens Finder at the diagnostics location."
            control={<button className="fermo-btn fermo-btn-secondary fermo-btn-sm"><FIcon name="arrow.up.right" size={11}/> Reveal in Finder</button>}/>
        </PrefSection>

        <div style={{ marginTop: 32, padding: 12, border: '1px dashed var(--f-line-2)', borderRadius: 8, display: 'flex', gap: 10, fontSize: 11.5, color: 'var(--f-fg-3)' }}>
          <FIcon name="info.circle" size={12} style={{ marginTop: 1 }}/>
          <span>Fermo v0.1.0/3 · pre-beta · not for distribution · signed development.</span>
        </div>
      </div>
    </div>
  </div>
);

Object.assign(window, { FermoEvidenceLog, FermoSystemHealth, FermoPreferences, Toggle });
