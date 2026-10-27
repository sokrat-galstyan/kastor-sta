# Sample research experiment files

These files demonstrate formats for preserving a small numerical experiment.
Keep or replace them when actual research experiments are added. They are not
a completed research topic or a production timing analyzer.

Use the [research-note template](../../docs/research/template.md) for findings
and the [research guide](../../docs/process/research.md) for conventions.
Related: [issue #22](https://github.com/sokrat-galstyan/kastor-sta/issues/22).

## Files

| File | Purpose |
| --- | --- |
| [circuit.json](circuit.json) | Authoritative topology and numerical inputs |
| [calculations.md](calculations.md) | Diagram and independent hand calculation |
| [expected.json](expected.json) | Expected values transcribed from that calculation |
| [verify.py](verify.py) | Calculate values and compare them with expectations |

These files share one flat folder. Create only the files a real experiment
needs; short calculations and results may live in its README instead.
Actual research folders use their primary note's `NNN-short-topic` name.

## Scope and input format

The sample contains one ordered path with fixed integer delays in picoseconds.
There is no branching, clock, rise/fall distinction, or setup/hold analysis.
Values are illustrative assumptions, not cell-library measurements.

`circuit.json` contains:

- `unit`: `ps`, used for every time value.
- `startpoint` and `arrival_ps`: starting point name and integer arrival.
- `segments`: ordered increments, each with a unique `endpoint` name and a
  nonnegative integer `delay_ps`.

The script expects reviewed fixture files, not arbitrary user input.
Unsupported units fail explicitly; malformed fixtures cause Python errors.
The calculator receives only circuit inputs. The verifier reads expected
values separately and compares the complete mapping using exact equality.
No rounding or numerical tolerance applies to these integer values.

## Reproduce

Use Python 3.10 or newer and its standard library. From the repository root:

```sh
python3 --version
python3 experiments/research-output-example/verify.py
```

The script also works from another working directory. It prints calculated
values and PASS on agreement, and exits unsuccessfully on disagreement. It
does not change inputs, expected values, or recorded results. All sample data
is project-authored; no downloads or dependencies are required.

## Results

The reproduction command above was run on 2026-10-27 using Python 3.12.3 and
the standard library. Inputs, expected values, and the script are versioned
together with this record.

Observed output, with exit status zero:

```text
{
  "input": 10,
  "gate_a_out": 30,
  "gate_b_in": 35,
  "output": 65
}
PASS: all arrivals match independent expected values
```

All values matched exactly in integer picoseconds. This record is observed
output, not the source of expected values. It verifies only the sample's
arithmetic, not a physical timing model or complete STA implementation.
