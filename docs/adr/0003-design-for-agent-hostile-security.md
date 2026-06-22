# Design for agent-hostile security

This repo assumes LLM agents may be prompt-injected or user-misaligned at any time, so security controls should be hard barriers rather than agent self-restraint. Automated workflows should avoid combining two or more legs of the lethal trifecta — private-data access, untrusted-content exposure, and external communication — and destructive or hard-to-rollback actions should require human escalation or authentication through mechanisms such as immutable flags, sudo, 1Password, or human-only guards.
