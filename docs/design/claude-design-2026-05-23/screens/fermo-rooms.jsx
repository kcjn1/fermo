// Fermo — Rooms list + detail, Blocklist editor, Focus Room builder
// Exposes: FermoRooms, FermoBlocklistEditor, FermoRoomBuilder

const ROOMS = [
  { id: 'deep',    icon: 'square.and.pencil', name: 'Deep Writing',   sub: '14 allowed · 19 blocked', dur: '90 min', rigor: 'locked',    used: 'Apr 12', mode: 'room' },
  { id: 'coding',  icon: 'doc.text',          name: 'Coding',         sub: 'Allow IDE / GitHub / docs', dur: '120 min', rigor: 'locked', used: 'Apr 10', mode: 'room' },
  { id: 'admin',   icon: 'tray',              name: 'Admin',          sub: 'Banking + email allowed', dur: '45 min', rigor: 'soft', used: 'Apr 11', mode: 'block' },
  { id: 'plan',    icon: 'target',            name: 'Deep Planning',  sub: 'Notes + calendar + research', dur: '60 min', rigor: 'locked', used: 'Apr 06', mode: 'room' },
  { id: 'block',   icon: 'minus.circle',      name: 'Feeds blocklist',sub: '23 distractions blocked', dur: '60 min', rigor: 'soft', used: 'Mar 28', mode: 'block' },
];

// ─────────────────────────────────────────────────────────────
// Rooms — list + detail (master-detail)
// ─────────────────────────────────────────────────────────────
const FermoRooms = ({ selectedId = 'deep' }) => {
  const allow = [
    { kind: 'site', name: 'notion.so' },
    { kind: 'site', name: 'docs.google.com' },
    { kind: 'site', name: 'are.na' },
    { kind: 'site', name: 'developer.apple.com', note: '+ subdomains' },
    { kind: 'app',  name: 'Notes' },
    { kind: 'app',  name: 'Drafts' },
    { kind: 'app',  name: 'Pages',   note: 'com.apple.iWork.Pages' },
    { kind: 'app',  name: 'Preview', note: 'com.apple.Preview' },
  ];
  const block = [
    { kind: 'site', name: 'reddit.com' },
    { kind: 'site', name: 'youtube.com' },
    { kind: 'site', name: 'x.com' },
    { kind: 'app',  name: 'Discord', note: 'com.hnc.Discord' },
    { kind: 'app',  name: 'Messages' },
    { kind: 'app',  name: 'Slack' },
    { kind: 'app',  name: 'Calculator', note: 'com.apple.calculator · spike example' },
  ];
  return (
    <div style={{ display: 'flex', height: '100%', minHeight: 0 }}>
      {/* Master list */}
      <div style={{ width: 256, flexShrink: 0, borderRight: '1px solid var(--f-line)', display: 'flex', flexDirection: 'column' }}>
        <div style={{ padding: '12px 14px 10px', display: 'flex', alignItems: 'center', justifyContent: 'space-between', borderBottom: '1px solid var(--f-line)' }}>
          <div style={{ fontSize: 13, fontWeight: 600 }}>Rooms</div>
          <div style={{ display: 'flex', gap: 4 }}>
            <button className="fermo-btn fermo-btn-ghost fermo-btn-sm" style={{ width: 20, padding: 0 }}><FIcon name="plus" size={12}/></button>
            <button className="fermo-btn fermo-btn-ghost fermo-btn-sm" style={{ width: 20, padding: 0 }}><FIcon name="ellipsis" size={12}/></button>
          </div>
        </div>
        <div style={{ padding: '8px 10px', flex: 1, overflow: 'auto', display: 'flex', flexDirection: 'column', gap: 2 }}>
          {ROOMS.map(r => {
            const on = r.id === selectedId;
            return (
              <div key={r.id} style={{
                padding: '8px 9px', borderRadius: 6, cursor: 'pointer',
                display: 'flex', alignItems: 'center', gap: 9,
                background: on ? 'oklch(0.74 0.09 168 / 0.14)' : 'transparent',
              }}>
                <FIcon name={r.icon} size={13} style={{ color: on ? 'var(--f-ok)' : 'var(--f-fg-2)' }}/>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontSize: 12.5, fontWeight: 500, color: on ? 'var(--f-fg-0)' : 'var(--f-fg-1)' }}>{r.name}</div>
                  <div style={{ fontSize: 10.5, color: 'var(--f-fg-3)', fontFamily: 'var(--f-font-mono)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{r.mode === 'room' ? 'Focus Room' : 'Blocklist'} · {r.dur}</div>
                </div>
                {on && <FIcon name="chevron.right" size={10} style={{ color: 'var(--f-fg-3)' }}/>}
              </div>
            );
          })}
        </div>
        <div style={{ padding: '8px 10px', borderTop: '1px solid var(--f-line)', display: 'flex', flexDirection: 'column', gap: 4 }}>
          <button className="fermo-btn fermo-btn-ghost" style={{ width: '100%', justifyContent: 'flex-start' }}><FIcon name="plus" size={11}/> New room</button>
          <button className="fermo-btn fermo-btn-ghost" style={{ width: '100%', justifyContent: 'flex-start' }}><FIcon name="arrow.up.right" size={11}/> Import room…</button>
        </div>
      </div>

      {/* Detail */}
      <div style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column' }}>
        <FermoSectionHead
          title="Deep Writing"
          subtitle="Drafting long-form, distraction-free. Allow only what you read or write."
          right={
            <>
              <Chip><FIcon name="door.left.hand.closed" size={10}/> Focus Room</Chip>
              <button className="fermo-btn fermo-btn-ghost fermo-btn-sm"><FIcon name="square.and.pencil" size={11}/> Edit</button>
              <button className="fermo-btn fermo-btn-secondary fermo-btn-sm"><FIcon name="play.fill" size={10}/> Use this room</button>
            </>
          }
        />
        <div style={{ flex: 1, overflow: 'auto', padding: '18px 22px 26px', display: 'flex', flexDirection: 'column', gap: 20 }}>
          {/* Defaults */}
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 1, background: 'var(--f-line)', border: '1px solid var(--f-line)', borderRadius: 10, overflow: 'hidden' }}>
            {[
              { l: 'Mode',           v: 'Focus Room', icn: 'door.left.hand.closed' },
              { l: 'Default duration', v: '90 min',   icn: 'clock' },
              { l: 'Default rigor',  v: 'Locked',     icn: 'lock' },
              { l: 'Default proof',  v: 'Markdown',   icn: 'doc.text' },
            ].map(d => (
              <div key={d.l} style={{ padding: '12px 14px', background: 'var(--f-bg-2)' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 10.5, fontWeight: 600, color: 'var(--f-fg-3)', textTransform: 'uppercase', letterSpacing: 0.06 }}>
                  <FIcon name={d.icn} size={10}/> {d.l}
                </div>
                <div style={{ fontSize: 14, fontWeight: 600, marginTop: 4 }}>{d.v}</div>
              </div>
            ))}
          </div>

          {/* Allowed */}
          <RoomListSection
            title="Allowed websites"
            icon="globe"
            tone="ok"
            count={`${allow.filter(a => a.kind === 'site').length} sites`}
            items={allow.filter(a => a.kind === 'site')}
            addLabel="Add domain…"
          />
          <RoomListSection
            title="Allowed apps"
            icon="app.fill"
            tone="ok"
            count={`${allow.filter(a => a.kind === 'app').length} apps`}
            items={allow.filter(a => a.kind === 'app')}
            addLabel="Add app…"
          />

          {/* Blocked exceptions */}
          <RoomListSection
            title="Blocked exceptions"
            icon="minus.circle"
            tone="danger"
            count={`${block.length} rules`}
            subtitle="Even when 'Allow all the rest' is on, these stay blocked."
            items={block}
            addLabel="Add rule…"
          />

          {/* Footer actions */}
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', paddingTop: 6 }}>
            <div style={{ fontSize: 11.5, color: 'var(--f-fg-3)' }}>
              Created Mar 02 · last edited Apr 09 · used 23 sessions
            </div>
            <div style={{ display: 'flex', gap: 8 }}>
              <button className="fermo-btn fermo-btn-ghost"><FIcon name="copy" size={11}/> Duplicate</button>
              <button className="fermo-btn fermo-btn-secondary"><FIcon name="arrow.up.right" size={11}/> Export…</button>
              <button className="fermo-btn fermo-btn-danger"><FIcon name="trash" size={11}/> Delete room</button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

const RoomListSection = ({ title, icon, tone, count, items = [], subtitle, addLabel, locked }) => {
  const c = tone === 'ok' ? 'var(--f-ok)' : tone === 'danger' ? 'var(--f-danger)' : 'var(--f-fg-2)';
  return (
    <div>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 8 }}>
        <div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 7 }}>
            <FIcon name={icon} size={12} style={{ color: c }}/>
            <span style={{ fontSize: 13, fontWeight: 600 }}>{title}</span>
            <span style={{ fontSize: 11, color: 'var(--f-fg-3)', fontFamily: 'var(--f-font-mono)' }}>· {count}</span>
          </div>
          {subtitle && <div style={{ fontSize: 11.5, color: 'var(--f-fg-2)', marginTop: 3 }}>{subtitle}</div>}
        </div>
        {!locked && <button className="fermo-btn fermo-btn-secondary fermo-btn-sm"><FIcon name="plus" size={10}/> {addLabel}</button>}
      </div>
      <div className="fermo-card" style={{ overflow: 'hidden' }}>
        <AllowBlockList kind={tone === 'ok' ? 'allow' : 'block'} items={items} locked={locked}/>
      </div>
    </div>
  );
};

// ─────────────────────────────────────────────────────────────
// Blocklist editor — domains + apps, with validation states
// ─────────────────────────────────────────────────────────────
const FermoBlocklistEditor = ({ locked }) => {
  const domains = [
    { kind: 'site', name: 'reddit.com', note: 'exact + subdomains' },
    { kind: 'site', name: '*.youtube.com', note: 'wildcard subdomains' },
    { kind: 'site', name: 'x.com' },
    { kind: 'site', name: 'news.ycombinator.com' },
    { kind: 'site', name: 'instagram.com', disabled: true },
    { kind: 'site', name: 'tiktok..com', invalid: true, note: 'double dot' },
  ];
  const apps = [
    { kind: 'app', name: 'Discord', note: 'com.hnc.Discord' },
    { kind: 'app', name: 'Messages', note: 'com.apple.MobileSMS' },
    { kind: 'app', name: 'Slack' },
    { kind: 'app', name: 'Calculator', note: 'spike example · pause on start' },
    { kind: 'app', name: 'Steam', disabled: true, note: 'com.valvesoftware.steam' },
  ];
  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
      <FermoSectionHead
        title="Blocklist · Feeds blocklist"
        subtitle="Block selected distractions, allow the rest."
        right={
          <>
            <button className="fermo-btn fermo-btn-ghost fermo-btn-sm">Discard</button>
            <button className="fermo-btn fermo-btn-secondary fermo-btn-sm" disabled={locked}>Save</button>
          </>
        }
      />
      {locked && (
        <div style={{ padding: '0 22px', marginTop: 16 }}>
          <PermissionAlert
            tone="warn" icon="lock"
            title="Editing is paused during an active Locked session"
            body="You can review rules but you cannot weaken the blocklist while the session is running. Editing will re-enable when the timer ends."
          />
        </div>
      )}
      <div style={{ flex: 1, overflow: 'auto', padding: '18px 22px 26px', display: 'flex', flexDirection: 'column', gap: 20 }}>
        {/* Empty state if no rules */}
        {/* Domain rules */}
        <div>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 8 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 7 }}>
              <FIcon name="globe" size={12} style={{ color: 'var(--f-danger)' }}/>
              <span style={{ fontSize: 13, fontWeight: 600 }}>Domain rules</span>
              <span style={{ fontSize: 11, color: 'var(--f-fg-3)', fontFamily: 'var(--f-font-mono)' }}>· 6 rules · 1 invalid · 1 off</span>
            </div>
            <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
              <Seg options={[{value:'exact',label:'Exact'},{value:'wild',label:'Wildcard'}]} value="wild" onChange={()=>{}}/>
              <button className="fermo-btn fermo-btn-secondary fermo-btn-sm" disabled={locked}><FIcon name="plus" size={10}/> Add domain</button>
            </div>
          </div>
          <div className="fermo-card" style={{ overflow: 'hidden' }}>
            {/* Add row */}
            {!locked && (
              <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '8px 10px', borderBottom: '1px solid var(--f-line)', background: 'var(--f-bg-3)' }}>
                <FIcon name="plus" size={11} style={{ color: 'var(--f-fg-3)' }}/>
                <input className="fermo-input fermo-mono" placeholder="example.com  ·  *.example.com" style={{ height: 24, flex: 1, background: 'transparent', border: 'none', boxShadow: 'none' }}/>
                <Kbd>↵</Kbd>
              </div>
            )}
            <AllowBlockList kind="block" items={domains} locked={locked}/>
          </div>
          {/* Validation hint */}
          <div style={{ marginTop: 8, display: 'flex', alignItems: 'center', gap: 7, fontSize: 11.5, color: 'var(--f-danger)' }}>
            <FIcon name="exclamationmark.triangle" size={11}/>
            <span><b>tiktok..com</b> — domain has a double dot. Fix or remove before this session can be protected.</span>
          </div>
        </div>

        {/* App rules */}
        <div>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 8 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 7 }}>
              <FIcon name="app.fill" size={12} style={{ color: 'var(--f-danger)' }}/>
              <span style={{ fontSize: 13, fontWeight: 600 }}>App rules</span>
              <span style={{ fontSize: 11, color: 'var(--f-fg-3)', fontFamily: 'var(--f-font-mono)' }}>· 5 rules · 1 off</span>
            </div>
            <button className="fermo-btn fermo-btn-secondary fermo-btn-sm" disabled={locked}><FIcon name="plus" size={10}/> Choose from /Applications…</button>
          </div>
          <div className="fermo-card" style={{ overflow: 'hidden' }}>
            <AllowBlockList kind="block" items={apps} locked={locked}/>
          </div>
        </div>
      </div>
    </div>
  );
};

// ─────────────────────────────────────────────────────────────
// Focus Room builder — allowlist-first
// ─────────────────────────────────────────────────────────────
const FermoRoomBuilder = () => {
  const allowSites = [
    { kind: 'site', name: 'notion.so' },
    { kind: 'site', name: 'docs.google.com' },
    { kind: 'site', name: 'developer.apple.com', note: '+ subdomains' },
  ];
  const allowApps = [
    { kind: 'app', name: 'Notes', note: 'com.apple.Notes' },
    { kind: 'app', name: 'Drafts' },
  ];
  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
      <FermoSectionHead
        title="New Focus Room"
        subtitle="What belongs in this work room?"
        right={
          <>
            <button className="fermo-btn fermo-btn-ghost fermo-btn-sm">Cancel</button>
            <button className="fermo-btn fermo-btn-primary fermo-btn-sm">Save room</button>
          </>
        }
      />
      <div style={{ flex: 1, overflow: 'auto', padding: '22px 28px 30px', maxWidth: 880, width: '100%', alignSelf: 'flex-start' }}>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16 }}>
          <div>
            <FieldLabel>Room name</FieldLabel>
            <input className="fermo-input" defaultValue="Reliability writing"/>
          </div>
          <div>
            <FieldLabel hint="optional">Description</FieldLabel>
            <input className="fermo-input" defaultValue="For SRE memos and post-mortems. Calm rules."/>
          </div>
          <div>
            <FieldLabel>Default duration</FieldLabel>
            <DurationPicker value="90 min"/>
          </div>
          <div>
            <FieldLabel>Default rigor</FieldLabel>
            <Seg options={[{value:'soft',label:'Soft'},{value:'locked',label:'Locked'},{value:'emergency',label:'Emergency'}]} value="locked" onChange={()=>{}}/>
          </div>
        </div>

        <div style={{ marginTop: 22, padding: 12, border: '1px solid var(--f-line)', background: 'var(--f-bg-2)', borderRadius: 8, display: 'flex', gap: 10 }}>
          <FIcon name="info.circle" size={13} style={{ color: 'var(--f-info)', marginTop: 2 }}/>
          <div style={{ fontSize: 12, color: 'var(--f-fg-1)', lineHeight: 1.55 }}>
            A Focus Room <b>allows</b> what belongs and treats everything else as off-limits. Add a few things on purpose — don't try to allow everything.
          </div>
        </div>

        <hr className="fermo-hr" style={{ margin: '22px 0' }}/>

        <RoomListSection title="Allowed websites" icon="globe" tone="ok" count={`${allowSites.length} sites`}
          items={allowSites} addLabel="Add domain…"/>
        <div style={{ height: 16 }}/>
        <RoomListSection title="Allowed apps" icon="app.fill" tone="ok" count={`${allowApps.length} apps`}
          items={allowApps} addLabel="Add app…"/>
        <div style={{ height: 16 }}/>
        <RoomListSection title="Blocked exceptions"
          subtitle="Optional. Things to block even when the rest is allowed by the room."
          icon="minus.circle" tone="danger" count="0 rules" items={[]} addLabel="Add exception…"/>

        <div style={{ marginTop: 22, padding: 14, border: '1px solid var(--f-line)', borderRadius: 10, background: 'var(--f-bg-2)' }}>
          <div style={{ fontSize: 12, fontWeight: 600, marginBottom: 4 }}>Preview</div>
          <div style={{ fontSize: 11.5, color: 'var(--f-fg-2)', lineHeight: 1.55 }}>
            When this room runs, Fermo will allow <span className="fermo-mono" style={{ color: 'var(--f-ok)' }}>notion.so</span>, <span className="fermo-mono" style={{ color: 'var(--f-ok)' }}>docs.google.com</span>, <span className="fermo-mono" style={{ color: 'var(--f-ok)' }}>developer.apple.com</span>, plus Notes and Drafts. Everything else on the web and in /Applications will be blocked or paused for 90 min.
          </div>
        </div>
      </div>
    </div>
  );
};

Object.assign(window, { FermoRooms, FermoBlocklistEditor, FermoRoomBuilder, ROOMS, RoomListSection });
