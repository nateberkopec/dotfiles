---
name: codebase-design
description: Shared vocabulary for designing deep modules. Use to improve an interface, place a seam, find deepening opportunities, or make code more testable and AI-navigable.
---

# Codebase design

Design **deep modules**: substantial behavior behind a small interface at a clean seam, testable through that interface. Use this vocabulary consistently:

- **Module** — anything with an interface and implementation, from function to package.
- **Interface** — everything callers must know: signatures, invariants, ordering, errors, configuration, and performance.
- **Implementation** — behavior hidden inside a module.
- **Depth** — leverage per unit of interface; deep modules hide much behind little.
- **Seam** — a place where behavior can change without editing there.
- **Adapter** — a concrete implementation satisfying an interface at a seam.
- **Leverage** — capability callers gain from depth.
- **Locality** — change, knowledge, bugs, and verification concentrated behind the interface.

## Core principles

- Measure depth at the interface, not by implementation size.
- Apply the deletion test: deleting a valuable module redistributes complexity to callers; deleting a pass-through removes it.
- Make the interface the shared caller and test surface.
- Reduce methods and parameters while hiding more policy.
- Accept dependencies at the seam and return results where practical.

When deepening an existing cluster and deciding how dependencies cross its seam, read [DEEPENING.md](DEEPENING.md). It is authoritative for dependency categories, adapter discipline, internal versus external seams, and replace-don’t-layer testing.

When the interface has meaningful alternatives, read [DESIGN-IT-TWICE.md](DESIGN-IT-TWICE.md). Generate distinct designs, then compare depth, locality, and seam placement rather than polishing the first idea.

Completion means the chosen module has one intelligible interface, callers need less knowledge than before, dependencies cross deliberate seams, and tests exercise behavior through the same surface callers use.
