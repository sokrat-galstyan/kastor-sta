# Hand calculation

Use the inputs in [circuit.json](circuit.json), all in picoseconds. Delays are
fixed illustrative assumptions for one ordered path.

```text
input       gate_a_out       gate_b_in       output
  o --[20]--> o -----[5]-----> o --[30]------> o
      cell            wire          cell
```

| Point | Arithmetic (ps) | Expected arrival (ps) |
| --- | --- | --- |
| input | given | 10 |
| gate_a_out | 10 + 20 | 30 |
| gate_b_in | 10 + 20 + 5 | 35 |
| output | 10 + 20 + 5 + 30 | 65 |

These values are derived independently of the executable calculation and
transcribed into [expected.json](expected.json). The verifier checks all four
values, not just the final result. This checks arithmetic under the stated
assumptions; it does not validate a physical delay model.
