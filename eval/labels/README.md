# Eval labels

Hand-labelled story groups: which items cover the same event. The runner
(`python run_eval.py labels/ predictions.json`) scores the pipeline's
`{item_id: story_id}` answer with pairwise precision/recall/F1 and B-cubed F1.

## Format

One or more `*.json` files. Each group lists items by **id + link only** —
never titles, text, transcripts or summaries (rule 5: the repo must never hold
third-party content, and labels are committed):

```json
{
  "version": 1,
  "groups": [
    {
      "id": "halcyon-launch",
      "items": [
        {"id": "ledger-042", "link": "https://ledger.example/halcyon-launch"},
        {"id": "posten-117", "link": "https://posten.example/halcyon-2"}
      ]
    },
    {
      "id": "kestrel-landing",
      "items": [
        {"id": "orbital-009", "link": "https://orbital.example/kestrel-lands"}
      ]
    }
  ]
}
```

Rules the loader enforces:

- `version` must be `1`; every group needs a non-empty `items` list.
- Item ids are unique across all files; links must be `http(s)`.
- Any text-bearing key (`text`, `transcript`, `body`, `content`, `summary`)
  refuses the whole directory: fix the file, not the loader.

## Scoring notes

- A prediction for an id nobody labelled is an error, not a silent skip.
- Missing predictions score 0 for the pairs they break, never crash the run.
- `results/` holds timestamped outputs; it is generated, not reviewed.
- Thresholds are the author's call: this harness reports numbers, and the
  author picks from them. New metrics need the author too.
