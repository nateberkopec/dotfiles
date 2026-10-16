#!/usr/bin/env ruby

require "digest"
require "fileutils"
require "json"
require "tmpdir"

REVISION = "188115f355f423cbff50b20a2e5fd7d932ec1746"
SHA256 = "79dbc09757d1bf1da3eb09bf09bc5904afef2574fd8a8bd6be078c47ed3c591b"
INDEX_SHA256 = "f97a4171eb462982d2c11c5a99ffa9726be7d9540496357a21f99e3ffa4e0e21"
SCRUB_SHA256 = "e1c49dcf2eaeeef633be9f596fd3f1ac7a4b63dc340a23d33a445f2e6a7d148e"
SOURCE = "https://codeload.github.com/rynfar/meridian-plugin-pi-scrub/tar.gz/#{REVISION}"

root = File.join(ENV.fetch("HOME"), ".local/share/meridian/plugins")
destination = File.join(root, "pi-scrub-#{REVISION}")
index = File.join(destination, "dist/index.js")
scrub = File.join(destination, "dist/scrub.js")
unless File.file?(index) && File.file?(scrub) && Digest::SHA256.file(index).hexdigest == INDEX_SHA256 && Digest::SHA256.file(scrub).hexdigest == SCRUB_SHA256
  FileUtils.mkdir_p(root)
  Dir.mktmpdir("pi-scrub-", root) do |temp|
    archive = File.join(temp, "plugin.tgz")
    system("curl", "--fail", "--location", "--silent", "--show-error", "--retry", "3", "--retry-all-errors", "--output", archive, SOURCE) || abort("pi-scrub download failed")
    abort("pi-scrub release checksum mismatch") unless Digest::SHA256.file(archive).hexdigest == SHA256

    unpacked = File.join(temp, "unpacked")
    FileUtils.mkdir_p(unpacked)
    system("tar", "-xzf", archive, "--strip-components=1", "-C", unpacked) || abort("pi-scrub extraction failed")
    build = <<~JS
      const { stripTypeScriptTypes } = require('node:module');
      const { readFileSync, writeFileSync, mkdirSync } = require('node:fs');
      const root = process.argv[1];
      mkdirSync(`${root}/dist`, { recursive: true });
      for (const name of ['index', 'scrub']) {
        writeFileSync(`${root}/dist/${name}.js`, stripTypeScriptTypes(readFileSync(`${root}/src/${name}.ts`, 'utf8')));
      }
    JS
    system("mise", "exec", "node", "--", "node", "--disable-warning=ExperimentalWarning", "-e", build, unpacked) || abort("pi-scrub build failed")
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
