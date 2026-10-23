"""One active reading session; persist only the elapsed, uncommitted interval."""

import time


class ReadingSession:
    def __init__(self, record, clock=time.monotonic):
        self._record = record
        self._clock = clock
        self._book_id = ""
        self._checkpoint = None

    def start(self, book_id: str) -> None:
        if self._book_id == book_id:
            return
        self.end()
        if book_id:
            self._book_id = book_id
            self._checkpoint = self._clock()

    def flush(self) -> None:
        if not self._book_id or self._checkpoint is None:
            return
        now = self._clock()
        elapsed = max(0, now - self._checkpoint) / 60
        if elapsed > 0:
            self._record(self._book_id, elapsed)
        self._checkpoint = now

    def end(self) -> None:
        self.flush()
        self._book_id = ""
        self._checkpoint = None
