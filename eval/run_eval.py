"""Clustering eval: pairwise precision/recall and B-cubed F1.

Usage:  python run_eval.py labels/ predictions.json [--out results/]

`predictions.json` is the pipeline's answer: {item_id: story_id}. Prints the
two metric triples with group/item counts and writes a timestamped JSON
result. With no labels yet it says so and exits 0: nothing to score is
normal, not an error.
"""

from __future__ import annotations

import argparse
import json
import sys
from datetime import UTC, datetime
from pathlib import Path

from labels import LabelError, load_labels
from metrics import bcubed_scores, pairwise_scores


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("labels", help="directory of hand-labelled *.json files")
    parser.add_argument("predictions", nargs="?", help="JSON file mapping item id to story id")
    parser.add_argument("--out", default="results", help="where to write the timestamped result")
    args = parser.parse_args(argv)

    try:
        gold = load_labels(args.labels)
    except LabelError as error:
        print(f"labels: {error}", file=sys.stderr)
        return 2
    if not gold:
        print("nothing to score: no labelled groups yet")
        return 0
    if not args.predictions:
        print(f"{len(gold)} labelled groups, {sum(map(len, gold))} items; pass a predictions file to score it")
        return 0

    try:
        predicted = json.loads(Path(args.predictions).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        print(f"predictions: {error}", file=sys.stderr)
        return 2
    if not isinstance(predicted, dict):
        print("predictions: want {item_id: story_id}", file=sys.stderr)
        return 2

    try:
        pair_p, pair_r, pair_f = pairwise_scores(gold, predicted)
        b3_p, b3_r, b3_f = bcubed_scores(gold, predicted)
    except ValueError as error:
        print(f"score: {error}", file=sys.stderr)
        return 2

    result = {
        "at": datetime.now(UTC).isoformat(timespec="seconds"),
        "groups": len(gold),
        "items": sum(map(len, gold)),
        "stories": len(set(predicted.values())),
        "pairwise": {"precision": pair_p, "recall": pair_r, "f1": pair_f},
        "bcubed": {"precision": b3_p, "recall": b3_r, "f1": b3_f},
    }
    print(f"groups={result['groups']} items={result['items']} stories={result['stories']}")
    print(f"pairwise  P={pair_p:.3f} R={pair_r:.3f} F1={pair_f:.3f}")
    print(f"b-cubed   P={b3_p:.3f} R={b3_r:.3f} F1={b3_f:.3f}")
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    path = out / f"{datetime.now(UTC).strftime('%Y%m%dT%H%M%SZ')}.json"
    path.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
