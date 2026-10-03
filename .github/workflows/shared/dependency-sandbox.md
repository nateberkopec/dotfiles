---
# Shared by the dependency factory and its sandbox compatibility check.
network:
  allowed:
    - defaults
    - github
    - go
    - linux-distros
    - node
    - ruby
    - rust
    - api.osv.dev
    - appupdates.agilebits.com
    - blog.rustlang.org
    - cache.agilebits.com
    - cmake.org
    - dl.google.com
    - formulae.brew.sh
    - mise-versions.jdx.dev
    - mise.run
    - support.1password.com
    - tmaproduction.blob.core.windows.net
    - tuf-repo-cdn.sigstore.dev
    - www.ruby-lang.org
pre-agent-steps:
  - name: Set up uv for sandbox validation
    uses: astral-sh/setup-uv@c18668ad3cf93ea998bef934396af7bb5c839dc7 # v10.2.0
    with:
      enable-cache: false
---
