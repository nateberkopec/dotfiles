# AGENTS.md

These are my dotfiles. See README.md.

## CI

- CI usually takes about 10 minutes to finish running.

## Ruby

Keep files ~100 LOC. Split as needed.

### Testing Principles

- Never test the type or shape of return values. Tests should verify behavior, not implementation details or data structures.
- Each public method should have a test for its default return value with no setup.
- When testing that a method returns the same value as its default, first establish setup that would make it return the opposite without your intervention. Otherwise the test is meaningless.
- Keep variables as close as possible to where they're used. Don't put them in setup or as constants at the top of the test class.

