# ADRs Directory

This directory holds the architectural best practices and standards that apply
to code in the Anchor library. Each numbered Markdown file documents one
standard. Use this file as directory-specific guidance when adding, updating,
superseding, amending, or retiring an ADR.

## File Naming

ADRs are Markdown files named:

```
XXX-[name-using-dashes].md
```

- `XXX` is a triple-digit zero-padded sequence number (`001`, `002`, …, `042`).
- The rest is a short, dash-separated slug describing the subject.
- Numbers are assigned sequentially in the order ADRs are adopted. **Numbers are
  never reused**, even for superseded or retired ADRs.

Before picking a number, list the directory and take the highest existing `XXX-`
prefix + 1:

```bash
ls adrs/ | grep -E '^[0-9]{3}-' | sort | tail -1
```

## When to Add an ADR

Add an ADR when a new architectural standard has been accepted that applies
across the library and is worth enforcing. Signals:

- The same architectural mistake has been made and caught more than once.
- A decision has been debated, concluded, and needs to stick.
- A new cross-cutting rule (module placement, naming, error handling, dependency
  direction, testing discipline) has been adopted.

Do **not** add an ADR for:

- Proposals still under discussion — those are RFCs, not ADRs.
- Guidance that applies to only one module and does not generalize — put it in a
  moduledoc or a `CLAUDE.md` beside the code.
- Style/formatting rules handled by `mix format` or `credo` — those tools
  enforce themselves and do not need a parallel ADR.

## Structure of an ADR

Follow the shape established by `001-five-bucket-architecture.md`:

```markdown
# ADR XXX -- Title

## Status

Accepted. | Superseded by ADR YYY. | Retired (date, reason).

## Context

Why this decision exists. What problem it solves. What was the pressure that
made the team adopt it?

## Decision

The rule or constraint itself, stated precisely. Use sub-sections for
allowed/forbidden matrices, specific constraints, examples.

## Examples

### Correct

<code showing the right shape>

### Incorrect

<code showing what the ADR prohibits>

## Consequences

### Benefits

Why this is worth the cost.

### Tradeoffs

What we give up in exchange. Be honest about costs — an ADR with no tradeoffs is
probably not a real decision.

## Enforcement

How the rule is enforced (code review, a Credo check, …).

## References

Supporting material: external articles, related ADRs, files in the codebase that
exemplify the rule.
```

Every ADR must explain **what** the rule is, **why** it exists, and **how** to
apply it (with concrete correct/incorrect examples). Skip any section that
genuinely doesn't apply, but don't skip Decision, Examples, or Consequences.

## Lifecycle

### Adding a new ADR

1. Pick the next unused sequence number (see above).
2. Create `adrs/XXX-your-name.md` following the structure above.
3. Update `adrs/README.md` to list the new ADR under "Current ADRs".
4. Open a merge/pull request for review.

### Superseding an ADR

ADRs are **append-only**. If a best practice changes:

1. Write a new ADR (`XXX-new-name.md`) that supersedes the old one.
2. In the new ADR's Status section, note what it supersedes: `Supersedes ADR
   NNN`, where `NNN` is the old ADR's number.
3. In the old ADR, change the Status to `Superseded by ADR XXX (link).` and add
   a one-line note at the top pointing forward. **Do not rewrite or delete the
   body of the superseded ADR.** Its history stays intact.
4. Update `adrs/README.md` to reflect the supersession.

### Splitting an ADR (extracting a section)

When an accepted ADR has grown to cover two separable standards, extract one into
its own ADR rather than letting the file keep growing. This is **not**
supersession — the original stays in force for everything it still covers.

1. Pick the next unused sequence number for the extracted standard.
2. In the new ADR's Status section, note the origin: `Extracted from ADR NNN.`
   Give it a real Context of its own — a section lifted verbatim usually reads as
   a fragment, because its "why" was carried by the parent's Context.
3. In the original, replace the extracted section with a short pointer naming the
   new ADR, and move the corresponding Examples and Enforcement bullets across.
   Leaving a duplicate in both files is worse than either home.
4. Update `adrs/README.md`.

### Amending an ADR (reclassifying a subject, standard unchanged)

Sometimes a decision about **one subject** changes while the **standard itself**
does not. A worked example stops being true; an entity turns out never to have
qualified under a rule it was grandfathered into. Supersession over-serves this —
it retires a rule nobody disagrees with — and doing nothing leaves the ADR
asserting something false about the codebase.

Amend in place, under these constraints:

1. **Only when the standard is genuinely unchanged.** If the *rule* moves, even
   slightly, it is a supersession and needs a new ADR. The test: after the
   amendment, does the Decision section still bind every subject exactly as it
   did before? If not, stop and write a new ADR.
2. **Add a dated `Amended YYYY-MM-DD:` line to the Status section**, one or two
   sentences, naming the subject and pointing at the amendment section. Leave
   `Accepted.` in place — the ADR is still accepted.
3. **Put the reasoning in a dated `#### Amendment: <what changed>` subsection**
   under the section it qualifies, not scattered through the body. It should say
   why the original classification was wrong, not merely that it changed.
4. **Correcting stale prose is in scope; rewriting the Decision is not.** A
   References bullet or a Context sentence the amendment makes false should be
   corrected in the same change. Rules, criteria, and Consequences stay as
   written.
5. **Sweep for the subject's other mentions.** An amended subject usually appears
   in Examples, Enforcement, sibling ADRs, and moduledocs that copied the
   original wording. Grep for it; a half-amended ADR is worse than an unamended
   one.

### Retiring an ADR

If a best practice no longer applies (e.g. the subsystem it governed was
removed):

1. Change the Status to `Retired (YYYY-MM-DD, <reason>).`
2. Add a one-line note at the top explaining why.
3. Leave the file in place. **Do not delete retired ADRs** — they are historical
   context.
4. Update `adrs/README.md` to move the ADR under a "Retired" section.

## Enforcement

There is no ADR review bot in this repository. ADRs are enforced by **code
review**, and — where a standard is mechanically checkable — by Anchor's own
Credo checks configured against Anchor's own tree. When you change an ADR, expect
a reviewer to read the change against the standard it documents; when you change
code, expect it to be read against the ADRs. If a rule can be expressed as a
dependency-direction or module-pattern constraint, prefer encoding it in
`.anchor.yml` so a machine enforces it rather than a reviewer remembering it.

## Pitfalls

### Don't put single-module rules here

If the rule only applies inside one module, put it in that module's moduledoc or
a nearby `CLAUDE.md`. ADRs are for cross-cutting, library-wide concerns.

### Don't rewrite history

Superseded and retired ADRs stay in place, untouched apart from the Status line
and forward-pointer note. The value of an ADR catalog is partly archaeological —
future engineers need to see what was decided and why it changed.

### Don't skip the "Why"

An ADR without a Context section is just a style guide. The `Context` section is
what makes the decision defensible and teachable. If you can't articulate why the
rule exists, the rule isn't ready to be an ADR.

### Keep ADRs focused

One standard per ADR. If a change introduces two distinct rules, write two ADRs.
Mixing concerns makes them hard to supersede independently.
