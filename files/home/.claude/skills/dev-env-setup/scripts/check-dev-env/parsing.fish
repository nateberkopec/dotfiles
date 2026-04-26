function env_file_keys
    set file $argv[1]
    if not test -f "$file"
        return 0
    end

    for line in (string split \n -- (cat "$file"))
        set trimmed (string trim -- "$line")
        if test -z "$trimmed"
            continue
        end
        if string match -q '#*' -- "$trimmed"
            continue
        end

        set matches (string match -r '^(?:export[ \t]+)?([A-Za-z_][A-Za-z0-9_]*)[ \t]*=' -- "$trimmed")
        if test (count $matches) -gt 1
            echo $matches[2]
        end
    end
end

function mise_task_names
    set task_names

    if test -n "$mise_file"
        for line in (cat "$mise_file")
            if string match -rq '^\[tasks[.\[]["\']*([a-zA-Z0-9_:.-]+)' -- "$line"
                set -a task_names (string match -r '^\[tasks[.\[]["\']*([a-zA-Z0-9_:.-]+)' -- "$line")[2]
            end
        end
    end

    if command -q mise
        set mise_task_output (builtin cd "$target_dir"; and mise tasks 2>/dev/null)
        for line in $mise_task_output
            set task_name (string split -m1 " " -- "$line")[1]
            if test -n "$task_name"
                set -a task_names "$task_name"
            end
        end
    end

    printf "%s\n" $task_names
end

function mise_file_has_section
    set section_name (string escape --style=regex -- $argv[1])
    string match -rq "^\\s*\\[$section_name\\]" -- (cat "$mise_file")
end

function mise_task_has_key
    set target_task $argv[1]
    set key_name (string escape --style=regex -- $argv[2])
    set in_task 0

    while read -l line
        set task_header (string match -r "^\\s*\\[tasks[.\\[]['\"]?([A-Za-z0-9_:.-]+)" -- "$line")
        if test (count $task_header) -gt 1
            if test "$task_header[2]" = "$target_task"
                set in_task 1
            else
                set in_task 0
            end
        else if string match -rq "^\\s*\\[" -- "$line"
            set in_task 0
        end

        if test $in_task -eq 1; and string match -rq "^\\s*$key_name\\s*=" -- "$line"
            return 0
        end
    end < "$mise_file"

    return 1
end

function long_mise_task_run_blocks
    set file $argv[1]
    set current_task ""
    set in_run_block 0
    set run_task ""
    set run_lines 0

    while read -l line
        if test $in_run_block -eq 1
            set trimmed (string trim -- "$line")
            if test "$trimmed" = '"""'; or test "$trimmed" = "'''"
                if test $run_lines -gt 10
                    echo "$run_task|$run_lines"
                end
                set in_run_block 0
                set run_task ""
                set run_lines 0
            else
                set run_lines (math $run_lines + 1)
            end
            continue
        end

        set task_header (string match -r "^\\s*\\[tasks[.\\[]['\"]?([A-Za-z0-9_:.-]+)" -- "$line")
        if test (count $task_header) -gt 1
            set current_task $task_header[2]
        else if string match -rq "^\\s*\\[" -- "$line"
            set current_task ""
        end

        if test -n "$current_task"; and string match -rq "^\\s*run\\s*=\\s*([\"']{3})\\s*\$" -- "$line"
            set in_run_block 1
            set run_task "$current_task"
            set run_lines 0
        end
    end < "$file"
end
