// Fermo — Start Contract flow + Preset picker
// Exposes: FermoStartContract, FermoPresetPicker

const FieldLabel = ({ children, hint }) => (
  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 6 }}>
    <span className="fermo-kv-label">{children}</span>
    {hint && <span style={{ fontSize: 10.5, color: 'var(--f-fg-3)', fontFamily: 'var(--f-font-mono)' }}>{hint}</span>}
  </div>
);

const DurationPicker = ({ value = '90 min' }) => (
  <div style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
    <input className="fermo-input fermo-mono" defaultValue={value} style={{ flex: 1 }}/>
    <div className="fermo-seg">
      {['25', '45', '60', '90', '120'].map(v => (
        <button key={v} className={v === '90' ? 'is-on' : ''}>{v}</button>
      ))}
    </div>
  </div>
);

const PresetCard = ({ icon, name, intent, allowed, blocked, rigor, mode = 'room', selected, compact }) => (
  <div style={{
    padding: compact ? 12 : 14,
    border: `1px solid ${selected ? 'oklch(0.74 0.09 168 / 0.5)' : 'var(--f-line-2)'}`,
    background: selected ? 'oklch(0.74 0.09 168 / 0.06)' : 'var(--f-bg-2)',
    borderRadius: 10,
    cursor: 'pointer',
    display: 'flex', flexDirection: 'column', gap: 10,
  }}>
    <div style={{ display: 'flex', alignItems: 'center', gap: 9 }}>
      <div style={{
        width: 28, height: 28, borderRadius: 7,
        background: 'var(--f-bg-3)',
        border: '1px solid var(--f-line-2)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        color: selected ? 'var(--f-ok)' : 'var(--f-fg-1)',
      }}>
        <FIcon name={icon} size={14}/>
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 13, fontWeight: 600 }}>{name}</div>
        <div style={{ fontSize: 11, color: 'var(--f-fg-3)' }}>{intent}</div>
      </div>
      {selected && <FIcon name="checkmark.circle.fill" size={14} style={{ color: 'var(--f-ok)' }}/>}
    </div>
    <div style={{ display: 'flex', flexDirection: 'column', gap: 4, fontSize: 11.5 }}>
      <div style={{ display: 'flex', gap: 6, alignItems: 'flex-start' }}>
        <FIcon name="checkmark" size={10} style={{ color: 'var(--f-ok)', marginTop: 3, flexShrink: 0 }}/>
        <span style={{ color: 'var(--f-fg-1)' }}><b style={{ color: 'var(--f-fg-0)', fontWeight: 600 }}>Allow </b>{allowed}</span>
      </div>
      <div style={{ display: 'flex', gap: 6, alignItems: 'flex-start' }}>
        <FIcon name="minus" size={10} style={{ color: 'var(--f-danger)', marginTop: 3, flexShrink: 0 }}/>
        <span style={{ color: 'var(--f-fg-1)' }}><b style={{ color: 'var(--f-fg-0)', fontWeight: 600 }}>Block </b>{blocked}</span>
      </div>
    </div>
    <div style={{ display: 'flex', alignItems: 'center', gap: 6, paddingTop: 6, borderTop: '1px dashed var(--f-line-2)' }}>
      <span style={{ fontSize: 10.5, color: 'var(--f-fg-3)', textTransform: 'uppercase', letterSpacing: 0.06 }}>Suggested rigor</span>
      <Chip><FIcon name={RIGOR_DEFS[rigor].icon} size={10}/> {RIGOR_DEFS[rigor].name}</Chip>
    </div>
  </div>
);

const PRESETS = [
  { id: 'writing', icon: 'square.and.pencil', name: 'Writing', intent: 'Long-form drafting.',
    allowed: 'docs, notes, reference', blocked: 'social, video, messaging', rigor: 'locked' },
  { id: 'coding', icon: 'doc.text', name: 'Coding', intent: 'Build, debug, ship.',
    allowed: 'IDE, docs, terminal, GitHub', blocked: 'social, video', rigor: 'locked' },
  { id: 'admin', icon: 'tray', name: 'Admin', intent: 'Email, bills, ops.',
    allowed: 'email, calendar, banking, docs', blocked: 'feeds, video', rigor: 'soft' },
  { id: 'planning', icon: 'target', name: 'Deep Planning', intent: 'Think slow on hard things.',
    allowed: 'notes, calendar, research', blocked: 'messaging, social, video', rigor: 'locked' },
  { id: 'custom', icon: 'plus', name: 'Custom', intent: 'Build a room from scratch.',
    allowed: 'nothing yet', blocked: 'nothing yet', rigor: 'soft' },
];

// ─────────────────────────────────────────────────────────────
// Preset picker (standalone screen — full grid)
// ─────────────────────────────────────────────────────────────
const FermoPresetPicker = () => (
  <div style={{ display: 'flex', flexDirection: 'column', height: '100%', overflow: 'hidden' }}>
    <FermoSectionHead
      title="Choose a preset"
      subtitle="Presets pre-fill a room and rigor. You can still override every field."
      right={<button className="fermo-btn fermo-btn-ghost fermo-btn-sm">Skip · build from scratch</button>}
    />
    <div style={{ flex: 1, overflow: 'auto', padding: '20px 22px 26px' }}>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 14 }}>
        {PRESETS.map((p, i) => (
          <PresetCard key={p.id} {...p} selected={i === 0}/>
        ))}
      </div>
    </div>
  </div>
);

// ─────────────────────────────────────────────────────────────
// Start Contract — single-panel flow with grouped sections
// ─────────────────────────────────────────────────────────────
const FermoStartContract = () => (
  <div style={{ display: 'flex', flexDirection: 'column', height: '100%', overflow: 'hidden' }}>
    <FermoSectionHead
      title="Start a contract"
      subtitle="One task. One outcome. One protected session."
      right={
        <>
          <button className="fermo-btn fermo-btn-ghost fermo-btn-sm">Save as preset</button>
          <button className="fermo-btn fermo-btn-secondary fermo-btn-sm">Cancel · <Kbd style={{ marginLeft: 4 }}>esc</Kbd></button>
        </>
      }
    />
    <div style={{ flex: 1, overflow: 'auto' }}>
      <div style={{
        maxWidth: 820, margin: '0 auto',
        padding: '26px 32px 32px',
        display: 'flex', flexDirection: 'column', gap: 22,
      }}>
        {/* 1 · TASK */}
        <div>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 8, marginBottom: 12 }}>
            <span style={{ fontSize: 10, fontWeight: 700, color: 'var(--f-ok)', fontFamily: 'var(--f-font-mono)' }}>01</span>
            <span style={{ fontSize: 14, fontWeight: 600 }}>What are you working on?</span>
          </div>
          <div>
            <FieldLabel>Task title</FieldLabel>
            <input className="fermo-input" style={{ height: 32, fontSize: 14, fontWeight: 500 }} defaultValue="Draft Q3 reliability memo"/>
          </div>
          <div style={{ marginTop: 14 }}>
            <FieldLabel hint="What changes if this session succeeds?">Intended outcome</FieldLabel>
            <textarea
              className="fermo-textarea"
              style={{ minHeight: 64 }}
              defaultValue="A complete first draft. Sections 1–3 written end to end, with one supporting graph plotted for §2. §4 left empty until I have Mira's error-budget numbers."
            />
          </div>
        </div>

        <hr className="fermo-hr"/>

        {/* 2 · ROOM */}
        <div>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 8, marginBottom: 12 }}>
            <span style={{ fontSize: 10, fontWeight: 700, color: 'var(--f-ok)', fontFamily: 'var(--f-font-mono)' }}>02</span>
            <span style={{ fontSize: 14, fontWeight: 600 }}>What rules apply?</span>
          </div>
          <FieldLabel>Start from preset</FieldLabel>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(5, 1fr)', gap: 8 }}>
            {PRESETS.map((p, i) => (
              <div key={p.id} style={{
                padding: '10px 10px',
                border: `1px solid ${i === 0 ? 'oklch(0.74 0.09 168 / 0.5)' : 'var(--f-line-2)'}`,
                background: i === 0 ? 'oklch(0.74 0.09 168 / 0.06)' : 'var(--f-bg-1)',
                borderRadius: 8, cursor: 'pointer',
                display: 'flex', flexDirection: 'column', gap: 6, alignItems: 'flex-start',
              }}>
                <FIcon name={p.icon} size={14} style={{ color: i === 0 ? 'var(--f-ok)' : 'var(--f-fg-1)' }}/>
                <div style={{ fontSize: 12.5, fontWeight: 600 }}>{p.name}</div>
                <div style={{ fontSize: 10.5, color: 'var(--f-fg-3)', lineHeight: 1.3 }}>{p.intent}</div>
              </div>
            ))}
          </div>

          <div style={{ marginTop: 18, display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 18 }}>
            <div>
              <FieldLabel>Mode</FieldLabel>
              <ModePicker value="room"/>
            </div>
            <div>
              <FieldLabel>Room</FieldLabel>
              <button className="fermo-btn fermo-btn-secondary" style={{ height: 32, width: '100%', justifyContent: 'space-between', padding: '0 12px' }}>
                <span style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                  <FIcon name="door.left.hand.closed" size={13} style={{ color: 'var(--f-fg-1)' }}/>
                  Deep Writing
                  <span style={{ fontSize: 11, color: 'var(--f-fg-3)' }}>· 14 allowed · 19 blocked</span>
                </span>
                <FIcon name="chevron.updown" size={11} style={{ color: 'var(--f-fg-2)' }}/>
              </button>
            </div>
          </div>
        </div>

        <hr className="fermo-hr"/>

        {/* 3 · DURATION + RIGOR */}
        <div>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 8, marginBottom: 12 }}>
            <span style={{ fontSize: 10, fontWeight: 700, color: 'var(--f-ok)', fontFamily: 'var(--f-font-mono)' }}>03</span>
            <span style={{ fontSize: 14, fontWeight: 600 }}>How protected?</span>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: '320px 1fr', gap: 22 }}>
            <div>
              <FieldLabel hint="Tab to enter custom">Duration</FieldLabel>
              <DurationPicker value="90 min"/>
              <div style={{ marginTop: 14 }}>
                <FieldLabel>Proof requirement</FieldLabel>
                <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
                  {[
                    { v: 'note', l: 'Short note',          d: 'A line or two when the timer ends.' },
                    { v: 'md',   l: 'Markdown evidence',   d: 'A full evidence note with sections.', on: true },
                    { v: 'link', l: 'File or link reference', d: 'Attach what was produced.' },
                  ].map(p => (
                    <label key={p.v} style={{
                      display: 'flex', alignItems: 'flex-start', gap: 9,
                      padding: '8px 10px', borderRadius: 7, cursor: 'pointer',
                      background: p.on ? 'oklch(0.74 0.09 168 / 0.06)' : 'transparent',
                      border: `1px solid ${p.on ? 'oklch(0.74 0.09 168 / 0.4)' : 'var(--f-line)'}`,
                    }}>
                      <div style={{
                        width: 14, height: 14, borderRadius: 3, marginTop: 1,
                        border: `1px solid ${p.on ? 'var(--f-ok)' : 'var(--f-line-3)'}`,
                        background: p.on ? 'var(--f-ok)' : 'transparent',
                        display: 'flex', alignItems: 'center', justifyContent: 'center',
                        flexShrink: 0,
                      }}>
                        {p.on && <FIcon name="checkmark" size={9} style={{ color: '#06120c' }}/>}
                      </div>
                      <div>
                        <div style={{ fontSize: 12.5, fontWeight: 500 }}>{p.l}</div>
                        <div style={{ fontSize: 11, color: 'var(--f-fg-3)' }}>{p.d}</div>
                      </div>
                    </label>
                  ))}
                </div>
              </div>
            </div>
            <div>
              <FieldLabel>Rigor</FieldLabel>
              <RigorPicker value="locked"/>
              <div style={{ marginTop: 12, padding: 11, background: 'var(--f-bg-2)', border: '1px solid var(--f-line)', borderRadius: 8, display: 'flex', gap: 9 }}>
                <FIcon name="info.circle" size={13} style={{ color: 'var(--f-fg-2)', marginTop: 1 }}/>
                <div style={{ fontSize: 11.5, color: 'var(--f-fg-1)', lineHeight: 1.5 }}>
                  Locked means there is no normal stop button during the session. Fermo cannot prevent every workaround on macOS — Locked is honesty against your own first impulse, not tamper-proofing.
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* FOOTER */}
        <div style={{
          position: 'sticky', bottom: 0, marginTop: 4,
          background: 'linear-gradient(180deg, transparent, var(--f-bg-1) 30%)',
          paddingTop: 14, paddingBottom: 4,
          display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        }}>
          <div style={{ fontSize: 11.5, color: 'var(--f-fg-2)', display: 'flex', alignItems: 'center', gap: 7 }}>
            <FIcon name="checkmark.seal" size={12} style={{ color: 'var(--f-ok)' }}/>
            Ready to protect · 14 sites + 4 apps will be enforced
          </div>
          <div style={{ display: 'flex', gap: 8 }}>
            <button className="fermo-btn fermo-btn-secondary">Save draft</button>
            <button className="fermo-btn fermo-btn-primary fermo-btn-lg">
              <FIcon name="play.fill" size={11}/> Start Contract · 90 min
              <span style={{ marginLeft: 6, opacity: 0.7, fontFamily: 'var(--f-font-mono)', fontSize: 11 }}>⌘↵</span>
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
);

Object.assign(window, { FermoStartContract, FermoPresetPicker, PRESETS, PresetCard });
