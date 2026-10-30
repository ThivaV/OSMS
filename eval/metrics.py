"""Clustering metrics: pairwise precision/recall/F1 and B-cubed, as specified.

Pure functions, stdlib only. Conventions (fixed here, so every run agrees):

- A predicted id missing from the labels is an error, never a silent skip:
  an unscored item must fail loudly, not flatter the score by disappearing.
- Labels may group nothing (no pairs): then pairwise precision is 1.0 only
  when the prediction also pairs nothing, else 0.0. Recall over zero gold
  pairs is 1.0 only when nothing is predicted alongside them... in practice:
  empty gold raises, because scoring nothing measures nothing.
- B-cubed averages per-item precision/recall over labelled items only.
"""

from __future__ import annotations

from itertools import combinations


def _pairs(groups: list[frozenset[str]]) -> set[frozenset[str]]:
    """Unordered same-story pairs across groups."""
    found: set[frozenset[str]] = set()
    for group in groups:
        for first, second in combinations(sorted(group), 2):
            found.add(frozenset((first, second)))
    return found


def pairwise_scores(
    gold: list[frozenset[str]], predicted: dict[str, str]
) -> tuple[float, float, float]:
    """Fraction of predicted pairs that are truly same-story (precision) and
    of true pairs the prediction kept together (recall), plus F1."""
    if not gold:
        raise ValueError("no labelled groups: scoring nothing measures nothing")
    labelled = set().union(*gold)
    unknown = set(predicted) - labelled
    if unknown:
        raise ValueError(f"predictions for unlabelled items: {sorted(unknown)[:5]}")
    gold_pairs = _pairs(gold)
    by_story: dict[str, set[str]] = {}
    for item, story in predicted.items():
        by_story.setdefault(story, set()).add(item)
    pred_pairs = _pairs([frozenset(members) for members in by_story.values()])
    true_positives = len(gold_pairs & pred_pairs)
    if not pred_pairs:
        precision = 1.0 if not gold_pairs else 0.0
    else:
        precision = true_positives / len(pred_pairs)
    recall = true_positives / len(gold_pairs) if gold_pairs else 1.0
    return precision, recall, _f1(precision, recall)


def bcubed_scores(
    gold: list[frozenset[str]], predicted: dict[str, str]
) -> tuple[float, float, float]:
    """Per item: of its predicted story-mates, how many share its gold story
    (precision); of its gold story-mates, how many share its prediction
    (recall). Averaged over labelled items, plus F1 of the averages."""
    if not gold:
        raise ValueError("no labelled groups: scoring nothing measures nothing")
    labelled = set().union(*gold)
    unknown = set(predicted) - labelled
    if unknown:
        raise ValueError(f"predictions for unlabelled items: {sorted(unknown)[:5]}")
    gold_of = {item: group for group in gold for item in group}
    precisions: list[float] = []
    recalls: list[float] = []
    for item in sorted(labelled):
        mates = {other for other, story in predicted.items() if story == predicted.get(item)}
        mates.discard(item)
        gold_mates = set(gold_of[item]) - {item}
        precisions.append(len(mates & gold_mates) / len(mates) if mates else (1.0 if not gold_mates else 0.0))
        recalls.append(len(mates & gold_mates) / len(gold_mates) if gold_mates else 1.0)
    precision = sum(precisions) / len(precisions)
    recall = sum(recalls) / len(recalls)
    return precision, recall, _f1(precision, recall)


def _f1(precision: float, recall: float) -> float:
    if precision + recall == 0:
        return 0.0
    return 2 * precision * recall / (precision + recall)
