function mlx --description "Run the latest version of a mise-managed command"
  if test (count $argv) -eq 0
    echo "Usage: mlx COMMAND [ARGUMENTS...]" >&2
    return 2
  end

  set -l bin $argv[1]
  set -e argv[1]
  set -l tool (mise which "$bin" --plugin); or return
  set -lx MISE_MINIMUM_RELEASE_AGE 0s

  if string match -q "npm:*" "$tool"
    set -l package (string replace "npm:" "" "$tool")
    set -l exclusion "$package"

    if string match -q "@*/*" "$package"
      set exclusion (string replace -r '^(@[^/]+)/.*$' '$1/*' "$package")
    end

    if set -q AUBE_MINIMUM_RELEASE_AGE_EXCLUDE
      set exclusion "$AUBE_MINIMUM_RELEASE_AGE_EXCLUDE,$exclusion"
    end

    set -fx AUBE_MINIMUM_RELEASE_AGE_EXCLUDE "$exclusion"
  end

  mise x "$tool"@latest -- "$bin" $argv
end
