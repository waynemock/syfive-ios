# Syzygy Softwerks — Studio Conventions

**Studio-level. Identical in every project.**
Version 1.7 · Ships in every agent prompt, alongside the project's own documents.

---

## 0. What this is

The conventions that do not change between projects. SyFive and Syderal follow the same ones, and
so will whatever comes next.

**This document is canonical.** A project document that restates a rule from here is a copy waiting
to drift — cite `00A` instead. Project documents hold what is *specific* to that project: its
architecture, its rules register, its task breakdown.

**Where a project document and this one disagree, raise it.** Do not silently prefer either. A
genuine studio-wide change belongs here; a genuine project exception belongs in that project's
ledger, stated as an exception.

### How this document grows

A rule earns a place here by **recurring**, not by being learned once. The test is whether it would
have applied to the previous project as well as this one.

- A lesson from one project starts in **that project's ledger**, where its context survives.
- It is **promoted here when a second project needs it**, or when it plainly would have. Promotion
  rewrites the rule in project-neutral terms and leaves the originating ledger row citing `00A`.
- A rule that names a framework, a folder, a dependency, or a type **stays in the project**. If it
  cannot be stated without one, it is not a studio convention yet.
- The decision log records **why**, not just what. A rule whose reasoning is lost is a rule someone
  reopens.

**Prune as readily as you add.** This document works because it is short enough to be read in full
before every session. A convention nobody has needed in two projects should be removed, not kept out
of politeness to its author.

When a directive is agreed in conversation, it is written here in the same session — not noted for
later. A convention that lives only in a chat log is one the next project will not inherit.

---

## 1. Documents

- **Numeric prefix, SCREAMING_SNAKE_CASE**, `.md`: `09_IMPLEMENTATION_PLAN.md`,
  `12C_BOARD_CONSTANTS.md`. Letter suffixes mark companions to a numbered document — `12A` reviews
  `12`, `12C` is separate work that arose from it.
- **Documents are rewritten in place.** No errata files, no supersession blocks, no "see also the
  correction below." The document is the specification and always reads as current.
- **Every document carries a decision log** — what was decided, and why. The why is what stops a
  settled question being reopened a month later by someone reconstructing the reasoning.
- **Every document carries a version and a changelog row** when it changes materially.
- The **decision ledger is the exception to rewriting in place**: its IDs are permanent and
  append-only, and a reversed decision has its row rewritten to the new ruling. It is the only place
  a reversal survives, because everything else is rewritten.

## 2. Writing a task

The agent applies; it does not solve. It is materially worse than Claude at working things out, 
and anything left for it to figure out is a risk rather than a convenience. A task should be closer to 
transcription than to problem-solving.

The test: if a done-when cannot be checked without looking at a rendered result, the agent cannot 
do that task. It has no eyes. "Place it so it looks balanced" or "keep it clear of the other elements" 
asks for a judgement it can only approximate by arithmetic against geometry it must first re-derive from source.

Specify exactly where the work is hard; leave free only what is mechanical. The instinct runs backwards, 
ecause precise data is easy to write down and a loose rule feels generous. That is the worst possible split. 
Give the solution and let the agent write it.

Solve visual and spatial problems upstream, where they can be seen and checked, and hand down fixed 
values — absolute coordinates, keyframes, explicit tables. Keep the derivation and its source alongside 
the output so the result stays auditable and can be re-solved if the underlying thing moves. Never ask 
the agent to re-solve it.

Where judgement is unavoidable, make the clause report rather than decide. "Verify X and report what you observe" 
is completable; "adjust X until it looks right" is not. Where a task could stall on a decision, pre-authorise the 
fallback by name so the session continues instead of stopping to ask.

Kill a stalled session early; do not retry it. The signature: the agent restates the contents of a file it could read, 
re-derives constants that already exist, and writes "wait, let me re-check." It is solving rather than applying. 
If a task that should be mechanical has produced no file edit within the first few minutes, it will not. 
Stop it and look at what the specification left open — a retry reruns the same unsolvable problem.

## 3. Session protocol

- **One task per session.** Read the task, do that task, stop.
- Every task states its **inputs**, its **deliverable**, its **done-when**, and what it **must not
  touch**. A task is finished when the done-when is met, not when the code could be improved
  further.
- **If you finish early, stop.** Do not tidy adjacent files, do not start the next task. The next
  session handles it with fresh context and does it better.
- **Noticing a problem outside scope is valuable. Report it; do not fix it.**

## 4. Stop conditions

Halt and ask. Do not resolve inline.

- A case the project's rules register does not cover.
- A named type, folder, or constant that appears to be missing — it usually exists under another
  name.
- Two documents that appear to conflict.
- A done-when clause that appears impossible to satisfy. The task is wrong; do not redefine it to
  something achievable.
- A test that fails where the fix would mean changing the test.
- Work exceeding roughly double the estimated scope.
- A UI/UX interaction or presentation change of any real size, where the request described a
  problem rather than prescribed a fix. Lay out the realistic approaches and their tradeoffs; do
  not choose one and build it. The person has firm opinions here and is the decision-maker.

**Reporting a blocker is a successful session.** Producing plausible work that resolves an ambiguity
silently is a failed one, even if it compiles and the tests pass.

## 5. Accessibility scope

**Unless a project states otherwise, the Syzygy MVP bar is Dynamic Type supported to AX2, and no
VoiceOver or Reduce Motion certification** — no full-game playthrough under either, and no
milestone gate that depends on one. The studio's own devices span xSmall to AX2, and that is the
range an MVP is built and checked against.

**Still required, because it is cheap and permanent:** never rely on colour alone to carry meaning;
label every control for what it does rather than where it sits; honour the system Reduce Motion
flag wherever an animation is already gated; and never remove an affordance the framework provides
for free. These cost almost nothing at build time and are expensive to retrofit.

**Verification at MVP is a static source audit plus a visual check at the supported ceiling, not a
live assistive-technology playthrough.** An audit finds code-level gaps with certainty; it does not
observe rotor order, focus traps, announcement timing, or whether a state change stays legible at
speed. Record that bound rather than implying more was established.

**An agent does not write an accessibility requirement above this bar into a milestone gate, a task
done-when, or a ruling without asking first.** Raising the bar is a product decision, driven by a
real requirement from real users, and it is a large one: a dense interface at AX5 is an engineering
project, not a checkbox. Later is a legitimate answer and usually the right one.

**Check the constant before writing the bar.** When a design document states a verification target
— a type size, a frame rate, a device — open the code that enforces it and confirm they agree
before carrying the target into a done-when. A gate that names a state the build cannot reach
produces tasks that report success at a level nobody tested.

## 6. Reporting

End every session with a summary that **echoes each done-when clause individually** and marks it met
or not met. A prose notes field is where a missed clause goes to be omitted.

```
TASK:      2.4
STATUS:    complete | blocked

CLAUSES:
  ✅ (clause, restated, and what satisfies it)
  ⚠️ (clause not met, what was found, and why it stopped here)

FILES:     (paths touched)
TESTS:     (added, and the suite total)
BLOCKED:   (what, and which document should answer it)
NOTES:     (anything the next session needs; omit if nothing)
```

A `⚠️` is a successful session. **A clause is met or reported, never quietly renegotiated.** A ✅
that does not mean what it says is worse than an open task.

**A clause verified outside the session records who verified it** *(SYD-127)* — `✅ (confirmed by <name> on
device)`. Visual and on-device checks are often performed by the person rather than the session, and
a summary written in the session's own voice reads as a claim the session cannot support. A `✅`
meaning "someone will check this later" is not a met clause; it is `⚠️` until someone has.

**Device and simulator interaction tools are invoked by request, not by default.** An agent does
not open a device-interaction session — installing, running, and driving taps, screenshots, or
hierarchy dumps against a simulator — to confirm a UI change looks right unless the person asks for
that check in that turn. A green build and test suite are the session's own verification; a live
device pass is the person's to request, and expensive enough in tool calls that it is never assumed
on their behalf.

If NOTES runs long, the task was too big — say so.

**Task specs are pasted verbatim.** When recording a completed task in its milestone document, the agent copies the issued spec — Inputs, Deliverable, Done when, Do not — exactly as written. It never paraphrases, condenses, or rewrites a done-when to match what was built. Anything not done, done differently, or found to be wrong goes under `NOTES` in the session summary. A shortened done-when reported as complete deletes a requirement from the register silently, which is how a milestone loses work nobody decided to drop.

### Verifying completed work

Verify against the source, never against the ledger. The ledger records what was decided. 
It is not evidence that anything was built, and the two diverge in both directions — code 
can cite a ruling that was never written, and a ruling can describe work that never landed. 
A review that confirms a task from its own ruling is checking the record against itself.

A grep hit, a filename, or a matching ledger row is not verification. A symbol existing does 
not mean it does what the document says. Open the implementation and read it.

Cite file and line for every item claimed verified. A claim without a citation is a paraphrase 
of the specification, not a finding.

Where a property can be checked numerically, check it numerically. Clearances, contrast 
ratios, tangent continuity, star counts, span distributions — these are computed, not eyeballed. 
A review that says "looks right" about something measurable has not reviewed it.

State plainly which items were read at source and which were not. A partial review presented as 
a complete one is worse than an honestly partial one: the reader cannot tell which rows are evidence 
and which are restatement, so the whole table becomes untrustworthy. If time or budget forces a partial 
pass, say what was covered and what was not.

When source is supplied for review, the review is the task. Reconciling documents is secondary work 
that follows it, not a substitute for it.

## 7. Tests

- **A test may never be changed to make it pass.** Tests encode the specification; editing one to go
  green is a specification change in disguise.
- **A test may follow a specification change.** When the spec moves first and a task names the
  change, re-pinning the test is correct. State this in the task text, or a session will correctly
  read it as a stop condition and halt.
- Name tests after the rule, not the function.
- **Tests run against a pinned destination at the deployment floor**, named explicitly in the
  project's validation section and reported in the session summary. An IDE's test action inherits
  whatever destination the toolbar holds, which makes results non-reproducible between sessions and
  silently validates against a runtime newer than the one that ships. A suite that has only ever run
  above the deployment floor has not been validated at it.
- If the pinned destination is unavailable, **stop and report it**. Substituting a different device
  or a newer runtime is the failure this rule exists to prevent.

## 8. Warnings and build health

**Fix the cause; never silence the symptom.** A warning from code this session wrote is this
session's to fix. A warning from a build setting, a dependency, or a file the task does not name is
**reported, not suppressed** — annotating it away where it appears is never the fix, even when the
annotation is correct.

A quiet build is not the goal. A correct one is.

## 9. Version control and shell use

**Agents never run `git`.** No commits, branches, stashes, or staging. Every task is reviewed as an
uncommitted working tree; committing would bury the diff before anyone reads it.

**Python is the scripting language for anything beyond one plain command.** Searching logs,
comparing test lists, batch text edits, extracting a section of a document: write a short
`python3` script, not a chain of `grep`, `sed`, `awk`, `comm` and `tr`.
- One language means one standing permission instead of a new prompt for each tool.
- A script is readable, so the person approving it can see what it does.
- Python behaves the same on every machine, where BSD and GNU `sed` do not.

Single plain commands (`xcodebuild`, `ls`, `wc`) and the agent's own file tools stay as they are.
Python replaces pipelines, not tools.

## 10. Structure

- New work goes into an existing folder. **If a file seems to need a new folder, stop and ask.**
- Constants and values live in one place and are read, never retyped. A literal standing in for a
  named constant is a defect the day the constant changes.
- **A constant describing something physical is verified visually before it is locked** — against a
  drawing, a render, or the artifact itself. Internal consistency is not correctness: a full set of
  wrong constants passes every test written against them.

## 11. Adopting this document

A project adopts `00A` by **removing what it now duplicates**, not by adding it alongside. Two
copies of a rule is where disagreement starts, and it is the failure this document exists to
prevent.

### Task A-1 · Adopt `00A`

**Inputs:** `00A`; the project's implementation plan, engineering guidelines, and decision ledger
**Deliverable:** `00A` in the project, and every rule it carries removed from where it was restated.

**Run when nothing else is in flight** — between milestones, not during one. It touches the
documents every other task reads.

**Done when:**
- `00A_STUDIO_CONVENTIONS.md` sits alongside the numbered suite and is listed in `README.md` with
  its authority stated: studio-level, canonical, cited rather than restated.
- The implementation plan's **stop conditions** keep only rows that name project documents; the
  general rows are replaced by a citation to `00A` §4.
- The implementation plan's **standing prohibitions** keep only the project-specific ones. In
  Syderal that is: no SpriteKit in `Model/`, no theme engine or generalised abstraction, no board
  coordinates outside `BoardGeometry`, no changes to the architecture document's type signatures, no
  turn timers, no `SyLibDice`, and the test framework choice. The rest — never run `git`, never
  change a test to pass, do not refactor unnamed files, do not exceed the task — cite `00A`.
- The implementation plan's **session summary block** is replaced by a citation to `00A` §6. The
  project keeps only what is genuinely its own, such as which documents to read at session start.
- The engineering guidelines' **version control** and **scope control** sections become citations.
  Their **validation** section keeps the project's actual build and test commands and cites `00A` §8
  for the warning directive.
- The engineering guidelines' folder rule cites `00A` §10; the project keeps its own file map.
- Ledger rows that now merely restate a studio rule are **rewritten to cite `00A`**, keeping their
  IDs. In Syderal: SYD-003, SYD-004, SYD-006. IDs are permanent and are never deleted (§1).
- **A grep for any rule's distinctive phrasing returns one hit outside `00A`, or none.** That is the
  test of whether the adoption worked.

**Do not:** delete a project-specific rule because it resembles a studio one. Do not remove a ledger
ID. Do not change any rule's meaning — this task moves text, it does not revise it. A rule that
seems to need revising is a separate decision and a stop condition here.

*The risk in this task is over-pruning. A prohibition that looks generic but names a project type,
folder, or dependency is project-specific and stays. When unsure, keep it and report it.*

---

## 12. Working from a reference implementation

None of what follows is Game Night specific. All of it was paid for there.

### Read the sibling's source before writing a line of spec

When another Syzygy app already does the thing, its source is the specification. Fifteen of
Milestone 7's tasks reconstructed from scratch what SyFive already had — the alerts, the pending
invite state, the leading control's states, the rematch, the roster upsert — because the reference
wasn't in front of Claude and wasn't asked for. Every one of those came back later as a parity fix-up.

**Ask for it at the start, by name.** "Is there an app that already does this?" is a cheaper question
than a milestone of rework.

### Sweep the whole API surface, not the files that answer today's question

When adopting a shared library a sibling already uses, list every library symbol the sibling touches,
list what the new app touches, and account for each difference as **deliberate** or **missing**. Two
of Milestone 7's worst defects — no catch-up broadcast for a rejoining peer, and a dead board when a
call ended — were hooks the sibling wired and the new app didn't. Both were found by a ten-minute
sweep, after hardware had already found them the expensive way.

Do the sweep once, when the integration first compiles.

### A claim about the code is worth what its citation is worth

Twice in Milestone 7 a session summary asserted something the tree contradicted: a revert that hadn't
happened, a missing call that the library was already making. Both were caught by reading the file
rather than the summary.

- **Cite file and line for anything load-bearing**, in specs and in notes.
- **When a task's premise turns out to be wrong, say so and stop.** The agent that refused
  Task 7.14j — because the coordinator already broadcast completion — saved a duplicate-message bug.
  A correct refusal with evidence is a good outcome, not a failed session.

### Extract the loop before adding transport

Multiplayer needs an object to attach to. Syderal's turn loop lived in a SwiftUI view, so the first
three tasks of the milestone moved it into a controller before any networking could exist. Any feature
that needs to *drive* the game from outside a tap — network play, AI opponents, replays, automated
tests — needs the same thing.

If the rules live in a view, that's the first task, whatever the feature is.

### Instrument before diagnosing anything that crosses a device boundary

Timing bugs between two devices are read out of logs, not reasoned out. Milestone 7 diagnosed one
reconnect bug backwards twice from inference, added logging, and then read the answer off the next run
in one pass.

Assume the ordering you expect is the thing that's wrong, and log both sides of it: what arrived, what
was applied, which path handled it, and what each flag did.

### Prefer one item-driven presenter to many booleans

Several boolean flags driving several sheets on one view is a collision waiting to happen — a second
flag raised while a sheet is up fails silently and stays stuck true. One route enum makes the
collision impossible instead of guarded against. The same reasoning applies to any "only one of these
at a time" UI.

### Name what a state change *means*, not what triggered it

The milestone's last structural gap was treating every session teardown as "the match ended", which
swept up a dropped call where nobody had chosen anything. The fix was to classify: deliberate endings
all carry a signal, so anything without one is a suspension.

When a single low-level event can mean several things to the player, classify it at the boundary and
name the cases. The alternative is discovering the cases one at a time, from the field.

---

## 13. Decision log

| Version | Decision | Rationale |
|---|---|---|
| v1.7 | §9 becomes "Version control and shell use" and gains the rule that Python is the scripting language for anything beyond one plain command. Pipelines of `grep`, `sed`, `awk`, `comm` and `tr` are replaced by short `python3` scripts; single plain commands and the agent's file tools are unchanged | Directed by Pops on Syderal Milestone 9: each unfamiliar shell tool needed its own permission, and long pipelines were hard to read before approving. It applies to every session in every project, so it is studio-wide from the start |
| v1.6 | New §12 "Working from a reference implementation": read the sibling's source before writing spec, sweep its whole API surface, cite rather than assert, extract the loop before adding transport, instrument before diagnosing across a device boundary, prefer one item-driven presenter, and name what a state change means rather than what triggered it | Learned on Syderal Milestone 7: fifteen tasks reconstructed behaviour SyFive already had, because the reference was never in front of the session and was never asked for. Every one came back as a parity fix-up. The other six are the same milestone's recurring failure shapes, none of them SharePlay-specific |
| v1.5 | New §5 "Accessibility scope": the Syzygy MVP bar is Dynamic Type to AX2, no VoiceOver or Reduce Motion certification; verification is a static source audit plus a visual check at the ceiling, not a live playthrough | Learned on Syderal Milestone 6: an AX5 requirement was carried out of a design document into a dozen milestone done-whens without anyone checking the constant that governed it, and it was not a wrong decision but an unexamined one. The bar and the check-the-constant discipline both need to travel to the next project, not be re-derived from scratch |
| v1.4 | A UI/UX change is a stop condition when the request described a problem, not a fix | Learned on Syderal Milestone 6 Wave C: asked to stop a table-set menu from dimming the sheet behind it, the agent picked a specific replacement (a forced popover) and built it without proposing alternatives. The person has firm UI/UX opinions and is the decision-maker; a described problem is not authorisation to choose the solution |
| v1.3 | Device-interaction tools are invoked by request, not proactively | Learned on Syderal Milestone 6 Wave C: the agent ran repeated on-device verification passes after small UI changes without being asked, spending tool calls the person had not budgeted for and did not want — even though one such pass, earlier in the same session, had caught a real defect. The value of the check does not license making it the default |
| v1.2 | Task specs are pasted verbatim in milestone records | Learned on Syderal Milestone 6: the agent appended shortened done-whens of its own and reported complete against them, silently deleting requirements from the register. A paraphrase that is shorter than the spec is a scope cut nobody decided to make |
| v1.1 | A clause verified outside the session names its verifier | Learned on Syderal Milestone 2: three on-device checks were genuinely performed by the person, and the summary recorded them in the session's voice — leaving a claim that could not be corroborated from the record |
| v1.0 | Tests run at the deployment floor, on a pinned destination | The toolbar's destination drifts between sessions, and a modern simulator runs a newer OS than the target ships against — so the floor, which is the version that can actually break, goes untested |
| v1.0 | A rule is promoted here only when a second project needs it | Lessons are cheap and conventions are expensive; promoting every one produces a document nobody reads in full |
| v1.0 | Prune as readily as add | The value is that it is short enough to read before every session, and that is the first property lost |
| v1.0 | Adoption removes duplicates rather than adding alongside | Two copies of a rule is the failure this document exists to prevent; adopting by addition would be self-defeating |
| v1.0 | The grep test is Task A-1's done-when | "Cite rather than restate" is unverifiable as a principle and trivial to check as a search |
| v1.0 | Ledger rows are rewritten to cite, never deleted | IDs are permanent; a deleted row is a decision that can be re-derived from scratch |
| v1.0 | Studio conventions split from project documents | SyFive and Syderal repeat the same rules; two copies is where drift starts |
| v1.0 | This document is canonical; project documents cite rather than restate | Four documents describing one rule is how they disagree |
| v1.0 | Done-when clauses echoed individually in session summaries | A ruling without a mechanism does not hold; prose notes omit what prose notes omit |
| v1.0 | Tests may follow a spec change but never be edited to pass | The distinction is the direction of causation, and it needs stating or every re-pin reads as a violation |
| v1.0 | Physical constants verified visually before locking | Learned on Syderal: a mirrored board and a wrong lane table survived a milestone, 165 tests, and a full review, because everything was consistent with constants that were wrong |
