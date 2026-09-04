## Welcome ##

Cactus is an open source problem solving environment designed for scientists and engineers. Its modular structure easily enables parallel computation across different architectures and collaborative code development between different groups. Cactus originated in the academic research community, where it was developed and used over many years by a large international collaboration of physicists and computational scientists.

The name Cactus comes from the design of a central core (*flesh*) which connects to application modules (*thorns*) through an extensible interface. Thorns can implement custom developed scientific or engineering applications, such as computational fluid dynamics. Other thorns from a standard computational toolkit provide a range of computational capabilities, such as parallel I/O, data distribution, or checkpointing.

Cactus runs on many architectures. Applications, developed on standard workstations or laptops, can be seamlessly run on clusters or supercomputers. Cactus provides easy access to many cutting edge software technologies being developed in the academic research community, including the [Globus](http://www.globus.org/) Metacomputing Toolkit, [HDF5](http://www.hdfgroup.org/HDF5/) parallel file I/O, the [PETSc](http://www.mcs.anl.gov/petsc/) scientific library, [adaptive mesh refinement](http://www.carpetcode.org), web interfaces, and advanced visualization tools.

The Cactus user community has created and is maintaining toolkits for several research fields. The [Einstein Toolkit](http://www.einsteintoolkit.org) addresses computational relativistic astrophysics, supporting simulations of black holes, neutron stars, and related systems.

---

## Local feature: conditional `READS:`/`WRITES:` inside a `SCHEDULE` block ##

> **Status:** local, uncommitted change to this flesh checkout (see
> *Implementation* below for the three files involved). A stock Cactus
> checkout does **not** accept this syntax.

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
* Clauses **outside** the conditional apply to both branches; clauses inside
  apply only to their branch. Regions (`(everywhere)`, `(interior)`, ...) work
  as normal.
* `else` is optional. Without it, the false case simply gets the shared clauses.
* Everything else in the block (`LANG:`, `SYNC:`, `STORAGE:`, `OPTIONS:`,
  `TAGS:`, `TRIGGERS:`, the description, `AT`/`IN`/`AS`/`BEFORE`/`AFTER`) stays
  outside the conditional — those cannot vary per branch.

### Restrictions (current implementation) ###

* **One** `if`/`else` per `SCHEDULE` block. A second one is a CST error
  (*"Only one if/else READS/WRITES/INVALIDATES conditional is currently
  supported per SCHEDULE block"*); split the routine, or fall back to the
  top-level form.
* No `else if` chains and no nesting inside the branch bodies. (The top-level
  schedule `if` still supports both.)
* Only `READS:`/`WRITES:`/`INVALIDATES:` may appear in a branch.

### Semantics ###

It is parse-time sugar, expanded by the CST into precisely the duplicated form
shown at the top: two `CCTK_ScheduleFunction` registrations of the *same*
routine, wrapped in a real C `if`/`else` on the condition in the generated
`bindings/Schedule/Schedule<Thorn>.c`. Only one branch's registration ever
executes, so the routine is scheduled exactly once per run, with whichever
READS/WRITES set matches the parameter.

Two consequences worth knowing:

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

### Implementation ###

| File | Change |
|---|---|
| `src/piraha/pegs/schedule.peg` | New `rdwrblock`/`rdwrif` rules; `{rdwrif}` added to the `schedule` body alternation. |
| `lib/sbin/ScheduleParser.pl` | `parse_schedule_statement` handles an `rdwrif` child: emits two `BLOCK_n` database entries (shared clauses merged with each branch's) and the literal C `if`/`else` around their `@BLOCK@n` placeholders. Helpers: `parse_rdwrblock`, `merge_lists`, `write_schedule_block_entry`. |
| `lib/sbin/rdwr.pl` | `do_schedules` now also descends into `rdwrif`/`rdwrblock` when collecting clauses for `cctk_Arguments_Checked.h`, via the factored-out `accumulate_rdwr`; without this the branch-only variables would be missing from `DECLARE_CCTK_ARGUMENTS[X]_<routine>`. |

`lib/sbin/CreateScheduleBindings.pl` needed no changes — the generated-C
substitution path is shared with the pre-existing top-level `if`/`else`.

Note for anyone editing `schedule.peg`: whitespace in a rule's own source text
is what inserts a token skip, so a repeated alternation must be spaced
`( {a} | {b} | {c} )*`. Written compactly as `( {a}|{b}|{c} )*` only the first
alternative gets a leading skip and consecutive clauses of different kinds
misparse.

### Testing ###

An end-to-end regression thorn lives outside this repo, in this checkout at
`arrangements/LocalTest/TestScheduleRdwrIf` (CarpetX/ADMBaseX/HydroBaseX). It
exercises the syntax above and asserts, per branch, that every grid function the
active branch declares has a non-null data pointer and every one it does not
declare is null, and really reads/writes them. Build and run:

```
gmake <config>-config THORNLIST=thornlists/rdwrif_test.th \
      options=thornlists/rdwrif_test_carpetx.OptionList PROMPT=no
./exe/cactus_<config> \
      arrangements/LocalTest/TestScheduleRdwrIf/par/testschedulerdwrif.par
```

Both parameter settings (`TestScheduleRdwrIf::initial_data = "ID_Mag_NS"` and
anything else) must reach `Done.` with no `CCTK_VERROR`. The parfile sets
`Cactus::presync_mode = "presync-only"`; switching it to `"mixed-error"` is a
useful negative control — the null-pointer assertions then fail, confirming they
are not vacuous.
