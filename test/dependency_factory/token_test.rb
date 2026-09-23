require "test_helper"
require "open3"
require "tmpdir"

# Exercise the CI script with GitHub and Git responses, without real credentials.
# standard:disable Dotfiles/BanFileSystemClasses
class DependencyFactoryTokenTest < Minitest::Test
  def test_missing_token_fails_before_contacting_github
    output, status = check(token: "")
    refute status.success?
    assert_includes output, "DEPENDENCY_FACTORY_PAT: secret is missing"
  end

  def test_invalid_token_stops_before_repository_access
    output, status = check(failure: "identity")
    refute status.success?
    assert_includes output, "authentication failed; renew the token"
  end

  def test_repository_without_push_access_is_rejected
    output, status = check(failure: "permission")
    refute status.success?
    assert_includes output, "token cannot access the repository with push permission"
  end

  def test_git_authentication_failure_is_reported
    output, status = check(failure: "git")
    refute status.success?
    assert_includes output, "Git HTTPS authentication failed"
  end

  def test_valid_token_can_read_the_repository
    output, status = check
    assert status.success?, output
    assert_includes output, "Publishing token passed API and Git read checks"
  end

  private

  def check(token: "test-credential", failure: "")
    Dir.mktmpdir do |root|
      executable(root, "gh", <<~BASH)
        if [ "$2" = user ]; then
          [ "$FAILURE" != identity ]
        else
          [ "$FAILURE" != identity ] || exit 99
          [ "$FAILURE" = permission ] && echo false || echo true
        fi
      BASH
      executable(root, "git", '[ "$FAILURE" != git ]')
      env = {"PATH" => "#{root}:#{ENV.fetch("PATH")}", "GH_TOKEN" => token,
             "GITHUB_REPOSITORY" => "owner/repo", "RUNNER_TEMP" => root, "FAILURE" => failure}
      script = File.expand_path("../../tools/ci/check_dependency_factory_token.sh", __dir__)
      Open3.capture2e(env, "bash", script)
    end
  end

  def executable(root, name, body)
    path = File.join(root, name)
    File.write(path, "#!/bin/bash\nset -eu\n#{body}\n")
    File.chmod(0o755, path)
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
