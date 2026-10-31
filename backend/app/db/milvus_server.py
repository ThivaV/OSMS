"""Milvus Lite in its own process, started and stopped by `VectorIndex`.

Milvus Lite runs faiss, and on macOS faiss and torch (BGE-M3) each bundle their own
OpenMP runtime: in one process the second to start aborts it. So the index gets its own
process, bound to 127.0.0.1 only, and it shuts down cleanly (Ctrl+C's path) when the
worker that started it is gone, even if the worker was killed.

    python -m app.db.milvus_server DATA_DIR PORT
"""

import os
import signal
import sys
import threading
import time

from milvus_lite.adapter.grpc.server import run_server


def main() -> None:
    data_dir, port, parent = sys.argv[1], int(sys.argv[2]), os.getppid()

    def watch_parent() -> None:
        while os.getppid() == parent:
            time.sleep(1)
        os.kill(os.getpid(), signal.SIGINT)

    threading.Thread(target=watch_parent, daemon=True).start()
    run_server(data_dir=data_dir, host="127.0.0.1", port=port)


if __name__ == "__main__":
    main()
