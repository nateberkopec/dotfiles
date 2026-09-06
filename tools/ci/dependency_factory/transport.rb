module DependencyFactory
  module Transport
    module_function

    # gh-aw's bundle transport names and ref format (compiler v0.86.2).
    def errors(item, directory:, root: Dir.pwd, repo: ENV["GITHUB_REPOSITORY"])
      branch = item["branch"]
      return ["Publishing requires a branch"] if branch.to_s.empty?
      paths = [item["repo"], repo, nil].uniq.map { |slug| bundle_path(directory, slug, branch) }
      bundle = paths.find { |path| File.file?(path) }
      return ["Missing queued bundle for #{branch}"] unless bundle
      heads = Sources.capture({}, "git", "bundle", "list-heads", bundle).lines.map(&:split)
      head = Sources.capture({}, "git", "-C", root, "rev-parse", "HEAD").strip
      heads.include?([head, "refs/heads/#{branch}"]) ? [] : ["Queued bundle for #{branch} does not match the checked HEAD; emit the push/create after the final commit"]
    end

    def bundle_path(directory, repo, branch)
      parts = [repo, branch].compact.map { |part| part.gsub(%r{[/\\:*?"<>|]}, "-").gsub(/-{2,}/, "-").sub(/\A-/, "").sub(/-\z/, "").downcase }
      File.expand_path("../aw-#{parts.join("-")}.bundle", directory)
    end
  end
end
