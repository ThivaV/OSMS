"""Eval harness tests: hand-computed numbers, no fixtures, stdlib only.

Run from this directory:  python3 -m unittest -v  (or `make eval-test`).
"""

import json
import tempfile
import unittest
from pathlib import Path

from labels import LabelError, load_labels
from metrics import bcubed_scores, pairwise_scores
from run_eval import main

GOLD = [frozenset({"a", "b", "c"}), frozenset({"d", "e"})]  # gold pairs: ab ac bc de


class PairwiseTest(unittest.TestCase):
    def test_mixed_prediction(self) -> None:
        pred = {"a": "s1", "b": "s1", "d": "s1", "c": "s2", "e": "s2"}
        self.assertEqual(pairwise_scores(GOLD, pred), (0.25, 0.25, 0.25))

    def test_perfect(self) -> None:
        pred = {"a": "s1", "b": "s1", "c": "s1", "d": "s2", "e": "s2"}
        self.assertEqual(pairwise_scores(GOLD, pred), (1.0, 1.0, 1.0))

    def test_all_singletons(self) -> None:
        pred = {item: item for item in "abcde"}
        self.assertEqual(pairwise_scores(GOLD, pred), (0.0, 0.0, 0.0))

    def test_empty_gold_measures_nothing(self) -> None:
        with self.assertRaises(ValueError):
            pairwise_scores([], {"a": "s1"})

    def test_unknown_predictions_fail_loudly(self) -> None:
        with self.assertRaises(ValueError):
            pairwise_scores(GOLD, {"a": "s1", "zzz": "s1"})


class BCubedTest(unittest.TestCase):
    def test_mixed_prediction(self) -> None:
        pred = {"a": "s1", "b": "s1", "d": "s1", "c": "s2", "e": "s2"}
        precision, recall, f1 = bcubed_scores(GOLD, pred)
        self.assertAlmostEqual(precision, 0.2)
        self.assertAlmostEqual(recall, 0.2)
        self.assertAlmostEqual(f1, 0.2)

    def test_perfect(self) -> None:
        pred = {"a": "s1", "b": "s1", "c": "s1", "d": "s2", "e": "s2"}
        self.assertEqual(bcubed_scores(GOLD, pred), (1.0, 1.0, 1.0))

    def test_all_singletons(self) -> None:
        pred = {item: item for item in "abcde"}
        self.assertEqual(bcubed_scores(GOLD, pred), (0.0, 0.0, 0.0))

    def test_empty_gold_measures_nothing(self) -> None:
        with self.assertRaises(ValueError):
            bcubed_scores([], {"a": "s1"})


def _labels_file(directory: Path, name: str, document: object) -> None:
    (directory / name).write_text(json.dumps(document), encoding="utf-8")


class LabelsTest(unittest.TestCase):
    def test_valid_directory(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            _labels_file(
                root,
                "tech.json",
                {"version": 1, "groups": [{"id": "g1", "items": [{"id": "a", "link": "https://a.example/1"}]}]},
            )
            self.assertEqual(load_labels(root), [frozenset({"a"})])

    def test_text_keys_refused(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            _labels_file(
                root, "bad.json", {"version": 1, "groups": [{"id": "g", "items": [{"id": "a", "text": "full"}]}]}
            )
            with self.assertRaises(LabelError):
                load_labels(root)

    def test_duplicate_ids_refused(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            item = {"id": "a", "link": "https://a.example/1"}
            _labels_file(root, "one.json", {"version": 1, "groups": [{"id": "g1", "items": [item]}]})
            _labels_file(root, "two.json", {"version": 1, "groups": [{"id": "g2", "items": [item]}]})
            with self.assertRaises(LabelError):
                load_labels(root)

    def test_bad_links_and_versions_refused(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            _labels_file(root, "bad.json", {"version": 1, "groups": [{"id": "g", "items": [{"id": "a"}]}]})
            with self.assertRaises(LabelError):
                load_labels(root)
            _labels_file(root, "bad.json", {"version": 999, "groups": []})
            with self.assertRaises(LabelError):
                load_labels(root)


class RunnerTest(unittest.TestCase):
    def test_no_labels_is_not_an_error(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            self.assertEqual(main([tmp]), 0)

    def test_perfect_run_writes_a_result(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            labels = root / "labels"
            labels.mkdir()
            _labels_file(
                labels,
                "g.json",
                {
                    "version": 1,
                    "groups": [
                        {"id": "g1", "items": [{"id": "a", "link": "https://a.example"}, {"id": "b", "link": "https://b.example"}]}
                    ],
                },
            )
            pred = root / "pred.json"
            pred.write_text(json.dumps({"a": "s", "b": "s"}), encoding="utf-8")
            self.assertEqual(main([str(labels), str(pred), "--out", str(root / "results")]), 0)
            (result_file,) = (root / "results").glob("*.json")
            result = json.loads(result_file.read_text(encoding="utf-8"))
            self.assertEqual(result["pairwise"]["f1"], 1.0)
            self.assertEqual(result["bcubed"]["f1"], 1.0)


if __name__ == "__main__":
    unittest.main()
