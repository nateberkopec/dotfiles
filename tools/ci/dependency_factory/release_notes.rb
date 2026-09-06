module DependencyFactory
  class ReleaseNotes
    CHANGELOGS = %w[CHANGELOG.md CHANGELOG HISTORY.md].freeze
    UPSTREAM_CHANGELOGS = {
      "rust-lang/rust" => "RELEASES.md",
      "earendil-works/pi" => "packages/coding-agent/CHANGELOG.md",
      "badlogic/pi-mono" => "packages/coding-agent/CHANGELOG.md"
    }.freeze

    def initialize(upstream: ReleaseNotesUpstream.new)
      @upstream = upstream
    end

    def build(document)
      packages = document.fetch("candidates").flat_map { |candidate| candidate.fetch("members", [candidate]) }
      {"packages" => packages.to_h { |candidate| [candidate.fetch("name"), candidate.fetch("releases").map { |release| record(candidate, release) }] }}
    end

    private

    def record(candidate, release)
      result = {"version" => release.fetch("version"), "published" => release["created_at"],
                "url" => release["release_url"], "text" => nil, "error" => nil}
      return result.merge("text" => release["text"]) unless release["text"].to_s.strip.empty?
      resolve(candidate, release, result)
    rescue => error
      result.merge("url" => nil, "error" => error.message)
    end

    def resolve(candidate, release, result)
      repo = @upstream.repository(candidate, release)
      raise "No primary upstream repository identified" unless repo
      errors = []
      notes = github_notes(repo, candidate, release.fetch("version"), errors)
      notes ||= changelog(repo, release.fetch("version"), errors)
      return result.merge("url" => notes[0], "text" => notes[1]) if notes
      result.merge("url" => nil, "error" => (["No release notes found"] + errors).join("; "))
    end

    def github_notes(repo, candidate, version, errors)
      prefixes = [candidate.dig("meta", "tag_prefix"), "v", "", "rust-v", "go", "jq-"].compact.uniq
      prefixes.each do |prefix|
        url = "https://api.github.com/repos/#{repo}/releases/tags/#{URI.encode_www_form_component(prefix + version)}"
        release = attempt(errors) { JSON.parse(@upstream.fetch(url)) }
        next unless release && !release["body"].to_s.strip.empty?
        return [release["html_url"] || url, release["body"]]
      end
      nil
    end

    def changelog(repo, version, errors)
      [UPSTREAM_CHANGELOGS[repo], *CHANGELOGS].compact.each do |path|
        url = "https://raw.githubusercontent.com/#{repo}/HEAD/#{path}"
        text = attempt(errors) { @upstream.fetch(url) }
        entry = changelog_entry(text.to_s, version)
        return [url, entry] if entry
      end
      nil
    end

    def changelog_entry(text, version)
      heading = text.match(/^(\#{1,6})\s+[^\n]*?(?<![\d.])#{Regexp.escape(version)}(?![\w.+-])[^\n]*$/)
      return unless heading
      text[heading.begin(0)..].split(/^\#{1,#{heading[1].size}}\s+/, 3)[1]&.strip
    end

    def attempt(errors)
      yield
    rescue => error
      errors << error.message
      nil
    end
  end
end
