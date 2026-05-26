function fish_should_add_to_history --description 'Skip sensitive commands and leading-space commands in fish history'
  set -l commandline $argv[1]

  switch $commandline
    case '' ' *'
      return 1
  end

  set -l lower_commandline (string lower -- "$commandline" | string collect)

  switch $lower_commandline
    case '*api*' '*token*' '*secret*' '*password*' '*passwd*' '*private*key*' '*access*key*' '*authorization*' '*bearer*'
      string match --quiet --regex '(^|[[:space:];|&$])([a-z_][a-z0-9_]*(api[_-]?key|apikey|token|secret|password|passwd|private[_-]?key|access[_-]?key|client[_-]?secret|authorization|bearer)[a-z0-9_]*)([[:space:]]*=|[[:space:]]+|$)' -- "$lower_commandline"; and return 1
      string match --quiet --regex '(authorization:[^[:space:]]{8,}|bearer[[:space:]]+[a-z0-9._~+/=-]{16,})' -- "$lower_commandline"; and return 1
    case '*sk-or-v1-*' '*sk-ant-api03-*' '*github_pat_*' '*ghp_*' '*gho_*' '*ghu_*' '*ghs_*' '*ghr_*' '*glpat-*' '*xoxb-*' '*xoxa-*' '*xoxp-*' '*xoxr-*' '*xoxs-*' '*pplx-*' '*rubygems_*'
      string match --quiet --regex '(sk-or-v1-[a-z0-9_-]{20,}|sk-ant-api03-[a-z0-9_-]{20,}|sk-[a-z0-9_-]{20,}|github_pat_[a-z0-9_]{20,}|gh[pousr]_[a-z0-9_]{20,}|glpat-[a-z0-9_-]{20,}|xox[baprs]-[a-z0-9-]{20,}|pplx-[a-z0-9]{20,}|rubygems_[a-z0-9]{20,})' -- "$lower_commandline"; and return 1
  end

  return 0
end
