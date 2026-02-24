function mise-check-updates --description "Refresh mise metadata and show newest available tool versions"
  mise cache clear; or return $status
  mise plugins update; or return $status
  mise outdated --bump $argv
end
