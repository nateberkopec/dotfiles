FLOG_THRESHOLD = (ENV["FLOG_THRESHOLD"] || 50).to_i
FLAY_THRESHOLD = (ENV["FLAY_THRESHOLD"] || 100).to_i

task default: [:standardrb, :flog, :flay]

desc "Run standardrb"
task :standardrb do
  sh "bundle exec standardrb"
end

desc "Run flog"
task :flog do
  flog_output = `bundle exec flog -a lib`
  puts flog_output
  method_scores = flog_output.lines.grep(/^\s+[0-9]+\.[0-9]+:.*#/).map { |line| line.split.first.to_f }
  max_score = method_scores.max
  if max_score && max_score > FLOG_THRESHOLD
    abort "flog failed: highest complexity (#{max_score}) exceeds threshold (#{FLOG_THRESHOLD})"
  end
  puts "flog passed (max complexity: #{max_score}, threshold: #{FLOG_THRESHOLD})"
end

desc "Run flay"
task :flay do
  flay_output = `bundle exec flay lib`
  puts flay_output
  flay_score = flay_output[/Total score.*= (\d+)/, 1]&.to_i
  if flay_score && flay_score > FLAY_THRESHOLD
    abort "flay failed: duplication score (#{flay_score}) exceeds threshold (#{FLAY_THRESHOLD})"
  end
  puts "flay passed (duplication score: #{flay_score}, threshold: #{FLAY_THRESHOLD})"
end
