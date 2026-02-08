---
name: enumerable-refactor
description: This skill should be used when users request refactoring Ruby code to use Enumerable methods instead of manual iteration with empty variable initialization. Use when reviewing Ruby code that initializes empty arrays, hashes, strings, or counters and then populates them with .each loops. Targets Ruby 3.3+. Use when users mention "enumerable", "refactor each", "ruby iteration", or when reviewing Ruby code for idiomatic collection processing.
---

# Enumerable Refactor

## Overview

This skill identifies and refactors the most common Ruby anti-pattern: initializing an empty variable and populating it with `.each`. Almost every time you see this pattern, a purpose-built Enumerable method exists that is more concise, expressive, and often more performant.

## The Core Anti-Pattern

```ruby
# ANY time you see this shape, it can almost certainly be refactored:
result = []        # or {}, 0, "", Set.new, false, nil
something.each do |item|
  # ... build up result ...
end
result
```

## When to Use This Skill

Apply when:
- Reviewing or refactoring Ruby code that uses `.each` to build return values
- User asks to make Ruby code more idiomatic
- User mentions "enumerable", "refactoring", or "each loop"
- You spot the empty-variable-then-each pattern during code review

Do NOT apply when:
- The `.each` loop is purely for side effects (sending emails, writing to DB, printing)
- The loop has complex control flow (`retry`, exception handling) that genuinely resists functional expression
- The imperative version is genuinely clearer for the specific case

## Workflow

### 1. Find the Anti-Patterns

Search the codebase for the telltale signs:

```
# Search for empty array initialization followed by .each
Grep for: "= \[\]\s*$" in *.rb files
Grep for: "= {}\s*$" in *.rb files
Grep for: "= 0\s*$" in *.rb files
Grep for: "= \"\"\s*$" in *.rb files
Grep for: "= Set.new" in *.rb files
Grep for: "= false\s*$" in *.rb files
```

Then check if those initializations are followed by `.each` within a few lines.

Load the reference for the full pattern catalog:
```
Read references/patterns.md
```

### 2. Classify Each Instance

For each anti-pattern found, identify what the `.each` loop is doing:

| Loop behavior | Replace with |
|---|---|
| Transforming each element into a new array | `map` |
| Transforming + flattening nested arrays | `flat_map` |
| Transforming + removing nils | `filter_map` |
| Keeping elements that match a condition | `select` / `filter` |
| Removing elements that match a condition | `reject` |
| Building a hash from a collection | `to_h { \|x\| [k, v] }` |
| Building a hash with conditional/complex logic | `each_with_object({})` |
| Grouping elements by a key | `group_by` |
| Splitting into two groups (true/false) | `partition` |
| Summing numbers | `sum` |
| Counting matches | `count` |
| Building a frequency hash | `tally` |
| Finding the first match | `find` / `detect` |
| Finding min/max by attribute | `min_by` / `max_by` |
| Setting a boolean flag | `any?` / `all?` / `none?` |
| Joining strings | `join` or `map { ... }.join` |
| Accumulating a single immutable value | `reduce` / `inject` |

### 3. Refactor

For each instance, apply the replacement. Show before/after. Verify behavior is preserved.

**Key rules:**
- Use `each_with_object` for mutable accumulators (Hash, Array, Set), NOT `inject`
- Use `inject`/`reduce` only for immutable accumulation (numbers, frozen strings)
- Prefer `filter_map` over `.select.map` or `.map.compact` (single pass)
- Prefer `tally` over `Hash.new(0)` + `.each` for frequency counting
- Prefer `to_h { |x| [k, v] }` over `each_with_object({})` for simple key-value mappings
- Prefer `partition` over two separate `select`/`reject` calls
- Prefer `sort_by` over `sort` with a comparison block

### 4. Check for Chaining Opportunities

After individual refactors, look for method chains that can be simplified:

```ruby
# Two passes -> one pass
users.select(&:active?).map(&:email)
# becomes
users.filter_map { |u| u.email if u.active? }

# Unnecessary intermediate array
departments.map(&:employees).flatten
# becomes
departments.flat_map(&:employees)

# Two separate iterations for min and max
lowest = temps.min
highest = temps.max
# becomes
lowest, highest = temps.minmax
```

### 5. Verify

- Ensure the refactored code produces the same result
- Run tests if available
- Check for subtle differences (e.g., `filter_map` removes `false` values, not just `nil`)

## Important Caveats

1. **`filter_map` drops `false` too**: If the transformation can legitimately return `false`, use `.map.compact` instead.

2. **`inject` hash bug**: Never use `inject` to build a hash — `Hash#[]=` returns the value, not the hash. Use `each_with_object` instead.

3. **Lazy evaluation**: For very large collections where you only need the first N results, suggest `.lazy` before the chain.

4. **Rails extensions**: In Rails codebases, also suggest `index_by`, `index_with`, `pluck`, `excluding`, and `sole` where appropriate.

5. **Side effects are OK with `.each`**: Not every `.each` is an anti-pattern. If the loop body performs side effects and doesn't build a return value, `.each` is the right choice.
