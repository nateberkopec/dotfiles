require "json"
require "net/http"
require "open3"
require "uri"

module DependencyFactory
  class Sources
    def self.capture(env, *command)
      output, status = Open3.capture2(env, *command)
      raise "#{command.join(" ")} failed" unless status.success?
      output
    end

    def self.get(url)
      headers = {"User-Agent" => "dotfiles-dependency-factory"}
      token = ENV["GH_TOKEN"] || ENV["GITHUB_TOKEN"]
      headers["Authorization"] = "Bearer #{token}" if token && url.start_with?("https://api.github.com/")
      response = Net::HTTP.get_response(URI(url), headers)
      raise "GET #{url} returned #{response.code}" unless response.is_a?(Net::HTTPSuccess)
      response.body
    end

    def initialize(shell: method(:capture), http: method(:get))
      @shell = shell
      @http = http
    end

    def mise(tool)
      JSON.parse(@shell.call({"MISE_MINIMUM_RELEASE_AGE" => "0"}, "mise", "ls-remote", tool, "--json"))
    end

    def npm(package)
      times = JSON.parse(@http.call("https://registry.npmjs.org/#{package}")).fetch("time")
      times.except("created", "modified").map do |version, created_at|
        {"version" => version, "created_at" => created_at, "release_url" => "https://www.npmjs.com/package/#{package}/v/#{version}"}
      end
    end

    def gem(name)
      JSON.parse(@http.call("https://rubygems.org/api/v1/versions/#{name}.json")).reject { |release| release["prerelease"] }.map do |release|
        {"version" => release["number"], "created_at" => release["created_at"], "release_url" => "https://rubygems.org/gems/#{name}/versions/#{release["number"]}"}
      end
    end

    def github_releases(repo, tag_prefix)
      releases = JSON.parse(@http.call("https://api.github.com/repos/#{repo}/releases?per_page=100"))
      releases.reject { |release| release["prerelease"] || release["draft"] }.filter_map do |release|
        next unless release["tag_name"].start_with?(tag_prefix)
        {"version" => release["tag_name"].delete_prefix(tag_prefix), "created_at" => release["published_at"], "release_url" => release["html_url"]}
      end
    end

    private

    def capture(env, *command)
      self.class.capture(env, *command)
    end

    def get(url)
      self.class.get(url)
    end
  end
end
