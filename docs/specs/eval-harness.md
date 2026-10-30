# Spec: Eval harness (Oct 30)

**Goal:** make `cd eval && python run_eval.py` real: label validation, the two
specified metrics, and a results file the author can trust — before the first
eval numbers on Day 5. It scores clustering; it never sets thresholds. The
author owns the methodology; this spec only mechanizes what AGENTS.md and the
folder structure already say (`eval/labels/`, `run_eval.py`, `eval/results/`).

## Inputs

- `eval/labels/*.json`: hand-labelled story groups. Each group lists items by
  id + link only — never full text (rule 5). Schema (`version: 1`):
  `{"version": 1, "groups": [{"id": "g1", "items": [{"id": "a1", "link": "https://…"}]}]}`.
- `predictions.json`: the pipeline's answer, `{item_id: story_id}`.

## Outputs

- `eval/metrics.py` (stdlib only): `pairwise_scores` (precision/recall/F1 over
  same-story pairs) and `bcubed_scores` (per-item precision/recall averaged,
  then F1). Pure functions, documented edge cases (empty input raises; a
  predicted id missing from the labels is an error, not a silent skip).
- `eval/labels.py`: `load_labels` — parses every file, validates the schema,
  refuses text-bearing keys (`text`, `transcript`, `body`), duplicate ids, and
  non-http(s) links.
- `eval/run_eval.py`: `python run_eval.py labels/ predictions.json [--out results/]`
  prints pairwise + B-cubed P/R/F1 with group/item counts and writes a
  timestamped JSON result. No labels → "nothing to score", exit 0.
- `eval/test_metrics.py`: stdlib `unittest` (the eval has no venv of its own),
  run with `make eval-test`. Tiny hand-made cases with hand-computed numbers.
- `eval/labels/README.md`: the format, with a two-group example.

## Rules

- **No methodology changes.** Pairwise + B-cubed, as specified. New metrics
  need the author.
- **Labels stay committable:** ids + links only. Anything fuller is refused
  at load time.
- **Missing predictions are errors.** An id the pipeline never assigned must
  fail loudly, never flatter the score by disappearing.

## How to test

- `cd eval && python3 -m unittest -v` (or `make eval-test` from the root).
- `python run_eval.py` with no labels exits 0 with "nothing to score".
- A perfect predictions file scores 1.0 everywhere; an all-singletons
  prediction against grouped gold scores pairwise recall 0. Precision with no
  predicted pairs is 1.0 only when the gold has no pairs either, else 0.0 —
  never a crash.
