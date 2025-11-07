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
   ./bin/dotf run
   ```

   The script automatically detects your Ruby version and bootstraps a modern Ruby environment if needed.

   To see detailed output during installation:
   ```bash
   DEBUG=true ./bin/dotf run
   ```

## Usage

```bash
dotf <command>
```

**Commands:**
- `dotf run` - Set up development environment. Idempotent - safe to run on an already-configured system. Only runs steps that haven't been completed.
- `dotf update` - Update dotfiles from the system
- `dotf help` - Show help message

## How It Works: Steps

The setup process is organized into modular Steps. Each step is a Ruby class that inherits from the `Step` base class and implements a specific part of the setup process.

### Available Steps

For details on what each step does, see the implementations in [lib/step/](lib/step/).

Steps are executed in dependency order, automatically sorted by their `depends_on` declarations.

### Implementing Your Own Steps

To learn how to create new steps, see [docs/implementing-steps.md](docs/implementing-steps.md).
