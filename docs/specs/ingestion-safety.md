# Spec: Ingestion safety helpers + user OPML parsing (Oct 30)

**Goal:** the specified fetching rules as reusable code, before Day 8's
add-source work needs them: link safety (AGENTS.md §13) and a user-OPML parser
that treats the file as untrusted. No fetching, no routes, no DB wiring.

## Inputs

- A candidate URL string (from discovery, OPML import, or a feed).
- A reader's OPML file as bytes (parsed, then discarded; never committed).

## Outputs

- `services/ingestion/safety.py`:
  - `check_url(url) -> str`: returns the normalized URL or raises
    `UnsafeUrl`. Allows http/https only; refuses credentials in the URL,
    non-default-port tricks are fine but blocked hosts are not: literal
    private/loopback/link-local/multicast/reserved IPs, `localhost`, and
    single-label or special-use names (`.local`, `.internal`, `.invalid`,
    metadata endpoints). No network: DNS time-of-check stays the fetcher's
    job at fetch and after every redirect (Day 4).
  - `MAX_OPML_BYTES` (1 MiB), `MAX_OPML_OUTLINES` (5,000), and
    `read_user_opml(data)`: refuses oversize input, any `<!ENTITY`
    declaration (entity expansion off, billion-laughs impossible), and excess
    outlines; validates every `xmlUrl`/`htmlUrl` with `check_url`; returns
    plain `(title, feed_url, html_url)` triples. The seed loader keeps its
    own path: the seed file is ours.
- `opml.py`: the seed loader additionally honors an optional per-outline
  `language` attribute (`en`/`da`/`ta`, default `en`) instead of assuming
  English — a Danish seed feed must not mistag.

## Rules

- **Fail closed.** Any refusal raises; callers never get a maybe-URL.
- **No new dependencies.** stdlib only (`urllib`, `ipaddress`, `xml.etree`).
- **Reader OPML never touches the seed path** and vice versa.

## How to test

- `cd backend && uv run pytest -q tests/test_ingestion_safety.py`.
- URL table: good feeds pass; `javascript:`, `file:`, credentials, private /
  loopback / link-local / multicast IPs, `localhost`, `.local` names refused.
- OPML: a small valid file parses; entity declarations, oversize input, too
  many outlines, and a single bad URL each refuse the whole file.
- Seed loader: an outline with `language="da"` loads as Danish; without it,
  English as before.
