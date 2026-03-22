---
name: Bug Report
about: Report a bug to help improve CortexOS Server
title: '[Bug] '
labels: bug
assignees: ''
---

## Description

A clear description of the bug.

## Steps to Reproduce

1. Go to '...'
2. Click on '...'
3. See error

## Expected Behavior

What you expected to happen.

## Actual Behavior

What actually happened.

## Environment

- **OS:** Ubuntu 24.04 / Docker / etc.
- **Installation method:** Bare metal / Docker / Management server
- **CortexOS version:** (output of `openclaw --version`)
- **Node.js version:** (output of `node --version`)
- **AI Provider:** Anthropic / OpenAI / Ollama (model name)

## Logs

```
Paste relevant logs here.
Bare metal: sudo journalctl -u cortex-server -n 50 --no-pager
Docker: docker compose logs cortexos --tail 50
```

## Screenshots

If applicable, add screenshots.

## Additional Context

Any other context about the problem.
