function gc-ai
    # Parse arguments first to check for help
    argparse 'h/help' 'c/context' 'claude' 's/summary-only' 'no-gpg-sign' 'no-verify' 'C/conventional-commit' 'a/add-all' 'p/push' -- $argv
    or return

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

    # Show help if requested
    if set -q _flag_help
        echo "gc-ai - AI-powered git commit message generator"
        echo ""
        echo "Usage: gc-ai [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  -h, --help                 Show this help message"
        echo "  -c, --context              Prompt for additional context about the change"
        echo "  --claude                   Get context from current Claude session"
        echo "  -s, --summary-only         Only include summary line, skip detailed description"
        echo "  --no-gpg-sign              Skip GPG signing of the commit"
        echo "  --no-verify                Skip pre-commit and commit-msg hooks"
        echo "  -C, --conventional-commit  Use conventional commit format"
        echo "  -a, --add-all              Run 'git add -A' before generating commit"
        echo "  -p, --push                 Auto-accept commit and push immediately"
        return 0
    end

    # Add all changes if -a flag is provided
    if set -q _flag_add_all
        echo "Adding all changes..."
        git add -A
    end

    # Get the git diff
    set diff (git diff --cached)

    if test -z "$diff"
        echo "No staged changes to commit"
        return 1
    end

    # Get the last 5 commits for style reference
    set commit_history (git log --pretty=format:"%s%n%n%b" -5 2>/dev/null)
    if test -z "$commit_history"
        set commit_history ""
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

    # Base prompt with the signature tone
    set base_prompt "Write a git commit message for these changes. Format it as:
- First line: a summary of 72 characters or less
- Second line: blank
- Remaining lines: detailed description (1-3 sentences, only if needed to explain WHY)

Tone: Direct, technical, and conversational. Write like an experienced developer talking to another developer. No marketing speak, no clever endings, no unnecessary flourishes.

Focus on WHAT changed and WHY it matters. Skip the obvious. Be precise.

Every word should earn its place. When in doubt, be brief."

    # Add conventional commit requirements if flag is set
    if set -q _flag_conventional_commit
        set base_prompt "Write a git commit message following the Conventional Commits specification.

CONVENTIONAL COMMITS SPECIFICATION:

1. Commits MUST be prefixed with a type (noun like feat, fix, etc.), followed by OPTIONAL scope, OPTIONAL !, and REQUIRED terminal colon and space.

2. The type feat MUST be used when a commit adds a new feature.
3. The type fix MUST be used when a commit represents a bug fix.
4. A scope MAY be provided after a type. A scope MUST consist of a noun describing a section of the codebase surrounded by parenthesis, e.g., fix(parser):
5. A description MUST immediately follow the colon and space after the type/scope prefix. The description is a short summary of the code changes.

6. A longer commit body MAY be provided after the short description, providing additional contextual information about the code changes. The body MUST begin one blank line after the description.
7. Breaking changes MUST be indicated by a ! immediately before the : in the type/scope prefix, OR as a footer entry.
8. If included as a footer, a breaking change MUST consist of the uppercase text BREAKING CHANGE, followed by colon, space, and description.
9. Types other than feat and fix MAY be used (e.g., docs, style, refactor, perf, test, build, ci, chore, revert).

FORMAT:
<type>[optional scope][optional !]: <description>

[optional body]

[optional footer(s)]

EXAMPLES:
feat(auth): add oauth2 integration
fix!: correct major calculation error
docs(api): update endpoint documentation
BREAKING CHANGE: API endpoints now require authentication

STYLE REQUIREMENTS:
- Description: Keep under 50 chars, present tense, no capital first letter, no period
- Body: 1-3 sentences MAX, only if needed to explain WHY. Often unnecessary.
- Tone: Direct, technical, conversational. No marketing speak, no clever endings.

Focus on WHAT changed and WHY it matters. When in doubt, be brief."
    end

    # Always add the return instruction
    set base_prompt "$base_prompt

Return only the commit message."

    # Build the full prompt with commit history and context
    set prompt "$base_prompt"

    if test -n "$commit_history"
        set prompt "$prompt

Recent commits from this repository for style reference:
---
$commit_history
---"
    end

    if test -n "$context"
        set prompt "$prompt

Additional context from the developer:
$context"
    end

    # Function to validate conventional commit format
    function validate_conventional_commit
        set first_line $argv[1]
        # Check if it matches conventional commit pattern (including optional ! for breaking changes)
        echo $first_line | grep -qE '^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\([^)]+\))?!?: .+$'
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

    # Function to attempt commit and handle pre-commit hook failures
    function attempt_commit
        set message_file $argv[1]
        set git_commit_options $argv[2..-1]

        # Create temp file for error output
        set error_file (mktemp)

        # Attempt the commit, capturing stderr
        git commit -F $message_file $git_commit_options 2>$error_file
        set commit_result $status

        if test $commit_result -eq 0
            rm $error_file
            return 0
        end

        # Read the error output
        set error_output (cat $error_file)
        rm $error_file

        # Check if it's a commitlint error
        if echo "$error_output" | grep -q "body-max-line-length\|scope-enum\|type-enum\|subject-empty\|header-max-length"
            echo "$error_output"
            return 2  # Special return code for commitlint errors
        else
            # Other pre-commit hook failure - display error and exit
            echo "$error_output"
            return 1
        end
    end

    # Function to fix commitlint errors
    function fix_commitlint_errors
        set original_message_file $argv[1]
        set error_output $argv[2]
        set conventional_commit $argv[3]

        echo "Commitlint errors detected. Attempting to fix..."

        # Extract the original message
        set original_message (cat $original_message_file)

        # Parse commitlint errors
        set commitlint_errors ""
        if echo "$error_output" | grep -q "body-max-line-length"
            set commitlint_errors "$commitlint_errors
- Body lines must not be longer than 72 characters"
        end
        if echo "$error_output" | grep -q "scope-enum"
            set scope_enum (echo "$error_output" | grep "scope must be one of" | sed 's/.*\[\(.*\)\].*/\1/')
            set commitlint_errors "$commitlint_errors
- Scope must be one of: $scope_enum"
        end
        if echo "$error_output" | grep -q "type-enum"
            set type_enum (echo "$error_output" | grep "type must be one of" | sed 's/.*\[\(.*\)\].*/\1/')
            set commitlint_errors "$commitlint_errors
- Type must be one of: $type_enum"
        end
        if echo "$error_output" | grep -q "subject-empty"
            set commitlint_errors "$commitlint_errors
- Subject/description cannot be empty"
        end
        if echo "$error_output" | grep -q "header-max-length"
            set commitlint_errors "$commitlint_errors
- Header (first line) must be 100 characters or less"
        end

        # Build fix prompt
        set fix_prompt "The following commit message failed commitlint validation:

$original_message

Commitlint errors:
$commitlint_errors

Please fix the commit message to comply with these requirements. Maintain the same content and intent, but adjust formatting/structure as needed."

        if test "$conventional_commit" = "yes"
            set fix_prompt "$fix_prompt

Ensure it follows the Conventional Commits format."
        end

        set fix_prompt "$fix_prompt

Return only the fixed commit message."

        # Generate fixed message
        set fixed_file (mktemp)
        echo "$fix_prompt" | llm > $fixed_file

        # Clean up blank lines
        set cleaned_file (clean_blank_lines $fixed_file)
        rm $fixed_file

        echo $cleaned_file
    end

    # Build git commit options
    set git_commit_options
    if set -q _flag_no_gpg_sign
        set git_commit_options $git_commit_options --no-gpg-sign
    end
    if set -q _flag_no_verify
        set git_commit_options $git_commit_options --no-verify
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

        # Read first line to check length and format
        set summary (head -n 1 $temp_file)

        # Check conventional commit format if flag is set
        if set -q _flag_conventional_commit
            if not validate_conventional_commit "$summary"
                echo "Not a valid conventional commit format, regenerating..."
                rm $temp_file
                continue
            end
            # For conventional commits, check 50 char limit for description
            set description_part (echo "$summary" | sed -E 's/^[^:]+: //')
            set description_length (string length "$description_part")
            if test $description_length -gt 50
                echo "Conventional commit description too long ($description_length chars), regenerating..."
                rm $temp_file
                continue
            end
        else
            set summary_length (string length "$summary")
            if test $summary_length -gt 72
                echo "Summary too long ($summary_length chars), regenerating..."
                rm $temp_file
                continue
            end
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

        # If auto-push flag is set, handle commit with error checking
        if set -q _flag_push
            echo "Generated commit message:"
            bat -P -H 1 --style=changes,grid,numbers,snip $display_file
            echo "Auto-committing and pushing..."

            # Try to commit with error handling
            set commit_attempt 0
            set max_attempts 2
            set current_file $display_file

            while test $commit_attempt -lt $max_attempts
                set commit_attempt (math $commit_attempt + 1)

                # Create temp file for error output
                set error_file (mktemp)
                git commit -F $current_file $git_commit_options 2>$error_file
                set commit_result $status

                if test $commit_result -eq 0
                    rm $error_file
                    rm $temp_file
                    rm $display_file
                    test "$current_file" != "$display_file"; and rm $current_file
                    git push
                    return 0
                end

                # Read error and check if it's commitlint
                set error_output (cat $error_file)
                rm $error_file

                if echo "$error_output" | grep -q "body-max-line-length\|scope-enum\|type-enum\|subject-empty\|header-max-length"
                    if test $commit_attempt -lt $max_attempts
                        echo "Commitlint validation failed. Attempting to fix..."
                        if set -q _flag_conventional_commit
                            set fixed_file (fix_commitlint_errors $current_file "$error_output" "yes")
                        else
                            set fixed_file (fix_commitlint_errors $current_file "$error_output" "no")
                        end
                        test "$current_file" != "$display_file"; and rm $current_file
                        set current_file $fixed_file
                        echo "Retrying with fixed message..."
                    else
                        echo "Failed to fix commitlint errors after retry."
                        echo "$error_output"
                        rm $temp_file
                        rm $display_file
                        test "$current_file" != "$display_file"; and rm $current_file
                        return 1
                    end
                else
                    # Other error - just display and exit
                    echo "$error_output"
                    rm $temp_file
                    rm $display_file
                    test "$current_file" != "$display_file"; and rm $current_file
                    return 1
                end
            end
        end

        # Show the generated message
        echo "Generated commit message:"
        bat -P -H 1 --style=changes,grid,numbers,snip $display_file

        # Let user choose what to do
        set action (gum choose "Commit" "Commit and Push" "Edit" "Reroll" "Condense" "Cancel")

        switch $action
            case "Commit"
                # Try to commit with error handling
                set commit_attempt 0
                set max_attempts 2
                set current_file $display_file

                while test $commit_attempt -lt $max_attempts
                    set commit_attempt (math $commit_attempt + 1)

                    # Create temp file for error output
                    set error_file (mktemp)
                    git commit -F $current_file $git_commit_options 2>$error_file
                    set commit_result $status

                    if test $commit_result -eq 0
                        rm $error_file
                        rm $temp_file
                        rm $display_file
                        test "$current_file" != "$display_file"; and rm $current_file
                        return 0
                    end

                    # Read error and check if it's commitlint
                    set error_output (cat $error_file)
                    rm $error_file

                    if echo "$error_output" | grep -q "body-max-line-length\|scope-enum\|type-enum\|subject-empty\|header-max-length"
                        if test $commit_attempt -lt $max_attempts
                            echo "Commitlint validation failed. Attempting to fix..."
                            if set -q _flag_conventional_commit
                                set fixed_file (fix_commitlint_errors $current_file "$error_output" "yes")
                            else
                                set fixed_file (fix_commitlint_errors $current_file "$error_output" "no")
                            end
                            test "$current_file" != "$display_file"; and rm $current_file
                            set current_file $fixed_file
                            echo "Retrying with fixed message..."
                        else
                            echo "Failed to fix commitlint errors after retry."
                            echo "$error_output"
                            rm $temp_file
                            rm $display_file
                            test "$current_file" != "$display_file"; and rm $current_file
                            return 1
                        end
                    else
                        # Other error - just display and exit
                        echo "$error_output"
                        rm $temp_file
                        rm $display_file
                        test "$current_file" != "$display_file"; and rm $current_file
                        return 1
                    end
                end

            case "Commit and Push"
                # Try to commit with error handling
                set commit_attempt 0
                set max_attempts 2
                set current_file $display_file

                while test $commit_attempt -lt $max_attempts
                    set commit_attempt (math $commit_attempt + 1)

                    # Create temp file for error output
                    set error_file (mktemp)
                    git commit -F $current_file $git_commit_options 2>$error_file
                    set commit_result $status

                    if test $commit_result -eq 0
                        rm $error_file
                        rm $temp_file
                        rm $display_file
                        test "$current_file" != "$display_file"; and rm $current_file
                        git push
                        return 0
                    end

                    # Read error and check if it's commitlint
                    set error_output (cat $error_file)
                    rm $error_file

                    if echo "$error_output" | grep -q "body-max-line-length\|scope-enum\|type-enum\|subject-empty\|header-max-length"
                        if test $commit_attempt -lt $max_attempts
                            echo "Commitlint validation failed. Attempting to fix..."
                            if set -q _flag_conventional_commit
                                set fixed_file (fix_commitlint_errors $current_file "$error_output" "yes")
                            else
                                set fixed_file (fix_commitlint_errors $current_file "$error_output" "no")
                            end
                            test "$current_file" != "$display_file"; and rm $current_file
                            set current_file $fixed_file
                            echo "Retrying with fixed message..."
                        else
                            echo "Failed to fix commitlint errors after retry."
                            echo "$error_output"
                            rm $temp_file
                            rm $display_file
                            test "$current_file" != "$display_file"; and rm $current_file
                            return 1
                        end
                    else
                        # Other error - just display and exit
                        echo "$error_output"
                        rm $temp_file
                        rm $display_file
                        test "$current_file" != "$display_file"; and rm $current_file
                        return 1
                    end
                end

            case "Edit"
                eval $EDITOR $display_file
                git commit -F $display_file $git_commit_options
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