function gcai
  git add .
  set message (git diff HEAD | llm -s "write a conventional commit message (feat/fix/docs/style/refactor) with scope")
  git commit -m "$message" -e
end
