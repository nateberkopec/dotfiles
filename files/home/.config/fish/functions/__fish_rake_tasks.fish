function __fish_rake_tasks
    rake -AT 2>/dev/null | string replace -r '^rake (\S+)\s+# (.*)' '$1\t$2'
end
