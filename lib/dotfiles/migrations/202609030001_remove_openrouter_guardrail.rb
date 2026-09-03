class Dotfiles::Migration::RemoveOpenRouterGuardrail < Dotfiles::Migration
  VERSION = 202609030001

  def up
    retired_paths.each { |path| @system.rm_rf(path) }
  end

  def down
    raise NotImplementedError, "This migration removes the retired OpenRouter guardrail and cannot be safely reversed."
  end

  private

  def retired_paths
    agent_dir = File.join(@home, ".pi", "agent")
    [
      File.join(agent_dir, "extensions", "openrouter_guardrail"),
      File.join(agent_dir, "cache", "openrouter-guardrail-models.json"),
      File.join(agent_dir, "cache", "openrouter-guardrail-performance.json")
    ]
  end
end
