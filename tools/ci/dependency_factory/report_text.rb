module DependencyFactory
  module ReportText
    # gh-aw v0.88.2 adds code spans around mentions, including in URL paths.
    MENTION = /(`+)(@[A-Za-z0-9](?:[A-Za-z0-9_-]{0,37}[A-Za-z0-9])?(?:\/[A-Za-z0-9._-]+)?)\1/

    def self.unescape_mentions(text)
      text.gsub(MENTION, '\2')
    end

    def self.publishable(body)
      body.gsub(%r{(\]\(https://[^/)\s`]+/)([^)\s]*)}) do
        prefix, path = Regexp.last_match.captures
        prefix + unescape_mentions(path).gsub("@", "%40")
      end
    end

    def self.canonical_url(url)
      url.to_s.gsub("%40", "@")
    end
  end
end
