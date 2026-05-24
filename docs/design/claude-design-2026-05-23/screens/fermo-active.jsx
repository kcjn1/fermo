// Fermo — Active session screen, Break Glass dialog, Proof capture
// Exposes: FermoActiveSession, FermoBreakGlass, FermoProofCapture

// ─────────────────────────────────────────────────────────────
// Active session — tighter, focused
// ─────────────────────────────────────────────────────────────
const FermoActiveSession = ({ rigor = 'locked', degraded = false }) => {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%', overflow: 'hidden' }}>
      <ActiveHeader
        task="Draft Q3 reliability memo"
        outcome="A complete first draft. Sections 1–3 written end to end, with one supporting graph plotted for §2."
        remaining="00:42:18"
        total="1:30:00"
        rigor={rigor}
        room="Deep Writing"
        mode="room"
        protectedCount="13 sites · 4 apps"
      />

      {degraded && (
        <div style={{ padding: '12px 22px 0' }}>
          <PermissionAlert
            tone="warn" icon="exclamationmark.triangle"
            title="App interruption is partial"
            body="Firefox could not be paused. The session is still running but one path is unprotected."
            primary="Recheck"
          />
        </div>
      )}

      <div style={{ flex: 1, overflow: 'auto', padding: '18px 22px 22px', display: 'grid', gridTemplateColumns: '1.4fr 1fr', gap: 20, alignContent: 'start' }}>
        {/* LEFT: What's being protected + note pad */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
          {/* Protected list */}
          <div className="fermo-card" style={{ overflow: 'hidden' }}>
            <div style={{ padding: '12px 16px', display: 'flex', alignItems: 'center', justifyContent: 'space-between', borderBottom: '1px solid var(--f-line)' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <FIcon name="lock.shield" size={13} style={{ color: 'var(--f-ok)' }}/>
                <span style={{ fontSize: 12.5, fontWeight: 600 }}>What is being protected</span>
              </div>
              <button className="fermo-btn fermo-btn-ghost fermo-btn-sm">View room rules <FIcon name="arrow.up.right" size={10}/></button>
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 1, background: 'var(--f-line)' }}>
              <div style={{ padding: '12px 16px', background: 'var(--f-bg-2)' }}>
                <div style={{ fontSize: 10.5, fontWeight: 600, color: 'var(--f-fg-3)', textTransform: 'uppercase', letterSpacing: 0.06, display: 'flex', alignItems: 'center', gap: 6, marginBottom: 8 }}>
                  <FIcon name="globe" size={10}/> Blocked domains · 13
                </div>
                <div style={{ display: 'flex', flexWrap: 'wrap', gap: 5 }}>
                  {['reddit.com','youtube.com','x.com','news.ycombinator.com','instagram.com','tiktok.com','facebook.com','linkedin.com','+5 more'].map(d => (
                    <Chip key={d} mono>{d}</Chip>
                  ))}
                </div>
              </div>
              <div style={{ padding: '12px 16px', background: 'var(--f-bg-2)' }}>
                <div style={{ fontSize: 10.5, fontWeight: 600, color: 'var(--f-fg-3)', textTransform: 'uppercase', letterSpacing: 0.06, display: 'flex', alignItems: 'center', gap: 6, marginBottom: 8 }}>
                  <FIcon name="app.fill" size={10}/> Paused apps · 4
                </div>
                <div style={{ display: 'flex', flexDirection: 'column', gap: 5, fontSize: 12 }}>
                  {[
                    { n: 'Messages', s: 'paused' },
                    { n: 'Discord',  s: 'paused' },
                    { n: 'Slack',    s: 'paused' },
                    { n: 'Calculator', s: 'paused', note: 'spike example' },
                  ].map(a => (
                    <div key={a.n} style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                      <FIcon name="pause.fill" size={9} style={{ color: 'var(--f-ok)' }}/>
                      <span>{a.n}</span>
                      {a.note && <span style={{ fontSize: 10.5, color: 'var(--f-fg-3)', fontFamily: 'var(--f-font-mono)' }}>· {a.note}</span>}
                    </div>
                  ))}
                </div>
              </div>
            </div>
            <div style={{ padding: '10px 16px', display: 'flex', alignItems: 'center', justifyContent: 'space-between', borderTop: '1px solid var(--f-line)', background: 'var(--f-bg-1)' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 7, fontSize: 11.5 }}>
                <FIcon name="externaldrive.badge.checkmark" size={12} style={{ color: 'var(--f-ok)' }}/>
                <span style={{ color: 'var(--f-fg-2)' }}>Helper</span>
                <span style={{ color: 'var(--f-ok)', fontWeight: 600 }}>persisting · pid 4128</span>
                <span style={{ color: 'var(--f-fg-3)', fontFamily: 'var(--f-font-mono)' }}>·  signed proof verified 11s ago</span>
              </div>
              <button className="fermo-btn fermo-btn-ghost fermo-btn-sm"><FIcon name="arrow.clockwise" size={11}/> Recheck</button>
            </div>
          </div>

          {/* Note pad */}
          <div className="fermo-card" style={{ overflow: 'hidden' }}>
            <div style={{ padding: '12px 16px', borderBottom: '1px solid var(--f-line)', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <FIcon name="square.and.pencil" size={13} style={{ color: 'var(--f-fg-1)' }}/>
                <span style={{ fontSize: 12.5, fontWeight: 600 }}>Session notes</span>
                <span style={{ fontSize: 11, color: 'var(--f-fg-3)' }}>· auto-attached to evidence</span>
              </div>
              <Kbd>⌘N</Kbd>
            </div>
            <textarea className="fermo-textarea" style={{ border: 'none', borderRadius: 0, minHeight: 140, background: 'transparent' }}
              defaultValue={'14:23  Outlined §1 — three sub-points. SLA-vs-actual graph data exported from grafana.\n14:31  §2 first pass written. Need a sentence about the August dip.\n14:38  Stuck on naming — calling it "error budget burn" feels imprecise.'}/>
          </div>
        </div>

        {/* RIGHT: Controls + health */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
          {/* Allowed actions */}
          <div className="fermo-card" style={{ overflow: 'hidden' }}>
            <div style={{ padding: '12px 16px', borderBottom: '1px solid var(--f-line)' }}>
              <div style={{ fontSize: 12.5, fontWeight: 600 }}>Allowed actions</div>
              <div style={{ fontSize: 11, color: 'var(--f-fg-3)', marginTop: 2 }}>What you can do without ending the session.</div>
            </div>
            <div style={{ padding: 12, display: 'flex', flexDirection: 'column', gap: 8 }}>
              <button className="fermo-btn fermo-btn-secondary" style={{ width: '100%', justifyContent: 'flex-start' }}>
                <FIcon name="square.and.pencil" size={12}/> Record note <span style={{ marginLeft: 'auto', color: 'var(--f-fg-3)' }}><Kbd>⌘N</Kbd></span>
              </button>
              <button className="fermo-btn fermo-btn-secondary" style={{ width: '100%', justifyContent: 'flex-start' }}>
                <FIcon name="list.bullet.clipboard" size={12}/> View room rules <span style={{ marginLeft: 'auto', color: 'var(--f-fg-3)' }}><Kbd>⌘R</Kbd></span>
              </button>
              <button className="fermo-btn fermo-btn-secondary" style={{ width: '100%', justifyContent: 'flex-start' }}>
                <FIcon name="bolt" size={12}/> Add 10 min <span style={{ marginLeft: 'auto', color: 'var(--f-fg-3)' }}><Kbd>⌘+</Kbd></span>
              </button>
              <hr className="fermo-hr" style={{ margin: '4px 0' }}/>
              {rigor === 'locked' && (
                <>
                  <button className="fermo-btn fermo-btn-secondary" style={{ width: '100%', justifyContent: 'flex-start', opacity: 0.5 }} disabled>
                    <FIcon name="stop.fill" size={11}/> Stop session
                    <span style={{ marginLeft: 'auto', fontSize: 11, color: 'var(--f-fg-3)' }}>unavailable · Locked</span>
                  </button>
                  <div style={{ fontSize: 11.5, color: 'var(--f-fg-3)', padding: '0 4px', lineHeight: 1.5 }}>
                    Locked sessions don't expose a stop button. If something real is on fire, switch this contract's rigor to Emergency before starting.
                  </div>
                </>
              )}
              {rigor === 'soft' && (
                <button className="fermo-btn fermo-btn-secondary" style={{ width: '100%', justifyContent: 'flex-start' }}>
                  <FIcon name="stop.fill" size={11}/> Stop session
                  <span style={{ marginLeft: 'auto', color: 'var(--f-fg-3)' }}><Kbd>⌘.</Kbd></span>
                </button>
              )}
              {rigor === 'emergency' && (
                <button className="fermo-btn fermo-btn-danger" style={{ width: '100%', justifyContent: 'flex-start' }}>
                  <FIcon name="exclamationmark.triangle" size={11}/> Break glass…
                  <span style={{ marginLeft: 'auto', color: 'var(--f-fg-3)' }}><Kbd>⌘⌥⌃.</Kbd></span>
                </button>
              )}
            </div>
          </div>

          {/* Live health */}
          <div className="fermo-card" style={{ overflow: 'hidden' }}>
            <div style={{ padding: '12px 16px', borderBottom: '1px solid var(--f-line)' }}>
              <div style={{ fontSize: 12.5, fontWeight: 600 }}>Live health</div>
              <div style={{ fontSize: 11, color: 'var(--f-fg-3)', marginTop: 2 }}>Re-checked every 5 s while running.</div>
            </div>
            {[
              { i: 'network',       t: 'Content filter',   s: degraded ? 'active' : 'active' },
              { i: 'app.dashed',    t: 'App interruption', s: degraded ? 'degraded' : 'active' },
              { i: 'externaldrive', t: 'Helper persistence', s: 'active' },
              { i: 'wifi',          t: 'Wi-Fi change',     s: 'unverified', d: 'No event since session start.' },
            ].map((r, i) => {
              const tone = STATE_TONE[r.s];
              const c = tone === 'ok' ? 'var(--f-ok)' : tone === 'warn' ? 'var(--f-warn)' : tone === 'danger' ? 'var(--f-danger)' : 'var(--f-fg-2)';
              return (
                <div key={r.t} style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '9px 16px', borderTop: i === 0 ? 'none' : '1px solid var(--f-line)' }}>
                  <FIcon name={r.i} size={12} style={{ color: 'var(--f-fg-2)' }}/>
                  <span style={{ flex: 1, fontSize: 12 }}>{r.t}</span>
                  <FIcon name={STATE_ICON[r.s]} size={11} style={{ color: c }}/>
                  <span style={{ fontSize: 11, fontWeight: 600, color: c, minWidth: 78, textAlign: 'right' }}>{STATE_LABEL[r.s]}</span>
                </div>
              );
            })}
          </div>
        </div>
      </div>
    </div>
  );
};

// ─────────────────────────────────────────────────────────────
// Break Glass dialog
// ─────────────────────────────────────────────────────────────
const FermoBreakGlass = () => (
  <div style={{
    width: '100%', height: '100%',
    background: 'rgba(5, 7, 10, 0.65)',
    backdropFilter: 'blur(10px)',
    WebkitBackdropFilter: 'blur(10px)',
    display: 'flex', alignItems: 'center', justifyContent: 'center',
    padding: 32,
    fontFamily: 'var(--f-font)',
  }} className="fermo">
    {/* Faint backdrop: hint of session screen */}
    <div style={{
      position: 'absolute', inset: 24,
      background: 'var(--f-bg-1)',
      border: '0.5px solid rgba(255,255,255,0.06)',
      borderRadius: 12,
      opacity: 0.4,
    }}/>

    <div style={{
      position: 'relative',
      width: 460,
      background: 'var(--f-bg-2)',
      border: '1px solid var(--f-line-2)',
      borderRadius: 12,
      boxShadow: '0 30px 80px rgba(0,0,0,0.6), 0 8px 20px rgba(0,0,0,0.4)',
      overflow: 'hidden',
    }}>
      <div style={{ padding: '22px 24px 4px', display: 'flex', gap: 14 }}>
        <div style={{
          width: 32, height: 32, borderRadius: 8,
          background: 'oklch(0.78 0.11 75 / 0.14)',
          border: '1px solid oklch(0.78 0.11 75 / 0.3)',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          color: 'var(--f-warn)', flexShrink: 0,
        }}>
          <FIcon name="exclamationmark.triangle" size={16}/>
        </div>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontSize: 15, fontWeight: 600, letterSpacing: 0 }}>End emergency session</div>
          <div style={{ fontSize: 12.5, color: 'var(--f-fg-2)', marginTop: 4, lineHeight: 1.5 }}>
            Your reason will be recorded in the evidence log. There is no judgment, just a record.
          </div>
        </div>
      </div>

      <div style={{ padding: '18px 24px 4px' }}>
        <FieldLabel>Reason</FieldLabel>
        <textarea
          className="fermo-textarea"
          placeholder="Why are you ending this session early?"
          autoFocus
          style={{ minHeight: 76 }}
          defaultValue="On-call paged for SEV-2 — billing reconciler returning 500s. Need to handoff and join the incident channel."
        />
        <div style={{ marginTop: 8, fontSize: 11.5, color: 'var(--f-fg-3)', display: 'flex', alignItems: 'center', gap: 6 }}>
          <FIcon name="info.circle" size={11}/>
          <span>23 characters minimum · 162 written · saved on confirm.</span>
        </div>
      </div>

      <div style={{ padding: '18px 24px 8px' }}>
        <div style={{ padding: '10px 12px', background: 'var(--f-bg-1)', border: '1px solid var(--f-line)', borderRadius: 8, fontSize: 12, color: 'var(--f-fg-1)', display: 'flex', flexDirection: 'column', gap: 6 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between' }}>
            <span style={{ color: 'var(--f-fg-3)' }}>Session</span>
            <span>Draft Q3 reliability memo</span>
          </div>
          <div style={{ display: 'flex', justifyContent: 'space-between' }}>
            <span style={{ color: 'var(--f-fg-3)' }}>Time used</span>
            <span className="fermo-mono">47:42 of 90:00</span>
          </div>
          <div style={{ display: 'flex', justifyContent: 'space-between' }}>
            <span style={{ color: 'var(--f-fg-3)' }}>Evidence will store</span>
            <span>outcome: <b style={{ color: 'var(--f-danger)' }}>broke-glass</b></span>
          </div>
        </div>
      </div>

      <div style={{ padding: '14px 24px 22px', display: 'flex', alignItems: 'center', gap: 10 }}>
        <span style={{ flex: 1, fontSize: 11.5, color: 'var(--f-fg-3)' }}>Hold <Kbd>⌘↵</Kbd> for 2 s to confirm</span>
        <button className="fermo-btn fermo-btn-secondary">Cancel</button>
        <button className="fermo-btn" style={{
          background: 'var(--f-warn)', color: '#1c0f00', fontWeight: 600,
          height: 28, padding: '0 14px',
        }}>
          <FIcon name="exclamationmark.triangle" size={11}/> End session &amp; record
        </button>
      </div>
    </div>
  </div>
);

// ─────────────────────────────────────────────────────────────
// Proof capture — post-session
// ─────────────────────────────────────────────────────────────
const FermoProofCapture = () => (
  <div style={{ display: 'flex', flexDirection: 'column', height: '100%', overflow: 'hidden' }}>
    <FermoSectionHead
      title="Record what happened"
      subtitle="The session ended at 14:48. This is your honest record, not a scoreboard."
      right={<button className="fermo-btn fermo-btn-ghost fermo-btn-sm">Skip · mark needs evidence</button>}
    />
    <div style={{ flex: 1, overflow: 'auto', padding: '22px 28px 28px' }}>
      <div style={{ maxWidth: 880, display: 'grid', gridTemplateColumns: '1.1fr 0.9fr', gap: 22 }}>
        {/* LEFT: Form */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 18 }}>
          {/* Outcome */}
          <div>
            <FieldLabel>Outcome</FieldLabel>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 8 }}>
              {[
                { v: 'completed', i: 'checkmark.circle', l: 'Completed', d: 'Shipped what I planned.', tone: 'ok',   on: true },
                { v: 'partial',   i: 'minus.circle',     l: 'Partial',   d: 'Some of it landed.',      tone: 'warn' },
                { v: 'notdone',   i: 'xmark.circle',     l: 'Not done',  d: 'Did not ship.',           tone: 'muted' },
              ].map(o => {
                const c = o.tone === 'ok' ? 'var(--f-ok)' : o.tone === 'warn' ? 'var(--f-warn)' : 'var(--f-fg-3)';
                return (
                  <div key={o.v} style={{
                    padding: 12,
                    border: `1px solid ${o.on ? c : 'var(--f-line-2)'}`,
                    background: o.on ? `color-mix(in oklch, ${c} 10%, transparent)` : 'var(--f-bg-2)',
                    borderRadius: 8, cursor: 'pointer',
                  }}>
                    <FIcon name={o.i} size={15} style={{ color: c }}/>
                    <div style={{ fontSize: 13, fontWeight: 600, marginTop: 6 }}>{o.l}</div>
                    <div style={{ fontSize: 11, color: 'var(--f-fg-3)', marginTop: 2 }}>{o.d}</div>
                  </div>
                );
              })}
            </div>
          </div>

          <div>
            <FieldLabel hint="What changed because of this session?">Proof note</FieldLabel>
            <textarea className="fermo-textarea" style={{ minHeight: 110 }}
              defaultValue="Drafted §1–3 of the reliability memo end to end, plus the SLA-vs-actual graph for §2. Holes left: §4 needs Mira's error-budget numbers, and the title still isn't right. Saved to repo as a PR for review."/>
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
            <div>
              <FieldLabel hint="optional">File reference</FieldLabel>
              <button className="fermo-btn fermo-btn-secondary" style={{ width: '100%', height: 30, justifyContent: 'flex-start' }}>
                <FIcon name="doc" size={12} style={{ color: 'var(--f-fg-2)' }}/>
                <span className="fermo-mono" style={{ fontSize: 12 }}>evidence/2026-04-12-q3-reliability.md</span>
              </button>
            </div>
            <div>
              <FieldLabel hint="optional">Link reference</FieldLabel>
              <input className="fermo-input fermo-mono" defaultValue="github.com/team/notes/pull/482"/>
            </div>
          </div>

          <div style={{ paddingTop: 8, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span style={{ fontSize: 11.5, color: 'var(--f-fg-3)' }}>Saved locally to <span className="fermo-mono">~/Fermo/evidence/</span>. Nothing leaves this Mac.</span>
            <div style={{ display: 'flex', gap: 8 }}>
              <button className="fermo-btn fermo-btn-secondary">Save draft</button>
              <button className="fermo-btn fermo-btn-primary fermo-btn-lg">
                <FIcon name="checkmark.seal" size={11}/> Save to evidence log
              </button>
            </div>
          </div>
        </div>

        {/* RIGHT: Preview */}
        <div className="fermo-card" style={{ display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
          <div style={{ padding: '12px 16px', borderBottom: '1px solid var(--f-line)', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
              <FIcon name="doc.text" size={13} style={{ color: 'var(--f-fg-2)' }}/>
              <span style={{ fontSize: 12.5, fontWeight: 600 }}>Markdown preview</span>
            </div>
            <Chip mono>2026-04-12-q3-reliability.md</Chip>
          </div>
          <pre style={{
            margin: 0, padding: '14px 16px', flex: 1, overflow: 'auto',
            fontFamily: 'var(--f-font-mono)', fontSize: 11.5, lineHeight: 1.6,
            color: 'var(--f-fg-1)', whiteSpace: 'pre-wrap',
          }}>
{`# Draft Q3 reliability memo
**Outcome:** completed · 1:30:00 used of 1:30:00
**Room:** Deep Writing (Focus Room)
**Rigor:** Locked
**Started:** 2026-04-12 13:18
**Ended:**   2026-04-12 14:48

## What changed
Drafted §1–3 end to end, plus the SLA-vs-actual graph for §2.

## Open holes
- §4 needs error-budget numbers from Mira
- Title still imprecise

## Attached
- file: `}<span style={{ color: 'var(--f-ok)' }}>evidence/2026-04-12-q3-reliability.md</span>{`
- link: `}<span style={{ color: 'var(--f-ok)' }}>github.com/team/notes/pull/482</span>{`

## Notes captured during session
14:23  Outlined §1 — three sub-points.
14:31  §2 first pass written.
14:38  Stuck on naming.

## System
3 protections green · 1 unverified (Wi-Fi change).
Helper signed proof OK at 14:48.`}
          </pre>
        </div>
      </div>
    </div>
  </div>
);

Object.assign(window, { FermoActiveSession, FermoBreakGlass, FermoProofCapture });
