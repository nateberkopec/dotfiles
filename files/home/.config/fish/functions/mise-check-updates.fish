function mise-check-updates --description "Refresh mise metadata and show actionable tool updates"
  mise cache clear; or return $status
  mise plugins update; or return $status

  set -l rows (
    mise outdated --json 2>/dev/null \
      | jq -r '
          to_entries
          | map(.value)
          | map(select(
              (.current | type) == "string" and
              (.latest | type) == "string" and
              (.current | test("^v?[0-9]")) and
              (.latest | test("^v?[0-9]")) and
              .current != .latest
            ))
          | .[]
          | [ .name, .requested, .current, .latest, .source.path ]
          | @tsv
        '
  )

  if test (count $rows) -eq 0
    gum style --foreground 2 --border rounded --padding "0 1" "No actionable mise updates."
    return 0
  end

  gum style --foreground 6 "Actionable mise updates: "(count $rows)

  begin
    printf 'name\trequested\tcurrent\tlatest\tsource\n'
    printf '%s\n' $rows
  end | gum table --border rounded --print
end
