"""Verify the sample experiment against independently derived values."""

import json
from pathlib import Path
from typing import TypedDict


class Segment(TypedDict):
    """A fixed delay in ps ending at a uniquely named point on the path."""

    endpoint: str
    delay_ps: int


class Circuit(TypedDict):
    """Reviewed path input with ps units and ordered nonnegative delays."""

    unit: str
    startpoint: str
    arrival_ps: int
    segments: list[Segment]


def calculate_arrivals(circuit: Circuit) -> dict[str, int]:
    """Accumulate arrivals for a reviewed single-path fixture.

    Args:
        circuit: Ordered path with integer ps values and unique point names.

    Returns:
        Each point's integer arrival in ps, including the startpoint.

    Raises:
        ValueError: The input unit is unsupported.

    Complexity:
        O(n) time and output space for n segments.
    """
    if circuit["unit"] != "ps":
        raise ValueError("This fixture supports only integer ps inputs")
    arrival = circuit["arrival_ps"]
    arrivals = {circuit["startpoint"]: arrival}
    for segment in circuit["segments"]:
        arrival += segment["delay_ps"]
        arrivals[segment["endpoint"]] = arrival
    return arrivals


def main() -> None:
    """Compare the bundled fixture with independent expected arrivals.

    Prints calculated values and PASS on agreement; modifies no files.

    Raises:
        OSError: A fixture cannot be read.
        ValueError: JSON, units, or the comparison is invalid.
        KeyError: A required fixture field is absent.
        TypeError: A fixture value has an incompatible type.

    Complexity:
        O(n) time and space in fixture size.
    """
    folder = Path(__file__).resolve().parent
    circuit = json.loads((folder / "circuit.json").read_text(encoding="utf-8"))
    expected_text = (folder / "expected.json").read_text(encoding="utf-8")
    expected = json.loads(expected_text)
    actual = calculate_arrivals(circuit)
    if actual != expected:
        raise ValueError(f"Arrival mismatch: {actual!r} != {expected!r}")
    print(json.dumps(actual, indent=2))
    print("PASS: all arrivals match independent expected values")


if __name__ == "__main__":
    main()
