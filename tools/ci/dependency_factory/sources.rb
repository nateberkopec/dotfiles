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

    def self.get(url, max_bytes: nil)
      headers = {"User-Agent" => "dotfiles-dependency-factory"}
      token = ENV["GH_TOKEN"] || ENV["GITHUB_TOKEN"]
      headers["Authorization"] = "Bearer #{token}" if token && url.start_with?("https://api.github.com/")
      uri = URI(url)
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 5, read_timeout: 10) do |http|
        http.request(Net::HTTP::Get.new(uri, headers)) { |response| return response_body(response, url, max_bytes) }
      end
    end

    def self.response_body(response, url, max_bytes)
      raise "GET #{url} returned #{response.code}" unless response.is_a?(Net::HTTPSuccess)
      body = +""
      response.read_body do |chunk|
        body << chunk
        raise "GET #{url} exceeded #{max_bytes} bytes" if max_bytes && body.bytesize > max_bytes
      end
      body
    end

    def initialize(shell: method(:capture), http: method(:get))
      @shell = shell
      @http = http
    end

    def mise(tool)
      JSON.parse(@shell.call({"MISE_MINIMUM_RELEASE_AGE" => "0"}, "mise", "ls-remote", tool, "--json"))
    end

    def npm(package)
      metadata = JSON.parse(@http.call("https://registry.npmjs.org/#{package}"))
      times = metadata.fetch("time")
      times.except("created", "modified").map do |version, created_at|
        {"version" => version, "created_at" => created_at, "release_url" => "https://www.npmjs.com/package/#{package}/v/#{version}", "repository" => metadata["repository"]}
      end
    end

    def gem(name)
      JSON.parse(@http.call("https://rubygems.org/api/v1/versions/#{name}.json")).reject { |release| release["prerelease"] }.map do |release|
        {"version" => release["number"], "created_at" => release["created_at"], "release_url" => "https://rubygems.org/gems/#{name}/versions/#{release["number"]}"}
      end
    end

    def github_releases(repo, tag_prefix)
      releases = github_pages(repo)
      releases.reject { |release| release["prerelease"] || release["draft"] }.filter_map do |release|
        next unless release["tag_name"].start_with?(tag_prefix)
        {"version" => release["tag_name"].delete_prefix(tag_prefix), "created_at" => release["published_at"], "release_url" => release["html_url"], "text" => release["body"]}
      end
    end

    private

    def github_pages(repo)
      releases = []
      page = 1
      loop do
        batch = JSON.parse(@http.call("https://api.github.com/repos/#{repo}/releases?per_page=100&page=#{page}"))
        releases.concat(batch)
        break if batch.size < 100
        page += 1
      end
      releases
    end

    def capture(env, *command)
      self.class.capture(env, *command)
    end

    def get(url)
      self.class.get(url)
    end
  end
end
