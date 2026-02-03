if test -d "$HOME/.local/bin"
  fish_add_path -g "$HOME/.local/bin"
end

function __local_bin_first --on-event fish_preexec
  if test -d "$HOME/.local/bin"
    fish_add_path -m "$HOME/.local/bin"
  end
end
