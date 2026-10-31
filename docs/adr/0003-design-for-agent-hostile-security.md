# Design for agent-hostile security

## Status

Accepted

## Context

This setup runs agents in two different environments:

1. Interactive agents on the laptop, usually with a person watching.
2. Isolated agent workloads, which may eventually run without supervision.

The primary laptop threat is attacker-controlled user-level code executed through an upstream repository, dependency, package channel, installer, extension, or downloaded binary. Prompt injection and careless agent behavior remain possible, but are lower-priority threats. Human observation helps detect mistakes; it is not an authorization boundary and cannot reliably stop malware after execution.

The laptop is sometimes on a managed home network and sometimes on an untrusted network. Model providers are trusted according to [ADR 0009](0009-require-no-training-terms-and-us-inference-from-model-providers.md).

## Decision

The laptop is a powerful operator endpoint, not the durable root of trust.

Interactive laptop agents may retain broad local authority, but should not have direct access to durable secrets or ambient control-plane credentials. Remote operations should use scoped capabilities through brokers. Destructive, privileged, publishing, production, account-administration, or otherwise hard-to-reverse actions require a distinct human decision.

Unfamiliar upstream work, contributor changes, dependency experiments, and newly downloaded code should execute in an isolated environment by default. The normal laptop agent entry point should fail closed around executable project resources until the project is explicitly trusted. An isolated session may always trust its project when its VM, network, credentials, and remote grants provide the actual boundaries.

A separate watcher may support detection, investigation, forensics, and human response. It can notify the operator, but is not an enforcement or approval mechanism.

Backups are the primary recovery control for accidental or destructive local changes. Valuable local state must be covered by versioned, restore-tested storage that the ordinary laptop user cannot silently destroy.

Network controls distinguish the managed home network from unknown networks. Services bind to loopback unless peer access is intentional. An unknown network should activate a stricter away posture for inbound services, sharing, routing, and listener visibility.

Fully unattended agent workloads wait until their filesystem, network, credential, remote-capability, recovery, and audit boundaries have been verified without relying on a cooperative model or a human watching the transcript.

## Consequences

- Broad interactive agent capability remains compatible with this threat model.
- Watching an agent reduces operational mistakes but does not make executed code trustworthy.
- Project trust is a resource-loading choice, not a sandbox. Laptop and isolated environments can use different defaults.
- A general SSH key, API token, browser session, or package-publishing credential available to the laptop user is also available to malicious user-level code.
- A traditional unrestricted bastion only moves ambient authority. Management services should expose constrained operations and keep emergency access human-gated.
- Home-network controls reduce peer exposure but do not prevent malware from initiating outbound traffic.
- Prompt-level rules remain defense in depth. Hard barriers protect high-impact credentials and actions.
