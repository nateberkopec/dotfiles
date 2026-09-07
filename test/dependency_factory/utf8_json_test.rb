require "test_helper"
require_relative "../../tools/ci/dependency_factory"
require_relative "../support/dependency_publication_fixture"

# standard:disable Dotfiles/BanFileSystemClasses
class DependencyUtf8JsonTest < Minitest::Test
  include DependencyPublicationFixture

  def test_byte_written_em_dash_passes_checker_and_validator_under_c_locale
    publication_fixture do |fixture|
      validate_publication(fixture) # Set up the valid main response, without a bundle.
      write_utf8_envelope(fixture, "\xE2\x80\x94".b)
      %w[check_dependency_output validate_dependency_publication].each do |script|
        output, status = run_utf8_script(fixture, script)
        assert status.success?, output
      end
    end
  end

  def test_byte_written_lone_lead_byte_fails_all_event_and_artifact_reads
    {
      "dependency_context" => %w[event],
      "check_dependency_eligibility" => %w[context candidates],
      "check_dependency_output" => %w[context envelope],
      "validate_dependency_publication" => %w[context envelope]
    }.each do |script, inputs|
      inputs.each do |input|
        publication_fixture do |fixture|
          write_utf8_envelope(fixture, "\xE2\x80\x94".b)
          path = utf8_input_path(fixture, input)
          File.binwrite(path, File.binread(path).sub("}".b, ",\"prose\":\"\xE2\"}".b))
          forbid_publication_work(fixture)
          output, status = run_utf8_script(fixture, script)
          refute status.success?, "#{script} #{input}: #{output}"
          assert_includes output, "Invalid UTF-8 JSON"
          refute_includes output, "Missing queued bundle"
          refute File.exist?(File.join(fixture[:root], "external-work"))
        end
      end
    end
  end

  def test_validator_rechecks_envelope_bytes_after_checker
    publication_fixture do |fixture|
      File.write(File.join(fixture[:source], "tools/ci/check_dependency_output.rb"), "exit 0\n")
      forbid_publication_work(fixture)
      write_utf8_envelope(fixture, "\xE2".b)
      output, status = run_utf8_script(fixture, "validate_dependency_publication")
      refute status.success?, output
      assert_includes output, "Invalid UTF-8 JSON"
      refute File.exist?(File.join(fixture[:root], "external-work"))
    end
  end

  private

  def forbid_publication_work(fixture)
    bin = File.join(fixture[:root], "bin")
    FileUtils.mkdir_p(bin)
    %w[git gh].each do |command|
      path = File.join(bin, command)
      File.write(path, "#!/bin/sh\ntouch '#{fixture[:root]}/external-work'\nexit 1\n")
      File.chmod(0o755, path)
    end
  end

  def write_utf8_envelope(fixture, bytes)
    File.binwrite(utf8_input_path(fixture, "envelope"), '{"items":[{"type":"noop","message":"'.b + bytes + '"}]}'.b)
  end

  def utf8_input_path(fixture, input)
    return File.join(fixture[:directory], "../agent_output.json") if input == "envelope"
    File.join(fixture[:evidence], (input == "candidates") ? "dependency-candidates.json" : "pr-context.json")
  end

  def run_utf8_script(fixture, script)
    context = utf8_input_path(fixture, "context")
    arguments = case script
    when "dependency_context" then [File.join(fixture[:root], "result.json")]
    when "check_dependency_eligibility" then [context, utf8_input_path(fixture, "candidates")]
    when "check_dependency_output" then [fixture[:directory], context]
    else [fixture[:directory], fixture[:evidence]]
    end
    env = {"LC_ALL" => "C", "LANG" => "C", "RUBYOPT" => nil, "GITHUB_EVENT_PATH" => context, "GITHUB_REPOSITORY" => "test/test", "PATH" => "#{fixture[:root]}/bin:#{ENV["PATH"]}", "BUNDLE_GEMFILE" => File.join(fixture[:source], "Gemfile"), "BUNDLE_PATH" => File.expand_path(Bundler.settings[:path], Bundler.root)}
    Open3.capture2e(env, "bundle", "exec", "ruby", File.join(fixture[:source], "tools/ci/#{script}.rb"), *arguments, chdir: fixture[:source])
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
