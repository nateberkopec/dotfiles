# Security

These dotfiles set up the laptop I use every day. Coding agents run on it with broad access. This page explains what I worry about and the rules I follow because of it.

## Report a problem

Found a security problem? Please report it privately through [GitHub's private vulnerability reporting](https://github.com/nateberkopec/dotfiles/security/advisories/new). Don't open a public issue.

## The main threat

My biggest risk is bad code that runs as my user. It can come from:

- A repo I clone
- A dependency or package
- An installer, extension, or downloaded app

Prompt injection and careless agents are real risks too, but they come second.

Watching an agent helps me catch mistakes. It does not stop malware. Once bad code runs, it's too late.

I trust AI model providers only under the terms in [ADR 0009](docs/adr/0009-require-no-training-terms-and-us-inference-from-model-providers.md).

## My rules

### The laptop is a tool, not a vault

Agents can do a lot on the laptop. But the laptop should not hold the keys to everything.

- Agents should not be able to reach long-lived secrets or broad account logins.
- Remote work goes through a broker that grants only the access a task needs.
- A human must approve anything that deletes data, publishes, touches production, changes accounts, needs admin rights, or is hard to undo.

### Untrusted code stays off the laptop

Run unfamiliar code somewhere else first. That includes other people's projects, outside contributions, dependency experiments, and new downloads.

On the laptop, an agent should not load a project's scripts, hooks, or settings until I mark the project as trusted.

### A watcher can warn, but not block

A separate watcher can spot odd activity, keep a record, and alert me. It cannot block or approve anything.

### Backups are how I recover

If something deletes or damages my files, I restore them from backup. Important data must live in versioned backups that I've tested. My normal user account must not be able to quietly erase them.

### Networks

- Services listen only on the laptop itself unless another device needs them.
- My home network is managed, so I trust it more.
- On an unknown network, the laptop locks down. It opens fewer services, stops sharing, and shows less to the outside.

## What this means in practice

- Malware running as me can use any SSH key, API token, browser login, or publishing token that I can.
- A jump box with full access just moves the risk. Management tools should offer narrow actions and keep emergency access behind a human.
- Home network rules limit who can connect in. They don't stop malware from connecting out.
- Instructions to agents are an extra layer of defense. Hard barriers are what protect key logins and risky actions.
