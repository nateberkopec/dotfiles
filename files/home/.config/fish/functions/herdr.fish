function herdr --wraps herdr
    if test (count $argv) -gt 0; or test "$HERDR_ENV" = 1
        command herdr $argv
        return $status
    end

    set -l directory (pwd -P)
    set -l home (path resolve "$HOME")
    set -l gtd (path resolve "$HOME/Documents/Code.nosync/personal/gtd")
    set -l dotfiles (path resolve "$HOME/.dotfiles")
    if test "$directory" = "$home"; or contains -- "$directory" "$gtd" "$dotfiles"; or string match -q -- "$gtd/*" "$directory"; or string match -q -- "$dotfiles/*" "$directory"
        command ruby "$HOME/.local/share/dotfiles/herdr-launch.rb"
    else
        command herdr
    end
end
