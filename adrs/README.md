# Architecture Decision Records (ADRs)

This directory holds the architectural best practices and standards that apply
to code in the Anchor library. Each Markdown file documents one standard.

For guidance on working inside this directory (adding, updating, superseding,
amending, or retiring an ADR), see [CLAUDE.md](./CLAUDE.md).

The first three ADRs were ported from the `walt_ui` monorepo on 2026-09-12 and
adapted for Anchor, which is a single, standalone (non-umbrella) Elixir library.

## File naming

ADRs are Markdown files named `XXX-[name-using-dashes].md`, where `XXX` is a
triple-digit zero-padded sequence number. Numbers are assigned in the order ADRs
are adopted and are never reused.

## Current ADRs

- [001 -- Five-Bucket Architecture](./001-five-bucket-architecture.md)
- [002 -- Fast, Comprehensive, High-Signal Tests](./002-fast-comprehensive-high-signal-tests.md)
- [003 -- One File Per Sabotage Run, Beside the Suite It Describes](./003-sabotage-records-one-file-per-run.md)

## Adding a new ADR

1. Pick the next unused sequence number.
2. Create `XXX-your-name.md` following the format of the existing ADRs.
3. Open a merge/pull request for review.

## Enforcement

There is no ADR review bot in this repository. The ADRs are enforced by code
review, and — where a standard is mechanically checkable — by Anchor's own Credo
checks configured in `.anchor.yml` against Anchor's own tree.
