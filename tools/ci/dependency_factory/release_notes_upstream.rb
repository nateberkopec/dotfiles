require "json"
require "uri"
require "timeout"

module DependencyFactory
  class ReleaseNotesUpstream
    REPOSITORIES = {
      "ruby" => "ruby/ruby", "node" => "nodejs/node", "go" => "golang/go", "rust" => "rust-lang/rust",
      "hk" => "jdx/hk", "mise" => "jdx/mise", "cargo:broot" => "Canop/broot",
      "cargo:difftastic" => "Wilfred/difftastic", "cargo:starship" => "starship/starship",
      "pipx" => "pypa/pipx", "pipx:playwright" => "microsoft/playwright", "watchexec" => "watchexec/watchexec",
      "fnox" => "jdx/fnox", "bat" => "sharkdp/bat", "eza" => "eza-community/eza", "cmake" => "Kitware/CMake",
      "fd" => "sharkdp/fd", "fzf" => "junegunn/fzf", "gh" => "cli/cli", "git-lfs" => "git-lfs/git-lfs",
      "gum" => "charmbracelet/gum", "jq" => "jqlang/jq", "lazygit" => "jesseduffield/lazygit",
      "ripgrep" => "BurntSushi/ripgrep", "shellcheck" => "koalaman/shellcheck", "tmux" => "tmux/tmux",
      "zoxide" => "ajeetdsouza/zoxide", "pkl" => "apple/pkl", "claude" => "anthropics/claude-code",
      "gitleaks" => "gitleaks/gitleaks", "heroku" => "heroku/cli", "bundler" => "rubygems/rubygems",
      "github:pkgforge-dev/ghostty-appimage" => "ghostty-org/ghostty"
    }.freeze

    def initialize(http: ->(url) { Sources.get(url, max_bytes: 4 * 1024 * 1024) })
      @http = http
      @responses = {}
    end

    def repository(candidate, release)
      name = candidate.fetch("name").sub(/\[.*\]\z/, "")
      return REPOSITORIES[name] if REPOSITORIES.key?(name)
      return candidate["meta"]["repo"] if candidate.dig("meta", "repo")
      return name.split(":", 2).last if name.start_with?("github:", "aqua:")
      return name.delete_prefix("go:github.com/").split("/").first(2).join("/") if name.start_with?("go:github.com/")
      github_repository(release["repository"] || metadata_repository(candidate))
    end

    def fetch(url)
      result = @responses[url] ||= request(url)
      raise result if result.is_a?(StandardError)
      result
    end

    private

    def request(url)
      Timeout.timeout(20) { @http.call(url) }
    rescue => error
      error
    end

    def metadata_repository(candidate)
      name = candidate.fetch("name")
      if candidate["kind"] == "gem"
        metadata = JSON.parse(fetch("https://rubygems.org/api/v1/gems/#{name}.json"))
        metadata["source_code_uri"] || metadata["homepage_uri"]
      elsif name.start_with?("npm:", "pi:")
        JSON.parse(fetch("https://registry.npmjs.org/#{name.split(":", 2).last}/#{candidate.fetch("current")}"))["repository"]
      end
    end

    def github_repository(value)
      value = value["url"] if value.is_a?(Hash)
      value.to_s[%r{github\.com[:/]([^/]+/[^/#]+)}, 1]&.delete_suffix(".git")
    end
  end
end
