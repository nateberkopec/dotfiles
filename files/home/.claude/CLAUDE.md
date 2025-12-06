# CLAUDE.md

## Shell

I use fish shell.

Use `gum` to make your shell scripts pretty and fun!

- gum choose: Choose an option from a list of choices
- gum confirm: Ask a user to confirm an action
- gum file: Pick a file from a folder
- gum filter: Filter items from a list
- gum format: Format a string using a template
- gum input: Prompt for some input
- gum join: Join text vertically or horizontally
- gum pager: Scroll through a file
- gum spin: Display spinner while running a command
- gum style: Apply coloring, borders, spacing to text
- gum table: Render a table of data
- gum write: Prompt for long-form text
- gum log: Log messages to output

## Github

Use `gh` cli for all github interactions.

Whenever you open a pull request with `gh pr`, leave the description blank.

## ast-grep

`ast-grep` is available. Use it when searching/refactoring code.

## Ruby

### Testing Principles

- Never test the type or shape of return values. Tests should verify behavior, not implementation details or data structures.
- Each public method should have a test for its default return value with no setup.
- When testing that a method returns the same value as its default, first establish setup that would make it return the opposite without your intervention. Otherwise the test is meaningless.
- Keep variables as close as possible to where they're used. Don't put them in setup or as constants at the top of the test class.

### Code Style

- Use boolean expressions with implicit return for predicate methods, not guard clauses or case statements with literal true/false.
