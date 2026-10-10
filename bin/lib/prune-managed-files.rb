require_relative "pruning/paths"
require_relative "pruning/hooks"
require_relative "pruning/inventory"
require_relative "pruning/ledger"
require_relative "pruning/reconciler"

begin
  root = File.realpath(ENV.fetch("DOTFILES_DIR", File.expand_path("../..", __dir__)))
  home = ManagedPruning::Paths.new(ENV.fetch("HOME"))
  hooks = ManagedPruning::Hooks.new
  ledger = ManagedPruning::Ledger.new(home, hooks)
  ledger.synchronize do
    current = ManagedPruning::Inventory.new(root, home, hooks).read
    ManagedPruning::Reconciler.new(home, hooks, ledger).run(current)
  end
rescue => error
  abort "Dotfiles pruning failed: #{error.message}"
end
