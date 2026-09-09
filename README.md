## Welcome ##

Cactus is an open source problem solving environment designed for scientists and engineers. Its modular structure easily enables parallel computation across different architectures and collaborative code development between different groups. Cactus originated in the academic research community, where it was developed and used over many years by a large international collaboration of physicists and computational scientists.

The name Cactus comes from the design of a central core (*flesh*) which connects to application modules (*thorns*) through an extensible interface. Thorns can implement custom developed scientific or engineering applications, such as computational fluid dynamics. Other thorns from a standard computational toolkit provide a range of computational capabilities, such as parallel I/O, data distribution, or checkpointing.

Cactus runs on many architectures. Applications, developed on standard workstations or laptops, can be seamlessly run on clusters or supercomputers. Cactus provides easy access to many cutting edge software technologies being developed in the academic research community, including the [Globus](http://www.globus.org/) Metacomputing Toolkit, [HDF5](http://www.hdfgroup.org/HDF5/) parallel file I/O, the [PETSc](http://www.mcs.anl.gov/petsc/) scientific library, [adaptive mesh refinement](http://www.carpetcode.org), web interfaces, and advanced visualization tools.

The Cactus user community has created and is maintaining toolkits for several research fields. The [Einstein Toolkit](http://www.einsteintoolkit.org) addresses computational relativistic astrophysics, supporting simulations of black holes, neutron stars, and related systems.

---

## Local feature: conditional `READS:`/`WRITES:` inside a `SCHEDULE` block ##

> **Status:** local feature branch (`feature/schedule-if`), not upstream and
> not pushed (see *Implementation* below for the three files involved). A
> stock Cactus checkout does **not** accept this syntax.

### What it does ###

`schedule.ccl` has always allowed an `if`/`else` around a *whole* `SCHEDULE`
statement, so varying one routine's data dependencies by parameter meant
duplicating the entire block:

```
if (CCTK_EQUALS(initial_data, "ID_Mag_NS")) {
  SCHEDULE ID_Mag_NS_initialise IN ADMBase_InitialData
  {
    LANG: C
    READS: GRID::coordinates(everywhere)
    WRITES: ADMBASE::metric(everywhere)
    WRITES: HYDROBASE::Bvec(everywhere)
  } "Set up magnetised neutron star initial data"
} else {
  SCHEDULE ID_Mag_NS_initialise IN ADMBase_InitialData
  {
    LANG: C
    READS: GRID::coordinates(everywhere)
    READS: ADMBASE::curv(everywhere)
    WRITES: HYDROBASE::Bvec(everywhere)
  } "Set up magnetised neutron star initial data"
}
```

The `if`/`else` may now go *inside* the block instead, so the shared clauses
(and `LANG`, the description, the scheduling prepositions) are written once and
only the varying clauses sit in the conditional. This is exactly equivalent to
the above:

```
SCHEDULE ID_Mag_NS_initialise IN ADMBase_InitialData
{
  LANG: C
  READS: GRID::coordinates(everywhere)
  if (CCTK_EQUALS(initial_data, "ID_Mag_NS")) {
    WRITES: ADMBASE::metric(everywhere)
  } else {
    READS: ADMBASE::curv(everywhere)
  }
  WRITES: HYDROBASE::Bvec(everywhere)
} "Set up magnetised neutron star initial data"
```

### How to use it ###

* The condition is any boolean expression the existing top-level schedule `if`
  accepts — e.g. `CCTK_EQUALS(param, "value")`, `!CCTK_EQUALS(...)`,
  `a && b`, comparisons. Parameters are referred to unqualified, as usual.
* Each branch body may contain `READS:`, `WRITES:` and `INVALIDATES:` clauses,
  any number of them, in any order.
* Clauses **outside** the conditional apply to every branch; clauses inside
  apply only to their branch. Regions (`(everywhere)`, `(interior)`, ...) work
  as normal.
* `else` is optional. Without it, the false case simply gets the shared clauses.
* **`else if` chains** are supported, to any length:

  ```
  SCHEDULE Foo_Init AT initial
  {
    LANG: C
    if (CCTK_EQUALS(initial_data, "ID_Mag_NS")) {
      WRITES: ADMBASE::metric(everywhere)
    } else if (CCTK_EQUALS(initial_data, "ID_Curv")) {
      READS: ADMBASE::curv(everywhere)
    } else {
      WRITES: ADMBASE::lapse(everywhere)
    }
    WRITES: HYDROBASE::Bvec(everywhere)
  } "..."
  ```

* **Several independent conditionals** may appear in one block. They compose as
  the cartesian product of their branches, so this block covers all four
  combinations of the two parameters:

  ```
  SCHEDULE Foo_Init AT initial
  {
    LANG: C
    if (CCTK_EQUALS(initial_data, "ID_Mag_NS")) {
      WRITES: ADMBASE::metric(everywhere)
    } else {
      READS: ADMBASE::curv(everywhere)
    }
    if (CCTK_EQUALS(shift_data, "zero")) {
      WRITES: ADMBASE::shift(everywhere)
    } else {
      WRITES: ADMBASE::dtlapse(everywhere)
    }
  } "..."
  ```

* Everything else in the block (`LANG:`, `SYNC:`, `STORAGE:`, `OPTIONS:`,
  `TAGS:`, `TRIGGERS:`, the description, `AT`/`IN`/`AS`/`BEFORE`/`AFTER`) stays
  outside the conditionals — those cannot vary per branch.

### Restrictions (current implementation) ###

* Only `READS:`/`WRITES:`/`INVALIDATES:` may appear in a branch body.
* No `if` **nested inside a branch body**. Chains (`else if`) and several
  sibling conditionals in one block are both fine; an `if` *within* a branch's
  `{ ... }` is rejected by the grammar as a syntax error. (The top-level
  schedule `if` does support nesting.)
* The conditionals in one block may not expand to more than 64 registrations
  in total (the product of their branch counts — see *Semantics*). Beyond that
  the CST stops with an explicit error rather than generating thousands of
  registrations; split the routine into several `SCHEDULE` blocks.

### Semantics ###

It is parse-time sugar, expanded by the CST into precisely the duplicated form
shown at the top: one `CCTK_ScheduleFunction` registration of the *same*
routine per branch combination, wrapped in a real C `if`/`else if`/`else` on
the conditions in the generated `bindings/Schedule/Schedule<Thorn>.c`. Only one
combination's registration ever executes, so the routine is scheduled exactly
once per run, with whichever READS/WRITES set matches the parameters.

Counting the registrations: one conditional contributes one branch per
`if`/`else if` arm, plus one for the `else` — and that last one exists as a
registration whether or not you write an `else` (if you don't, it simply gets
no extra clauses). So `if`/`else` is 2 branches, `if`/`else if`/`else` is 3, and
a bare `if` with no `else` is also 2. Independent conditionals in the same block
multiply: a 3-branch chain alongside a 2-branch `if`/`else` gives 3 × 2 = 6
registrations, emitted as nested C conditionals.

Three consequences worth knowing:

* `DECLARE_CCTK_ARGUMENTS_CHECKED(<routine>)` (and the CarpetX
  `DECLARE_CCTK_ARGUMENTSX_<routine>` variant) is a single compile-time macro
  per routine name, so it declares the **union** of both branches' variables —
  every branch's variables are nameable in the C/C++ body regardless of which
  branch is active.
* Which of them are actually *accessible* is decided per call at runtime: with
  `Cactus::presync_mode = "presync-only"`, `CCTK_HasAccess`
  (`src/main/RDWR.cc`) consults the RDWR list of the registration that is
  currently running, and `CCTKi_VarDataPtrI` (`src/main/GroupsOnGH.c`) hands
  back a **NULL** data pointer for a variable the active branch did not declare.
  So the branch that declares `WRITES: ADMBASE::metric` sees a valid `gxx` and a
  null `kxx`, and the branch declaring `READS: ADMBASE::curv` sees the reverse.
  Under any other `presync_mode`, `CCTK_HasAccess` short-circuits and no pointer
  is nulled.
* `INVALIDATES:` in a branch behaves asymmetrically, and both halves are
  upstream behavior rather than anything this feature introduces. At **runtime**
  an INVALIDATES declaration grants access just like READS/WRITES: the clause is
  recorded in the same `f->RDWR` array (`src/main/RDWR.cc:241`) and `hasAccess`
  (`:311`) only checks that an entry *exists* for the variable — it takes an
  `access` member-pointer argument and never reads it. But at **compile time**
  an INVALIDATES-only variable is not named by
  `DECLARE_CCTK_ARGUMENTS[_CHECKED|X]_<routine>` at all, because `rdwr.pl`
  collects only reads/writes for that macro. So such a variable is reachable
  through `CCTKi_VarDataPtrI` yet has no generated pointer name.

### Implementation ###

| File | Change |
|---|---|
| `src/piraha/pegs/schedule.peg` | New `rdwrblock`/`rdwrif` rules; `{rdwrif}` added to the `schedule` body alternation. |
| `lib/sbin/ScheduleParser.pl` | `parse_schedule_statement` collects every `rdwrif` child of the block, then writes one `BLOCK_n` database entry per branch combination (shared clauses merged with that combination's) and emits the nested C scaffold around their `@BLOCK@n` placeholders. Helpers: `parse_rdwrif` (flattens an `else if` chain into arms + else), `rdwrif_leaf`/`rdwrif_nleaves`, `emit_rdwrif_tree` (recurses one conditional per level to produce the cartesian product), plus `parse_rdwrblock`, `merge_lists`, `write_schedule_block_entry`. |
| `lib/sbin/rdwr.pl` | `do_schedules` descends into `rdwrif`/`rdwrblock` when collecting clauses for `cctk_Arguments_Checked.h`, recursing through `else if` chains via `accumulate_rdwrif`; without this the branch-only variables would be missing from `DECLARE_CCTK_ARGUMENTS[X]_<routine>`. |

`lib/sbin/CreateScheduleBindings.pl` needed no changes — the generated-C
substitution path is shared with the pre-existing top-level `if`/`else`.

Note for anyone editing `schedule.peg`: whitespace in a rule's own source text
is what inserts a token skip, so a repeated alternation must be spaced
`( {a} | {b} | {c} )*`. Written compactly as `( {a}|{b}|{c} )*` only the first
alternative gets a leading skip and consecutive clauses of different kinds
misparse.

### Testing ###

An end-to-end regression thorn lives outside this repo, in this checkout at
`arrangements/LocalTest/TestScheduleRdwrIf` (CarpetX/ADMBaseX/HydroBaseX). Its
one schedule block combines three independent conditionals — a 3-arm `else if`
chain (on `initial_data`), a 2-arm `if`/`else` (on `shift_data`), and a bare
`if` with no `else` (on `marker_data`, which exercises the leaf the CST
synthesizes for the missing `else`) — 3 × 2 × 2 = 12 registrations. For every
combination it asserts that each grid function the active combination declares
has a non-null data pointer, each one it does not declare is null, and really
reads/writes the accessible ones. `ADMBASEX::dtshift` additionally appears with
a different clause kind per chain arm (`WRITES`, then `INVALIDATES`, then
absent), covering `INVALIDATES:` inside a branch. Build and run:

```
gmake <config>-config THORNLIST=thornlists/rdwrif_test.th \
      options=thornlists/rdwrif_test_carpetx.OptionList PROMPT=no
./exe/cactus_<config> \
      arrangements/LocalTest/TestScheduleRdwrIf/par/testschedulerdwrif.par
```

All twelve combinations of `TestScheduleRdwrIf::initial_data`
(`ID_Mag_NS`/`ID_Curv`/`none`), `TestScheduleRdwrIf::shift_data`
(`zero`/`none`) and `TestScheduleRdwrIf::marker_data` (`extra`/`none`) must
reach `Done.` with no `CCTK_VERROR`. The parfile sets
`Cactus::presync_mode = "presync-only"`; switching it to `"mixed-error"` is a
useful negative control — the null-pointer assertions then fail, confirming they
are not vacuous.
