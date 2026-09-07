module DependencyFactory
  module Transport
    module_function

    # gh-aw's bundle transport names and ref format (compiler v0.88.2).
    def queued_bundle(item, directory:, repo: ENV["GITHUB_REPOSITORY"])
      slugs = [item["repo"], repo].compact.reject(&:empty?).uniq + [nil]
      paths = slugs.map { |slug| bundle_path(directory, slug, item.fetch("branch")) }.uniq
      present = paths.select { |path| File.exist?(path) || File.symlink?(path) }
      raise "Ambiguous queued bundles" if present.size > 1
      present.first
    end

    def bundle_path(directory, repo, branch)
      parts = [repo, branch].compact.map { |part| part.gsub(%r{[/\\:*?"<>|]}, "-").gsub(/-{2,}/, "-").sub(/\A-/, "").sub(/-\z/, "").downcase }
      File.expand_path("../aw-#{parts.join("-")}.bundle", directory)
    end
  end
end
