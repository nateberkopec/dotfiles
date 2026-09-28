#!/usr/bin/env ruby

require "digest"
require "fileutils"
require "json"
require "tmpdir"

VERSION = "0.2.3-nate.1"
SHA256 = "64db41b3a2a03ebfec265f3ab8d43db62e2bf51a26a289c3678544a068927e80"
INDEX_SHA256 = "919020957c22f04bee21e2198619ae35649618dcc82eb6b05d08d2bf44b14af5"
SCRUB_SHA256 = "bcf65312ec8decd2bc927ca7de498130c17de61d7393343e0b7d686518853875"
RELEASE = "https://github.com/nateberkopec/meridian-plugin-pi-scrub/releases/download/meridian-plugin-pi-scrub-v#{VERSION}/meridian-plugin-pi-scrub-#{VERSION}.tgz"

root = File.join(ENV.fetch("HOME"), ".local/share/meridian/plugins")
destination = File.join(root, "pi-scrub-#{VERSION}")
index = File.join(destination, "dist/index.js")
scrub = File.join(destination, "dist/scrub.js")
unless File.file?(index) && File.file?(scrub) && Digest::SHA256.file(index).hexdigest == INDEX_SHA256 && Digest::SHA256.file(scrub).hexdigest == SCRUB_SHA256
  FileUtils.mkdir_p(root)
  Dir.mktmpdir("pi-scrub-", root) do |temp|
    archive = File.join(temp, "plugin.tgz")
    system("curl", "--fail", "--location", "--silent", "--show-error", "--output", archive, RELEASE) || abort("pi-scrub download failed")
    abort("pi-scrub release checksum mismatch") unless Digest::SHA256.file(archive).hexdigest == SHA256

    unpacked = File.join(temp, "unpacked")
    FileUtils.mkdir_p(unpacked)
    system("tar", "-xzf", archive, "-C", unpacked) || abort("pi-scrub extraction failed")
    abort("pi-scrub index checksum mismatch") unless Digest::SHA256.file(File.join(unpacked, "dist/index.js")).hexdigest == INDEX_SHA256
    abort("pi-scrub scrub checksum mismatch") unless Digest::SHA256.file(File.join(unpacked, "dist/scrub.js")).hexdigest == SCRUB_SHA256
    FileUtils.rm_rf(destination)
    FileUtils.mv(unpacked, destination)
  end
end

manifest = File.join(ENV.fetch("HOME"), ".config/meridian/plugins.json")
config = File.file?(manifest) ? JSON.parse(File.read(manifest)) : {"plugins" => []}
plugins = config.fetch("plugins").reject { |entry| entry.fetch("path", "").include?("pi-scrub") }
plugins << {"path" => index, "enabled" => true}
config["plugins"] = plugins
contents = JSON.pretty_generate(config) + "\n"
unless File.file?(manifest) && File.read(manifest) == contents
  FileUtils.mkdir_p(File.dirname(manifest))
  File.write(manifest, contents)
end
