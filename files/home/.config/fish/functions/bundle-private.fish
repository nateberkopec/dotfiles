function bundle-private --description "Run Bundler with private gem credentials from fnox"
    set -l args $argv
    test (count $args) -eq 0; and set args install

    if not command -q fnox
        echo "fnox is required to load private Bundler credentials" >&2
        return 127
    end

    set -lx BUNDLE_PRIVATE_ACTIVE 1
    fnox exec -c ~/.config/fnox/bundler.toml -- bundle $args
end
