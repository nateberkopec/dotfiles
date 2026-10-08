# Vendored anti-slop

Source: https://github.com/dmmulroy/anti-slop
Revision: `c44ef22ca116d0ba62a3ff663a0bd13a3f3fa40b`

Copied with `skills/install-anti-slop/scripts/install.mjs` from that revision's
`skills/install-anti-slop/assets/anti-slop/` into `tools/oxlint/anti-slop/`.
The generic plugin is registered in `.oxlintrc.json`; all generic rules and the
native `oxc/no-accumulating-spread` companion are enabled as errors, unchanged.
Effect rules are not registered because this repository does not use Effect.

The plugin source is unmodified. The nested ESLint Stylistic license and
provenance are retained. The upstream project's MIT license is included here.
