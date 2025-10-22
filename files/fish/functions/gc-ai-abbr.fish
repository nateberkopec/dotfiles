function gc-ai-abbr --description "Set up abbreviations for gc-ai"
    # Basic shortcuts
    abbr -a gca 'gc-ai -a'                        # Stage all changes (git add -A) then generate commit message
    # Common combinations
    abbr -a gcyolo 'gc-ai -a -p'
    abbr -a gcyolos 'gc-ai -a -p -s'
    abbr -a gcyoloc 'gc-ai -a -p --claude'           # Work in progress: stage all, summary only, skip hooks
end

# Auto-load abbreviations when this file is sourced
gc-ai-abbr  # Execute the function to register all abbreviations when file is loaded
