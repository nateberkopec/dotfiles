# CLAUDE.md

This file provides guidance to Claude Code for this project.

## Testing Principles

### Don't Test Types or Data

Never test the type or shape of return values. Tests should verify behavior, not implementation details or data structures.

Bad:
```ruby
def test_complete_returns_boolean
  result = @step.complete?
  assert [true, false].include?(result)
end
```

Good:
```ruby
def test_complete_returns_true_by_default
  assert @step.complete?
end
```

### Test Meaningful Assertions

Each public method should have a test for its default return value with no setup.

When testing that a method returns the same value as its default, first establish setup that would make it return the opposite without your intervention. Otherwise the test is meaningless.

For example, if `should_run?` returns false by default, a test asserting `should_run?` is false when CI=true is meaningless unless you also do setup that would cause `should_run?` to return true without the CI check.

Bad:
```ruby
def test_should_run_returns_false_in_ci
  ENV["CI"] = "true"
  refute @step.should_run?
end
```

Good:
```ruby
def test_should_run_returns_false_in_ci
  stub_admin_with_updates  # Without CI, this would return true
  with_ci { refute @step.should_run? }
end
```

### Keep Variables Local

Variables should live as close as possible to where they're used. Don't put them in setup or as constants at the top of the test class. This makes tests easier to read because you don't have to jump around the file to understand what's happening.

Bad:
```ruby
def setup
  @plist_path = "/Library/Preferences/com.apple.SoftwareUpdate.plist"
end

def stub_plist
  @fake_system.stub_file_content(@plist_path, "plist")
end
```

Good:
```ruby
def stub_plist
  plist_path = "/Library/Preferences/com.apple.SoftwareUpdate.plist"
  @fake_system.stub_file_content(plist_path, "plist")
end
```
