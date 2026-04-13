# Enumerable Anti-Pattern Replacement Catalog

Complete reference of empty-variable-then-each anti-patterns and their Enumerable replacements. Ruby 3.3+.

---

## 1. Accumulation Patterns

### `map`

```ruby
# BEFORE
results = []
users.each do |user|
  results << user.name.upcase
end
results

# AFTER
users.map { |user| user.name.upcase }
```

### `flat_map`

```ruby
# BEFORE
results = []
departments.each do |dept|
  dept.employees.each do |emp|
    results << emp
  end
end
results

# ALSO BAD
departments.map(&:employees).flatten

# AFTER
departments.flat_map(&:employees)
```

`flat_map` is more efficient than `.map.flatten` — no intermediate nested array. Only flattens one level.

### `filter_map` (Ruby 2.7+)

```ruby
# BEFORE
results = []
users.each do |user|
  results << user.email if user.active?
end
results

# ALSO BAD (two passes)
users.select(&:active?).map(&:email)

# ALSO BAD (intermediate nils)
users.map { |u| u.email if u.active? }.compact

# AFTER
users.filter_map { |u| u.email if u.active? }
```

**Gotcha**: `filter_map` removes `false` values too, not just `nil`. If your transformation can legitimately return `false`, use `.map.compact` instead.

### `each_with_object`

For mutable accumulators (Hash, Array, Set).

```ruby
# BEFORE
hash = {}
users.each do |user|
  hash[user.id] = user.name
end
hash

# AFTER
users.each_with_object({}) do |user, hash|
  hash[user.id] = user.name
end
```

```ruby
# BEFORE
set = Set.new
items.each do |item|
  set.add(item.category) if item.active?
end
set

# AFTER
items.each_with_object(Set.new) do |item, set|
  set.add(item.category) if item.active?
end
```

Key advantage over `inject`: you don't need to return the accumulator from the block.

### `inject` / `reduce`

For immutable accumulation only (numbers, frozen strings).

```ruby
# BEFORE
total = 0
orders.each do |order|
  total += order.amount
end
total

# AFTER (but .sum is even better)
orders.inject(0) { |total, order| total + order.amount }

# BEST
orders.sum(&:amount)
```

**Never use `inject` to build a hash:**

```ruby
# BUG: Hash#[]= returns the value, not the hash
users.inject({}) do |hash, user|
  hash[user.id] = user.name
  # Must explicitly return hash, easy to forget
end

# Use each_with_object instead
```

---

## 2. Filtering Patterns

### `select` / `filter`

```ruby
# BEFORE
active = []
users.each do |user|
  active << user if user.active?
end
active

# AFTER
users.select(&:active?)
```

### `reject`

```ruby
# BEFORE
not_admins = []
users.each do |user|
  not_admins << user unless user.admin?
end
not_admins

# AFTER
users.reject(&:admin?)
```

Prefer `reject` over `select` with negated condition.

### `grep` / `grep_v`

```ruby
# BEFORE
strings = []
items.each do |item|
  strings << item if item.is_a?(String)
end
strings

# AFTER
items.grep(String)

# Filter by regex
names.grep(/^A/)

# grep with transformation (filter + map in one)
items.grep(Numeric) { |n| n * 2 }

# Inverse
items.grep_v(/test/)
```

`grep` uses `===` — works with classes, ranges, regexps, and procs.

---

## 3. Grouping and Partitioning

### `group_by`

```ruby
# BEFORE
by_status = {}
orders.each do |order|
  by_status[order.status] ||= []
  by_status[order.status] << order
end
by_status

# AFTER
orders.group_by(&:status)
```

### `partition`

```ruby
# BEFORE
active = []
inactive = []
users.each do |user|
  if user.active?
    active << user
  else
    inactive << user
  end
end

# AFTER
active, inactive = users.partition(&:active?)
```

Single pass. Better than separate `select`/`reject` calls.

### `chunk`

Groups consecutive elements sharing a property (unlike `group_by` which groups all elements).

```ruby
# BEFORE
groups = []
current_group = nil
temperatures.each do |temp|
  category = temp >= 100 ? :hot : :cold
  if current_group && current_group[0] == category
    current_group[1] << temp
  else
    current_group = [category, [temp]]
    groups << current_group
  end
end

# AFTER
temperatures.chunk { |t| t >= 100 ? :hot : :cold }.to_a
```

### `chunk_while` / `slice_when`

```ruby
# Group consecutive integers
[1, 2, 3, 7, 8, 9, 15].chunk_while { |a, b| b == a + 1 }.to_a
# => [[1, 2, 3], [7, 8, 9], [15]]

# slice_when is the inverse — slices when condition IS true
[1, 2, 3, 7, 8, 9, 15].slice_when { |a, b| b != a + 1 }.to_a
```

### `slice_before` / `slice_after`

```ruby
# Split log entries (each starts with a timestamp)
log_lines.slice_before(/^\d{4}-\d{2}-\d{2}/).to_a
```

---

## 4. Finding

### `find` / `detect`

```ruby
# BEFORE
found = nil
users.each do |user|
  if user.admin?
    found = user
    break
  end
end
found

# AFTER
users.find(&:admin?)
```

### `find_index`

```ruby
# BEFORE
idx = nil
items.each_with_index do |item, i|
  if item.special?
    idx = i
    break
  end
end

# AFTER
items.find_index(&:special?)
```

### `min_by` / `max_by`

```ruby
# BEFORE
cheapest = nil
products.each do |product|
  if cheapest.nil? || product.price < cheapest.price
    cheapest = product
  end
end

# AFTER
products.min_by(&:price)

# Get N results
products.min_by(3, &:price)
```

### `minmax` / `minmax_by`

```ruby
# BEFORE (two passes)
lowest = temps.min
highest = temps.max

# AFTER (single pass)
lowest, highest = temps.minmax
youngest, oldest = users.minmax_by(&:age)
```

---

## 5. Boolean Queries

### `any?`

```ruby
# BEFORE
has_admin = false
users.each do |user|
  if user.admin?
    has_admin = true
    break
  end
end

# AFTER
users.any?(&:admin?)

# Pattern matching (Ruby 2.5+)
[1, "two", 3].any?(String)  # => true
```

### `all?`

```ruby
# BEFORE
all_valid = true
records.each do |record|
  unless record.valid?
    all_valid = false
    break
  end
end

# AFTER
records.all?(&:valid?)
```

### `none?`

```ruby
# BEFORE
no_errors = true
results.each do |r|
  if r.error?
    no_errors = false
    break
  end
end

# AFTER
results.none?(&:error?)
```

### `one?`

```ruby
# BEFORE
count = 0
users.each do |u|
  count += 1 if u.admin?
  break if count > 1
end
count == 1

# AFTER
users.one?(&:admin?)
```

### `include?`

```ruby
# BEFORE
found = false
items.each do |item|
  if item == target
    found = true
    break
  end
end

# AFTER
items.include?(target)
```

For large collections, use `Set#include?` (O(1) vs O(n)).

---

## 6. Counting and Tallying

### `count`

```ruby
# BEFORE
n = 0
users.each { |u| n += 1 if u.active? }

# AFTER
users.count(&:active?)
```

### `tally` (Ruby 2.7+)

```ruby
# BEFORE
counts = Hash.new(0)
words.each { |w| counts[w] += 1 }

# AFTER
words.tally
# => { "hello" => 3, "world" => 2 }
```

For tally-by-attribute:

```ruby
users.map(&:role).tally
# or
users.group_by(&:role).transform_values(&:count)
```

### `sum` (Ruby 2.4+)

```ruby
# BEFORE
total = 0
orders.each { |o| total += o.amount }

# AFTER
orders.sum(&:amount)
orders.sum { |o| o.quantity * o.price }
[1, 2, 3].sum  # => 6
```

For strings, use `.join` instead (much faster).

---

## 7. Hash Building

### `to_h` with block (Ruby 2.6+)

```ruby
# BEFORE
hash = {}
users.each { |u| hash[u.id] = u.name }

# AFTER
users.to_h { |u| [u.id, u.name] }
```

Most elegant for simple key-value mappings.

### `each_with_object({})` for complex cases

```ruby
# Conditional entries, multiple values per key
items.each_with_object(Hash.new { |h, k| h[k] = [] }) do |item, result|
  result[item.category] << item.name if item.active?
end
```

### `transform_values` / `transform_keys` (Ruby 2.4+/2.5+)

```ruby
# BEFORE
result = {}
prices.each { |item, price| result[item] = price * 1.1 }

# AFTER
prices.transform_values { |price| price * 1.1 }
headers.transform_keys(&:downcase)
```

### Rails: `index_by` / `index_with`

```ruby
# index_by: collection elements as values, block result as keys
users.index_by(&:id)
# Pure Ruby: users.to_h { |u| [u.id, u] }

# index_with: collection elements as keys
columns.index_with(0)
columns.index_with { |col| col.default_value }
```

---

## 8. String Building

### `join`

```ruby
# BEFORE
result = ""
names.each_with_index do |name, i|
  result += ", " unless i == 0
  result += name
end

# AFTER
names.join(", ")
```

### `map` + `join`

```ruby
# BEFORE
html = ""
items.each { |item| html += "<li>#{item.name}</li>" }

# AFTER
items.map { |item| "<li>#{item.name}</li>" }.join("\n")
```

---

## 9. Sorting

### `sort_by`

```ruby
# BEFORE (inefficient — calls block on every comparison)
users.sort { |a, b| a.last_name <=> b.last_name }

# AFTER (Schwartzian Transform — calls block once per element)
users.sort_by(&:last_name)

# Multiple criteria
users.sort_by { |u| [u.last_name, u.first_name] }

# Descending
users.sort_by { |u| -u.age }
```

---

## 10. Iteration Helpers

### `each_with_index`

```ruby
# BEFORE
i = 0
items.each do |item|
  puts "#{i}: #{item}"
  i += 1
end

# AFTER
items.each_with_index do |item, i|
  puts "#{i}: #{item}"
end
```

### `each_cons` (sliding window)

```ruby
# BEFORE
(0...(items.length - 1)).each do |i|
  current = items[i]
  next_item = items[i + 1]
end

# AFTER
items.each_cons(2) do |current, next_item|
  # ...
end
```

### `each_slice` (batching)

```ruby
items.each_slice(100) do |batch|
  process(batch)
end
```

### `zip`

```ruby
# BEFORE
results = []
names.length.times do |i|
  results << [names[i], scores[i]]
end

# AFTER
names.zip(scores)
```

---

## 11. Taking and Dropping

### `take_while` / `drop_while`

```ruby
# BEFORE
result = []
items.each do |item|
  break unless item.valid?
  result << item
end

# AFTER
items.take_while(&:valid?)
```

```ruby
# BEFORE
started = false
result = []
lines.each do |line|
  started = true if line.match?(/BEGIN/)
  result << line if started
end

# AFTER
lines.drop_while { |line| !line.match?(/BEGIN/) }
```

---

## 12. Lazy Evaluation

```ruby
# BEFORE (processes ALL elements, then takes 5)
huge_list.select(&:valid?).map(&:name).first(5)

# AFTER (stops after finding 5 valid elements)
huge_list.lazy.select(&:valid?).map(&:name).first(5)
```

---

## 13. Chain Simplifications

Common multi-method chains that can be collapsed:

```ruby
# Two passes -> one
users.select(&:active?).map(&:email)  =>  users.filter_map { |u| u.email if u.active? }

# Unnecessary flatten
items.map(&:tags).flatten  =>  items.flat_map(&:tags)

# Two iterations for extremes
[items.min, items.max]  =>  items.minmax

# Separate select + reject
active = users.select(&:active?)
inactive = users.reject(&:active?)
# =>
active, inactive = users.partition(&:active?)

# map + compact
users.map { |u| u.nickname }.compact  =>  users.filter_map(&:nickname)

# group_by + count
items.group_by(&:type).map { |k, v| [k, v.size] }.to_h
# =>
items.map(&:type).tally
```

---

## Quick Reference

| You want to... | Use |
|---|---|
| Transform each element | `map` |
| Transform + flatten one level | `flat_map` |
| Transform + remove nils | `filter_map` |
| Keep matching elements | `select` / `filter` |
| Remove matching elements | `reject` |
| Filter by class/regex/range | `grep` |
| Build hash (simple k-v) | `to_h { \|x\| [k, v] }` |
| Build hash (complex logic) | `each_with_object({})` |
| Group by criterion | `group_by` |
| Split into two groups | `partition` |
| Group consecutive matches | `chunk` |
| Sum numbers | `sum` |
| Count matches | `count` |
| Frequency hash | `tally` |
| Find first match | `find` |
| Find extreme values | `min_by` / `max_by` |
| Check any/all/none match | `any?` / `all?` / `none?` |
| Join into string | `join` |
| Sort by attribute | `sort_by` |
| Sliding window | `each_cons` |
| Process in batches | `each_slice` |
| Take from front conditionally | `take_while` |
| Skip from front conditionally | `drop_while` |
