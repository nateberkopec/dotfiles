# Separate config data from Step behavior

Config answers what desired things should exist, while Steps answer how to make them true. Prefer extending flat config or source files when adding package names, app lists, APT sources, file associations, exclusions, or tool lists; add or change Steps only when there is new behavior, sequencing, platform logic, side effects, prompting, retrying, or idempotency logic to encode.
