# frozen_string_literal: true

module AgentSkillEvalChecks
  private

  def eval_errors(path)
    eval_path = File.join(File.dirname(path), "evals", "evals.json")
    return [] unless File.exist?(eval_path)

    data = JSON.parse(File.read(eval_path))
    evals = data.is_a?(Hash) ? data.fetch("evals", []) : data
    ids = evals.filter_map { |item| item["id"] if item.is_a?(Hash) }
    return [] if ids.empty? || ids == (ids.first..ids.first + ids.length - 1).to_a

    [finding("eval-quality-issues", "Behavioral eval IDs must be sequential", eval_path)]
  end
end
