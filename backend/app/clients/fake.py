"""Scripted text models for tests: agent code runs with zero network calls."""

from app.agent.runtime import ModelStep


class FakeModelClient:
    """Each `step()` pops the next scripted `ModelStep`, or raises the next
    scripted exception (a fake outage). Every call is recorded."""

    def __init__(self, script: list[ModelStep | Exception]) -> None:
        self._script = list(script)
        self.calls: list[dict] = []

    def step(self, *, system: str, messages: list[dict[str, str]], tools: list[dict], agent: str) -> ModelStep:
        self.calls.append({"agent": agent, "messages": len(messages), "tools": len(tools)})
        if not self._script:
            raise AssertionError("fake model ran out of scripted steps")
        acted = self._script.pop(0)
        if isinstance(acted, Exception):
            raise acted
        return acted
