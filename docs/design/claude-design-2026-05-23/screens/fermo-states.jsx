// Fermo — Empty / Error / Permission state gallery
// Exposes: FermoStatesGallery

const StateCard = ({ icon, tone = 'muted', title, body, primary, secondary, last, big, illustration }) => {
  const c = tone === 'ok' ? 'var(--f-ok)' : tone === 'warn' ? 'var(--f-warn)' : tone === 'info' ? 'var(--f-info)' : tone === 'danger' ? 'var(--f-danger)' : 'var(--f-fg-2)';
  const bg = tone === 'ok' ? 'var(--f-ok-bg)' : tone === 'warn' ? 'var(--f-warn-bg)' : tone === 'info' ? 'var(--f-info-bg)' : tone === 'danger' ? 'var(--f-danger-bg)' : 'var(--f-muted-bg)';
  return (
    <div className="fermo-card" style={{
      padding: big ? 22 : 18,
      display: 'flex', flexDirection: 'column', gap: 12,
      height: '100%',
    }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
        <div style={{
          width: 30, height: 30, borderRadius: 7,
          background: bg, border: `1px solid ${c === 'var(--f-fg-2)' ? 'var(--f-line-2)' : c}`,
          display: 'flex', alignItems: 'center', justifyContent: 'center', color: c,
        }}>
          <FIcon name={icon} size={15}/>
        </div>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontSize: 13, fontWeight: 600 }}>{title}</div>
          {last && <div style={{ fontSize: 11, color: 'var(--f-fg-3)', fontFamily: 'var(--f-font-mono)' }}>{last}</div>}
        </div>
      </div>
      {illustration}
      <div style={{ fontSize: 12.5, color: 'var(--f-fg-1)', lineHeight: 1.55, flex: 1 }}>
        {body}
      </div>
      {(primary || secondary) && (
        <div style={{ display: 'flex', gap: 8 }}>
          {primary && <button className="fermo-btn fermo-btn-primary fermo-btn-sm">{primary}</button>}
          {secondary && <button className="fermo-btn fermo-btn-secondary fermo-btn-sm">{secondary}</button>}
        </div>
      )}
    </div>
  );
};

// Small visual: empty-state stripe placeholder
const EmptyStripe = ({ h = 60, label }) => (
  <div className="fermo-stripe" style={{
    height: h, borderRadius: 6, border: '1px dashed var(--f-line-2)',
    display: 'flex', alignItems: 'center', justifyContent: 'center',
    fontFamily: 'var(--f-font-mono)', fontSize: 10.5, color: 'var(--f-fg-3)',
    textTransform: 'uppercase', letterSpacing: 0.08,
  }}>{label}</div>
);

const FermoStatesGallery = () => (
  <div style={{
    width: '100%', height: '100%', overflow: 'auto',
    background: 'var(--f-bg-1)', color: 'var(--f-fg-0)',
    fontFamily: 'var(--f-font)',
    padding: '40px 48px',
  }} className="fermo">
    <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', marginBottom: 20 }}>
      <div>
        <div style={{ fontSize: 12, fontWeight: 600, color: 'var(--f-fg-3)', textTransform: 'uppercase', letterSpacing: 0.06 }}>States</div>
        <div style={{ fontSize: 24, fontWeight: 600, marginTop: 4, letterSpacing: 0 }}>Empty · permission · degraded · error</div>
        <div style={{ fontSize: 13, color: 'var(--f-fg-2)', marginTop: 8, maxWidth: 720, lineHeight: 1.55 }}>
          These are how each surface looks when something is missing, unverified, or broken. Copy is honest, action is one click away, and nothing pretends to enforce what it cannot.
        </div>
      </div>
    </div>

    {/* ─── Group: First-run empties ─── */}
    <div style={{ fontSize: 11, fontWeight: 700, color: 'var(--f-fg-3)', textTransform: 'uppercase', letterSpacing: 0.06, margin: '28px 0 12px' }}>First-run · empty surfaces</div>
    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 14 }}>
      <StateCard
        icon="square.grid.2x2" tone="muted"
        title="No rooms yet"
        illustration={<EmptyStripe label="Room list · empty"/>}
        body={<>A room is a saved set of allowed websites and apps, with default duration and rigor. Start from a preset — Writing, Coding, Admin, Deep Planning — or build one yourself.</>}
        primary="Add your first room" secondary="Use a preset"
      />
      <StateCard
        icon="play.fill" tone="muted"
        title="No active session"
        illustration={<EmptyStripe label="Active session · empty"/>}
        body={<>You haven't started a contract today. When you do, this screen turns into a protected workspace with what is being enforced and how much time remains.</>}
        primary="Start a contract" secondary="Browse presets"
      />
      <StateCard
        icon="list.bullet.clipboard" tone="muted"
        title="Evidence log is empty"
        illustration={<EmptyStripe label="Evidence · empty"/>}
        body={<>Sessions write a small Markdown file each. Once you have a few, this becomes a calm, searchable work ledger — kept locally on this Mac.</>}
        primary="Start a contract"
      />
    </div>

    {/* ─── Group: Permission ─── */}
    <div style={{ fontSize: 11, fontWeight: 700, color: 'var(--f-fg-3)', textTransform: 'uppercase', letterSpacing: 0.06, margin: '28px 0 12px' }}>Needs approval · macOS permissions</div>
    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 14 }}>
      <StateCard
        icon="network" tone="info"
        title="Network Extension not approved"
        last="checked 11s ago · System Settings needed"
        body={<>Without approval, Fermo can't filter network traffic. Sessions will still start, but website blocking will be inactive and Fermo will mark them <FStatus tone="warn">Degraded</FStatus> in the evidence log.</>}
        primary="Open System Settings" secondary="Show me how"
      />
      <StateCard
        icon="externaldrive" tone="info"
        title="Helper not approved"
        last="never registered"
        body={<>The helper runs as a login item and keeps protection alive after the main app quits. macOS asks you to approve it once.</>}
        primary="Approve helper" secondary="Open Login Items"
      />
      <StateCard
        icon="lock.shield" tone="info"
        title="System Extension waiting"
        last="loaded · pending approval"
        body={<>macOS has loaded the extension but is waiting for you to allow it in System Settings → Privacy &amp; Security. Click Allow and return here.</>}
        primary="Open Privacy &amp; Security"
      />
    </div>

    {/* ─── Group: Degraded / partial ─── */}
    <div style={{ fontSize: 11, fontWeight: 700, color: 'var(--f-fg-3)', textTransform: 'uppercase', letterSpacing: 0.06, margin: '28px 0 12px' }}>Degraded · partial enforcement</div>
    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 14 }}>
      <StateCard
        icon="exclamationmark.triangle" tone="warn"
        title="Content filter unavailable"
        last="last seen 4m ago"
        body={<>The Network Extension stopped responding. Fermo can still pause apps and record evidence, but website blocking is offline until the next launch.</>}
        primary="Restart filter" secondary="Run diagnostics"
      />
      <StateCard
        icon="app.dashed" tone="warn"
        title="App interruption is degraded"
        last="Firefox bundle id pending"
        body={<>One app could not be paused: <b>Firefox</b>. The bundle id resolved but the helper got back a non-zero code. The session is still running — flagged Degraded.</>}
        primary="Quit Firefox" secondary="Recheck"
      />
      <StateCard
        icon="hourglass" tone="warn"
        title="Active session expired without proof"
        last="ended 14:48 · 12m ago"
        body={<>The timer ran out and the window is gone. Record what happened so this session lands in the evidence log instead of staying half-open.</>}
        primary="Record proof" secondary="Mark needs evidence"
      />
    </div>

    {/* ─── Group: Unverified manual checks ─── */}
    <div style={{ fontSize: 11, fontWeight: 700, color: 'var(--f-fg-3)', textTransform: 'uppercase', letterSpacing: 0.06, margin: '28px 0 12px' }}>Unverified · honest gaps</div>
    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 14 }}>
      <StateCard
        icon="arrow.clockwise" tone="warn"
        title="Reboot restore unverified"
        last="last checked · never"
        body={<>Fermo could not confirm helper restore after a full restart and login. Until the manual reboot test passes, treat post-reboot protection as best-effort.</>}
        secondary="Open checklist"
      />
      <StateCard
        icon="globe" tone="warn"
        title="Firefox not checked"
        last="last checked · never"
        body={<>Website blocking behaviour in Firefox is not verified for this build. Other browsers (Safari, Chrome) report ready.</>}
        secondary="Run Firefox check"
      />
      <StateCard
        icon="eye.slash" tone="warn"
        title="Private / incognito windows unverified"
        last="last checked · never"
        body={<>Block behaviour in private and incognito windows is pending. Add this to your manual run before any beta claim.</>}
        secondary="Add to checklist"
      />
    </div>

    {/* ─── Group: Real errors ─── */}
    <div style={{ fontSize: 11, fontWeight: 700, color: 'var(--f-fg-3)', textTransform: 'uppercase', letterSpacing: 0.06, margin: '28px 0 12px' }}>Errors · real failures</div>
    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 14 }}>
      <StateCard
        icon="xmark.circle" tone="danger"
        title="Helper state is stale"
        last="last sync 38m ago"
        body={<>The helper is running but it has not updated its shared state in 38 minutes. Sessions may not record. Restart the helper to clear this.</>}
        primary="Restart helper" secondary="Open diagnostics"
      />
      <StateCard
        icon="tray.full" tone="danger"
        title="App Group misconfigured"
        last="bundle group id mismatch"
        body={<>The helper and the main app are reading different shared containers. This is a build-config issue: <span className="fermo-mono">group.io.toolary.fermo</span> is missing from one of the targets.</>}
        primary="Copy diagnostic ID" secondary="Reveal logs"
      />
    </div>

    {/* Microcopy reminder */}
    <div style={{ marginTop: 32, padding: 16, border: '1px solid var(--f-line)', borderRadius: 10, background: 'var(--f-bg-2)' }}>
      <div style={{ fontSize: 11, fontWeight: 700, color: 'var(--f-fg-3)', textTransform: 'uppercase', letterSpacing: 0.06, marginBottom: 10 }}>Microcopy reference</div>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
        <div>
          <div style={{ fontSize: 11.5, color: 'var(--f-ok)', fontWeight: 600, marginBottom: 6 }}>Use</div>
          <ul style={{ margin: 0, paddingLeft: 18, fontSize: 12.5, color: 'var(--f-fg-1)', lineHeight: 1.7 }}>
            <li>"This session is protected."</li>
            <li>"System protection needs approval."</li>
            <li>"Record what happened."</li>
            <li>"This check is unverified."</li>
            <li>"Fermo could not confirm helper restore after reboot."</li>
          </ul>
        </div>
        <div>
          <div style={{ fontSize: 11.5, color: 'var(--f-danger)', fontWeight: 600, marginBottom: 6 }}>Avoid</div>
          <ul style={{ margin: 0, paddingLeft: 18, fontSize: 12.5, color: 'var(--f-fg-2)', lineHeight: 1.7, textDecoration: 'line-through' }}>
            <li>"Win your focus."</li>
            <li>"Never get distracted again."</li>
            <li>"Impossible to bypass."</li>
            <li>"Productivity score."</li>
            <li>"Streak."</li>
          </ul>
        </div>
      </div>
    </div>
  </div>
);

Object.assign(window, { FermoStatesGallery, StateCard });
