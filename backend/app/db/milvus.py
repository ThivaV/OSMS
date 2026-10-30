"""Milvus Lite: one dense + sparse vector per item, for hybrid search (RRF) within a time
window. Only the worker opens it, so it runs embedded on a local file (`MILVUS_URI`,
default `data/milvus.db`); SQLite stays the record of which story an item is in.

Milvus Lite has no authentication: it is a file, never a port."""

from dataclasses import dataclass
from pathlib import Path

from pymilvus import AnnSearchRequest, DataType, MilvusClient, RRFRanker

from app.services.embeddings import Embedding, cosine

COLLECTION = "items"


@dataclass(frozen=True)
class Neighbour:
    item_id: int
    similarity: float  # dense cosine: how close in meaning


class VectorIndex:
    def __init__(self, uri: str, *, dim: int) -> None:
        if "://" not in uri:
            Path(uri).parent.mkdir(parents=True, exist_ok=True)
        self.client = MilvusClient(uri)
        self.dim = dim
        if not self.client.has_collection(COLLECTION):
            schema = self.client.create_schema(auto_id=False)
            schema.add_field("id", DataType.INT64, is_primary=True)
            schema.add_field("dense", DataType.FLOAT_VECTOR, dim=dim)
            schema.add_field("sparse", DataType.SPARSE_FLOAT_VECTOR)
            schema.add_field("published", DataType.INT64)
            index = self.client.prepare_index_params()
            index.add_index("dense", index_type="AUTOINDEX", metric_type="COSINE")
            index.add_index("sparse", index_type="SPARSE_INVERTED_INDEX", metric_type="IP")
            self.client.create_collection(COLLECTION, schema=schema, index_params=index)

    def upsert(self, item_id: int, embedding: Embedding, published_ts: int) -> None:
        sparse = embedding.sparse or {0: 1e-6}  # Milvus refuses an empty sparse vector.
        self.client.upsert(
            COLLECTION, [{"id": item_id, "dense": embedding.dense, "sparse": sparse, "published": published_ts}]
        )

    def neighbours(
        self, embedding: Embedding, *, since_ts: int, until_ts: int, exclude: int, limit: int = 10
    ) -> list[Neighbour]:
        """Candidates by hybrid search (dense + sparse, RRF), scored by dense cosine."""
        expr = f"published >= {since_ts} and published <= {until_ts} and id != {exclude}"
        requests = [
            AnnSearchRequest([embedding.dense], "dense", {"metric_type": "COSINE"}, limit=limit, expr=expr),
        ]
        if embedding.sparse:
            requests.append(AnnSearchRequest([embedding.sparse], "sparse", {"metric_type": "IP"}, limit=limit, expr=expr))
        hits = self.client.hybrid_search(COLLECTION, requests, RRFRanker(), limit=limit)[0]
        ids = [int(hit["id"]) for hit in hits]
        if not ids:
            return []
        stored = {int(row["id"]): row["dense"] for row in self.client.get(COLLECTION, ids=ids, output_fields=["dense"])}
        found = [Neighbour(i, cosine(embedding.dense, list(stored[i]))) for i in ids if i in stored]
        return sorted(found, key=lambda n: n.similarity, reverse=True)

    def delete(self, item_ids: list[int]) -> None:
        if item_ids:
            self.client.delete(COLLECTION, ids=item_ids)

    def close(self) -> None:
        self.client.close()
