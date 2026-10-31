"""Milvus Lite: one dense + sparse vector per item, for hybrid search (RRF) within a time
window. Only the worker opens it: a local directory (`OSMS_MILVUS_PATH`, default
`data/milvus.db`) served by Milvus Lite in a child process (`milvus_server`); SQLite stays
the record of which story an item is in.

Milvus Lite has no authentication: it listens on 127.0.0.1 only, never a public port."""

import atexit
import signal
import socket
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path

from pymilvus import AnnSearchRequest, DataType, MilvusClient, RRFRanker

from app.services.embeddings import Embedding, cosine

COLLECTION = "items"
# pymilvus pings every 10 s; Milvus Lite's gRPC server allows one every 5 minutes and
# answers more with GOAWAY ("too_many_pings"), dropping the connection mid-job.
_GRPC_OPTIONS = {"grpc.keepalive_time_ms": 360_000, "grpc.keepalive_permit_without_calls": False}


@dataclass(frozen=True)
class Neighbour:
    item_id: int
    similarity: float  # dense cosine: how close in meaning


class LiteServer:
    """Milvus Lite on a free 127.0.0.1 port, for as long as this process needs it."""

    START_TIMEOUT_S = 60.0

    def __init__(self, data_dir: str) -> None:
        Path(data_dir).parent.mkdir(parents=True, exist_ok=True)
        with socket.socket() as probe:
            probe.bind(("127.0.0.1", 0))
            port = probe.getsockname()[1]
        self.uri = f"http://127.0.0.1:{port}"
        self.process = subprocess.Popen([sys.executable, "-m", "app.db.milvus_server", data_dir, str(port)])
        atexit.register(self.stop)
        deadline = time.monotonic() + self.START_TIMEOUT_S
        while True:
            if self.process.poll() is not None:
                raise RuntimeError(f"Milvus Lite stopped on start (is another worker using {data_dir}?)")
            try:
                socket.create_connection(("127.0.0.1", port), timeout=1).close()
                return
            except OSError:
                if time.monotonic() > deadline:
                    self.stop()
                    raise RuntimeError("Milvus Lite didn't start in time") from None
                time.sleep(0.2)

    def stop(self) -> None:
        if self.process.poll() is None:
            self.process.send_signal(signal.SIGINT)  # Its clean shutdown: drain, then close the files.
            try:
                self.process.wait(timeout=15)
            except subprocess.TimeoutExpired:
                self.process.kill()
                self.process.wait()


class VectorIndex:
    def __init__(self, uri: str, *, dim: int) -> None:
        self.server = None
        options = {}
        if "://" not in uri:
            self.server = LiteServer(uri)
            uri, options = self.server.uri, {"grpc_options": _GRPC_OPTIONS}
        self.client = MilvusClient(uri, **options)
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
        else:
            self.client.load_collection(COLLECTION)  # A new process finds it released.

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
        if self.server:
            self.server.stop()
