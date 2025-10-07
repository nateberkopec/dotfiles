function gc-ai
    # Check required dependencies
    if not command -q gum
        echo "Error: gum is not installed. Install it from https://github.com/charmbracelet/gum"
        return 1
    end

    if not command -q bat
        echo "Error: bat is not installed. Install it from https://github.com/sharkdp/bat"
        return 1
    end

    if not command -q llm
        echo "Error: llm is not installed. Install it from https://llm.datasette.io/"
        return 1
    end

    # Parse arguments
    argparse 'c/context' 'claude' 's/summary-only' -- $argv
    or return

    # Get the git diff
    set diff (git diff --cached)

    if test -z "$diff"
        echo "No staged changes to commit"
        return 1
    end

    # Collect context if -c flag is provided
    set context ""
    if set -q _flag_context
        set context (gum write --placeholder "What motivated this change? Is there context a future reader will need to know? What problem did you solve?")
    end

    # Collect context from Claude if --claude flag is provided
    if set -q _flag_claude
        set claude_context (claude --continue --print "What context from this session would be useful for writing a commit message? Don't suggest a message or list affected files. Focus on the WHY of this work.")
        if test -n "$context"
            set context "$context

$claude_context"
        else
            set context $claude_context
        end
    end

    # Start with default temperature (no -o flag)
    set temp_options
    set reroll_count 0
    set base_prompt "Write a git commit message for these changes. Format it as:
- First line: a summary of 72 characters or less
- Second line: blank
- Remaining lines: detailed description (keep this BRIEF - 2-4 sentences max)

The tone should be confident, conversational, and slightly irreverent, mixing technical precision with plainspoken candor. Write as an experienced expert speaking peer-to-peer, empathetic to pain points but authoritative in solutions. Keep it credible, no-nonsense, and built for engineers tired of vague marketing.

Be concise. Every word should earn its place.

Return only the commit message."

    if test -n "$context"
        set prompt "$base_prompt

Additional context from the developer:
$context"
    else
        set prompt "$base_prompt"
    end

    # Function to clean up blank lines and remove markdown fences
    function clean_blank_lines
        set input_file $argv[1]
        set output_file (mktemp)
        # Remove markdown code fences and clean blank lines
        sed '/^```$/d' $input_file | awk 'NF {p=1} p' | awk 'NF || !blank {print; blank=!NF}' > $output_file
        echo $output_file
    end

    # Function to add LLM disclaimer after first line
    function add_disclaimer
        set input_file $argv[1]
        set summary_only $argv[2]
        set output_file (mktemp)
        set summary (head -n 1 $input_file)

        echo "$summary" > $output_file
        echo "" >> $output_file
        echo "This commit message was generated with the help of LLMs." >> $output_file

        if test "$summary_only" != "summary-only"
            tail -n +2 $input_file >> $output_file
        end

        echo $output_file
    end

    # Loop to allow rerolls
    while true
        # Generate commit message and save to temp file to preserve newlines
        set temp_file (mktemp)
        if test (count $temp_options) -eq 0
            echo "$diff" | llm -s "$prompt" > $temp_file
        else
            echo "$diff" | llm -s "$prompt" $temp_options > $temp_file
        end

        # Read first line to check length
        set summary (head -n 1 $temp_file)
        set summary_length (string length "$summary")

        if test $summary_length -gt 72
            echo "Summary too long ($summary_length chars), regenerating..."
            rm $temp_file
            continue
        end

        # Clean up blank lines
        set cleaned_file (clean_blank_lines $temp_file)
        rm $temp_file
        set temp_file $cleaned_file

        # Add disclaimer for display and commit
        if set -q _flag_summary_only
            set display_file (add_disclaimer $temp_file "summary-only")
        else
            set display_file (add_disclaimer $temp_file)
        end

        # Show the generated message
        echo "Generated commit message:"
        bat -P -H 1 --style=changes,grid,numbers,snip $display_file

        # Let user choose what to do
        set action (gum choose "Commit" "Commit and Push" "Edit" "Reroll" "Condense" "Cancel")

        switch $action
            case "Commit"
                git commit -F $display_file
                rm $temp_file
                rm $display_file
                return 0
            case "Commit and Push"
                git commit -F $display_file
                rm $temp_file
                rm $display_file
                git push
                return 0
            case "Edit"
                eval $EDITOR $display_file
                git commit -F $display_file
                rm $temp_file
                rm $display_file
                return 0
            case "Reroll"
                set reroll_count (math $reroll_count + 1)
                set temp (math "0.5 + $reroll_count * 0.3")
                set temp_options -o temperature $temp
                echo "Generating new message (temperature: $temp)..."
                rm $temp_file
                rm $display_file
                continue
            case "Condense"
                echo "Condensing message..."
                set current_message (cat $temp_file)
                set condense_prompt "Take this commit message and make it more concise while retaining the what and the why:

$current_message"
                set condensed_file (mktemp)
                echo "$condense_prompt" | llm > $condensed_file
                rm $temp_file
                set temp_file $condensed_file
                # Clean up blank lines after condensing
                set cleaned_file (clean_blank_lines $temp_file)
                rm $temp_file
                set temp_file $cleaned_file
                rm $display_file
                continue
            case "Cancel"
                echo "Commit cancelled"
                rm $temp_file
                rm $display_file
                return 1
        end
    end
end
