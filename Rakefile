require "open3"
require "rake/testtask"
require "standard/rake"

FLOG_THRESHOLD = (ENV["FLOG_THRESHOLD"] || 25).to_i
FLAY_THRESHOLD = (ENV["FLAY_THRESHOLD"] || 10).to_i

task default: [:test, :standard, :flog, :flay]

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.test_files = FileList["test/**/*_test.rb"]
end

desc "Run flog"
task :flog do
  flog_output, status = Open3.capture2e("bundle", "exec", "flog", "-a", "lib")
  puts flog_output
  abort "flog failed to run" unless status.success?

  method_scores = flog_output.lines.filter_map do |line|
    line[/^\s+([0-9]+\.[0-9]+):.*(?:#|::)/, 1]&.to_f unless line.include?("main#none")
  end
  max_score = method_scores.max || 0.0
  abort "flog failed: highest complexity (#{max_score}) reached threshold (#{FLOG_THRESHOLD})" if max_score >= FLOG_THRESHOLD
  puts "flog passed (max complexity: #{max_score}, threshold: #{FLOG_THRESHOLD})"
end

desc "Run flay"
task :flay do
  flay_output, = Open3.capture2e("bundle", "exec", "flay", "lib")
  puts flay_output
  flay_score = flay_output[/Total score.*?=\s*(\d+)/, 1]&.to_i
  abort "flay failed: no parseable total score" unless flay_score
  abort "flay failed: duplication score (#{flay_score}) reached threshold (#{FLAY_THRESHOLD})" if flay_score >= FLAY_THRESHOLD
  puts "flay passed (duplication score: #{flay_score}, threshold: #{FLAY_THRESHOLD})"
end
