# Dotfiles

Personal configuration files for my development environment.

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/nateberkopec/dotfiles.git ~/.dotfiles
   ```

2. Run the setup:
   ```bash
   cd ~/.dotfiles
   ./bin/dot run
   ```

   The script automatically detects your Ruby version and bootstraps a modern Ruby environment if needed.

   To see detailed output during installation:
   ```bash
   DEBUG=true ./bin/dot run
   ```

## Usage

```bash
dot <command>
```

**Commands:**
- `dot run` - Set up development environment. Idempotent - safe to run on an already-configured system. Only runs steps that haven't been completed.
- `dot update` - Update dotfiles from the system
- `dot help` - Show help message

## How It Works: Steps

The setup process is organized into modular Steps. Each step is a Ruby class that inherits from the `Step` base class and implements a specific part of the setup process.

### Step Interface

Steps must implement these methods:

- `run` - Executes the setup action
- `complete?` - Returns true if the step has already been completed
- `update` (optional) - Syncs configuration from the system back to the dotfiles repo

Steps can also define:

- `self.depends_on` - Returns an array of step classes that must run first
- `should_run?` - Returns true if the step should execute (default: `!complete?`)

### Available Steps

For details on what each step does, see the implementations in [lib/step/](lib/step/).

Steps are executed in dependency order, automatically sorted by their `depends_on` declarations.
