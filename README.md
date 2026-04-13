# CS292C Homework 2: Formal Verification of Programs and Agent Policies

**Out:** Lecture 8 (4/23) | **Due:** Lecture 11 (5/5) 11:59pm | **Weight:** 10%

## Overview

In this assignment you will use **Z3** (via its Python bindings) to formally verify imperative programs and agent security policies. The assignment has five problems spanning Hoare logic, VCG, SMT-based policy analysis, and runtime trace verification.

**What makes this assignment hard:** You will not be given the formulas to encode. You must *derive* loop invariants, *design* policy models, *diagnose* bugs in broken verifiers, and *explain* counterexamples. Generating code is the easy part — understanding why it works (or doesn't) is the point.

**Language:** Python 3.10+ with [z3-solver](https://pypi.org/project/z3-solver/).

## Setup

```bash
pip install z3-solver
```

Verify:
```bash
python3 -c "from z3 import *; x = Int('x'); print(simplify(x + 0))"
```

## Submission

Push all work to this repo before the deadline. Your repo should contain:

1. All `.py` files with completed implementations.
2. A **writeup.pdf** containing:
   - Pen-and-paper derivations (Problems 1c, 2a).
   - English explanations where marked **[EXPLAIN]**.
   - All program output (copy-paste or screenshot).
3. Run `bash check.sh` before submitting.

## Files

| File | Problem | Points | Topic |
|------|---------|--------|-------|
| `p1_z3_warmup.py` | Problem 1 | 15 | Z3 warm-up + EUF puzzle |
| `p2_vcgen.py` | Problem 2 | 30 | VCG implementation + invariant discovery |
| `p3_agent_policy.py` | Problem 3 | 25 | Agent permission policy analysis |
| `p4_tool_chain.py` | Problem 4 | 20 | DFA monitors + bounded trace verification |
| `p5_bonus.py` | Problem 5 | 10 | Bonus: verified skill composition |

---

## Problem 1: Z3 Warm-Up + EUF Puzzle (15 points)

This problem gets you comfortable with the Z3 API and tests your understanding of SMT theories.

**Part (a) — 3 pts:** Solve a system of integer constraints. *(Straightforward — read the skeleton.)*

**Part (b) — 3 pts:** Prove a universally quantified statement valid using Z3.

**Part (c) — 5 pts: The EUF Puzzle [PEN-AND-PAPER + CODE]**

Consider the following formula over an uninterpreted function `f`:

```
f(f(x)) = x  ∧  f(f(f(x))) = x  ∧  f(x) ≠ x
```

1. **Before running Z3**, work out by hand whether this is satisfiable or unsatisfiable. Show your reasoning in your writeup (hint: what can you derive about `f(x)` by applying `f` to both sides of the first equation?). This is worth 3 of the 5 points.
2. Then check your answer with Z3. If SAT, print the model.

**Part (d) — 4 pts:** Using Z3's array theory, prove the **read-over-write axiom** and the **read-over-write-miss axiom** (two separate checks):

```
(1)  i = j  →  Select(Store(a, i, v), j) = v
(2)  i ≠ j  →  Select(Store(a, i, v), j) = Select(a, j)
```

**[EXPLAIN]** In 2–3 sentences: why are these two axioms together sufficient to fully characterize the behavior of `Store` and `Select`?

---

## Problem 2: Hoare Logic VCG for IMP (30 points)

### Part (a) — Pen-and-Paper Derivation (6 pts) [WRITEUP ONLY]

Manually compute the weakest precondition of the following program with respect to the given postcondition. Show every step of the wp computation (no Z3 — just algebra).

```
{ ??? }
x := x + 1;
if x > 0 then
  y := x * 2
else
  y := 0 - x;
{ y > 0 }
```

State the weakest precondition you computed. Then: is `{ x >= 0 }` a valid precondition? Is `{ x > -1 }` ? Justify each answer.

### Part (b) — Implement the VCG (12 pts)

Complete the `wp()` and `verify()` functions in `p2_vcgen.py`. The IMP AST and Z3 translation helpers are provided. Your `wp()` must handle:

| Statement | wp(S, Q) |
|-----------|----------|
| `x := e` | `Q[x ↦ e]` |
| `s1; s2` | `wp(s1, wp(s2, Q))` |
| `if b then s1 else s2` | `(b → wp(s1, Q)) ∧ (¬b → wp(s2, Q))` |
| `while b inv I do s` | `I` (+ side VCs for preservation and postcondition) |
| `assert P` | `P ∧ Q` |
| `assume P` | `P → Q` |

Verify the two provided test programs (swap and absolute value) to confirm your VCG works.

### Part (c) — Invariant Discovery (8 pts)

The skeleton provides **three programs without loop invariants**. For each one, you must:

1. **Discover** a correct loop invariant.
2. Add it to the program and verify it passes your VCG.
3. **[EXPLAIN]** In 2–3 sentences, describe *how* you found the invariant and *why* it works.

The programs are:

**Program C1 — Multiplication by addition:**
```
{ a >= 0 }
i := 0; r := 0;
while i < a  invariant ???  do
  r := r + b;
  i := i + 1;
{ r == a * b }
```

**Program C2 — Power of 2:**
```
{ n >= 0 }
i := 0; p := 1;
while i < n  invariant ???  do
  p := p * 2;
  i := i + 1;
{ p == 2^n }
```
*(Hint: Z3 does not have a built-in power operator. Think about how to express `2^n` using the variables available in the loop.)*

**Program C3 — Sum of first n integers:**
```
{ n >= 1 }
i := 1; s := 0;
while i <= n  invariant ???  do
  s := s + i;
  i := i + 1;
{ 2 * s == n * (n + 1) }
```

### Part (d) — Find the Bug (4 pts)

The skeleton contains a function `test_buggy_div()` that attempts to verify an integer division program. The invariant provided is **wrong** — it is too weak. Your VCG should report that verification fails.

1. Run it and confirm it fails.
2. **[EXPLAIN]** Which side VC fails (preservation or postcondition)? Why?  Give a concrete state (values of `q`, `r`, `x`, `y`) where the invariant holds but the postcondition does not.
3. **Fix** the invariant and re-verify.

---

## Problem 3: Agent Permission Policy Verification (25 points)

### Part (a) — Encode the Policy (10 pts)

An agent operates with three roles (`admin`, `developer`, `viewer`) and four tools (`file_read`, `file_write`, `shell_exec`, `network_fetch`). Resources have attributes: `is_sensitive` and `in_sandbox`.

Encode the following rules as Z3 constraints using uninterpreted sorts and functions. **You must design the encoding yourself** — the skeleton provides only the sorts and function signatures.

| # | Rule |
|---|------|
| R1 | Viewers may only `file_read` non-sensitive resources. |
| R2 | Developers may `file_read` anything and `file_write` resources they own or that are in the sandbox. |
| R3 | Admins may use any tool on any resource. |
| R4 | **Nobody** may `shell_exec` on sensitive resources (overrides R3). |
| R5 | `network_fetch` is allowed only on sandbox resources. |

### Part (b) — Policy Queries (8 pts)

Use Z3 to answer:

1. Can a developer write to a sensitive file they don't own that is in the sandbox?
2. Can an admin `network_fetch` a resource outside the sandbox?
3. Is there *any* role that can `shell_exec` on a sensitive resource?
4. **[EXPLAIN]** Suppose we remove rule R4. What is the most dangerous action that becomes possible? Use Z3 to demonstrate it.

### Part (c) — Privilege Escalation (7 pts)

Suppose developers can invoke `shell_exec` on non-sensitive sandbox resources (new rule R6). A clever attacker notices that one `shell_exec` target lets them run `chmod` to change a file's sensitivity flag.

Model this as a **2-step trace**: the developer first calls `shell_exec` to change a resource's sensitivity, then calls `shell_exec` again on the (now non-sensitive) resource.

1. Encode this in Z3 and check: can the developer effectively bypass R4?
2. **[EXPLAIN]** Propose a fix (a new constraint) that prevents this escalation. Implement it and verify with Z3.

---

## Problem 4: DFA Monitors + Bounded Trace Verification (20 points)

This problem connects runtime monitoring (Lecture 10) with SMT-based verification (Lecture 7).

### Part (a) — Implement DFA Monitors (8 pts)

Implement three runtime monitors as Python classes in `p4_tool_chain.py`. Each monitor processes a stream of tool-call events and returns `ALLOW` or `DENY`.

| Monitor | Policy |
|---------|--------|
| `SandboxMonitor` | Deny any `file_write` where `path` is outside the sandbox directory. |
| `ReadBeforeWriteMonitor` | Deny any `file_write` to a path that hasn't been `file_read` first. |
| `NoExfilMonitor` | After any `file_read` of a sensitive resource, deny all subsequent `network_fetch` calls. |

The monitors must be **stateful** (they track what has happened so far). Test each on the provided trace examples.

### Part (b) — Bounded Trace Verification with Z3 (8 pts)

Now verify the **same three properties** using Z3 bounded model checking (trace length `k = 8`).

For each property:
1. Encode the trace symbolically (tool type + target at each step).
2. Assert the **negation** of the property (looking for a violation).
3. If SAT, print the counterexample trace. If UNSAT, the property holds for all traces up to length k.

**[EXPLAIN]** Compare the DFA monitor approach with the Z3 bounded approach: what does each one catch that the other might miss?

### Part (c) — Monitor Completeness (4 pts)

The `ComposedMonitor` runs all three monitors in parallel. Find a trace of length 6 that:
1. Is **accepted** by the composed monitor (all three monitors allow every step), AND
2. Is still **dangerous** — it violates a property not covered by any of the three monitors.

Describe the property being violated and **[EXPLAIN]** why the monitors miss it.

---

## Problem 5: Bonus — Verified Skill Composition (10 points)

Two agent skills are composed sequentially:

- **Skill A** reads a file and extracts a list of URLs. Postcondition: `urls_extracted ∧ file_unchanged`.
- **Skill B** fetches each URL and writes results to an output file. Postcondition: `output_written ∧ no_other_files_modified`.

The composed skill should satisfy: `file_unchanged ∧ output_written ∧ no_other_files_modified`.

**Part (a):** Using Z3 arrays to model the filesystem (array from path-ID to content-hash), encode Skills A and B as Hoare triples and verify the composed postcondition using the sequence rule.

**Part (b):** Introduce a bug: Skill B accidentally overwrites the input file (writes to the same path Skill A read from). Show that the composed postcondition fails and print the Z3 counterexample.

**Part (c): [EXPLAIN]** In 3–4 sentences, connect this to the real world: how does this kind of composition bug manifest in actual agent workflows? Give a concrete example from your experience with Claude Code or similar tools.

---

## Grading

| Problem | Points |
|---------|--------|
| Problem 1: Z3 Warm-Up + EUF Puzzle | 15 |
| Problem 2: VCG + Invariant Discovery | 30 |
| Problem 3: Agent Permission Policies | 25 |
| Problem 4: DFA Monitors + Bounded Verification | 20 |
| Problem 5: Bonus — Skill Composition | 10 |
| **Total** | **90 + 10 bonus** |

## Tips

- **Start with Problem 1** to get comfortable with Z3 before tackling harder problems.
- **Problem 2c is the hardest part** — budget extra time for invariant discovery.
- The [Z3 Python tutorial](https://ericpony.github.io/z3py-tutorial/guide-examples.htm) is an excellent reference.
- For substitution in Problem 2, Z3's `substitute()` function is your friend.
- For Problem 3, `ForAll` lets you write universally quantified constraints.
- 8 free late days are shared across all assignments.

## Academic Integrity

Using AI coding assistants is permitted and encouraged. You must understand and be able to explain every line of your submission. All AI-generated content must be attributed. The **[EXPLAIN]** and **pen-and-paper** sections are specifically designed to test understanding — vague or generic explanations will receive zero credit. The instructor reserves the right to conduct oral examinations.
