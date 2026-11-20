require "rake/testtask"

ENV["BASH_ENV"] = File.expand_path("files/home/.config/bash/safety.bash", __dir__)

task default: [:test]

Rake::TestTask.new("test:bash_safety") do |t|
  t.libs << "test"
  t.test_files = FileList["test/bash/safety_environment_test.rb"]
end

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.test_files = FileList["test/**/*_test.rb"].exclude("test/e2e/**/*")
end
# Run the bounded startup check before the suite can launch other Bash processes.
Rake::Task[:test].enhance(["test:bash_safety"])
