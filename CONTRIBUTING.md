# Contributing to CortexOS Server

Thank you for your interest in contributing! This guide will help you get started.

---

## Quick Start

1. **Fork** the repository
2. **Clone** your fork: `git clone https://github.com/YOUR-USERNAME/cortex-server-os.git`
3. **Create a branch**: `git checkout -b feature/my-improvement`
4. **Make your changes** and test on a fresh Ubuntu VM
5. **Commit**: `git commit -m "Add: description of change"`
6. **Push**: `git push origin feature/my-improvement`
7. **Open a Pull Request**

---

## Development Setup

### Requirements

- Ubuntu 22.04+ (VM recommended for testing)
- Node.js 22+ (via nvm)
- Git

### Local Development

```bash
# Clone the repo
git clone https://github.com/ivanuser/cortex-server-os.git
cd cortex-server-os

# Test the installer on a fresh VM (recommended)
# Do NOT run the installer on your development machine
vagrant up  # If using Vagrant
# or
multipass launch --name cortex-test
multipass shell cortex-test
```

### Testing Changes

Always test on a fresh Ubuntu installation (VM or container):

```bash
# Copy your modified install.sh to the test VM
scp install.sh user@test-vm:~/

# Run it
ssh user@test-vm 'sudo bash ~/install.sh'
```

---

## Areas We'd Love Help With

### 🧠 New Skills

Create new management skills for:
- Database management (PostgreSQL, MySQL, Redis)
- Log analysis and aggregation
- Kubernetes / K3s management
- Cloud provider integrations (AWS, GCP, Azure)
- Certificate management (Let's Encrypt, custom CAs)
- DNS management
- Cron job management

### 🎨 Dashboard Improvements

- Charts and graphs for historical data
- Dark/light theme toggle
- Mobile UX improvements
- Accessibility improvements
- Keyboard shortcuts

### 🔧 Installer

- Support for more Linux distributions (Debian, RHEL, Fedora)
- Raspberry Pi / ARM64 support
- Better error handling and recovery
- Idempotent re-runs

### 📖 Documentation

- Tutorials and how-to guides
- Video walkthroughs
- Translation to other languages
- Architecture deep-dives

### 🧪 Testing

- Automated install testing across Ubuntu versions
- Skill integration tests
- Dashboard E2E tests
- Performance benchmarks

### 🔒 Security

- Audit the installer script
- Review skill permissions and safety
- Report vulnerabilities responsibly (see below)

---

## Coding Guidelines

### General

- Keep it simple — readability over cleverness
- Comment the "why", not the "what"
- Test on a fresh Ubuntu VM before submitting

### Bash (installer, scripts)

- Use `set -euo pipefail` at the top
- Quote all variables: `"$VAR"` not `$VAR`
- Use `[[ ]]` for conditionals
- Functions should be named descriptively
- Add error handling for commands that might fail

### JavaScript (dashboard, skills)

- Use modern ES6+ syntax
- No build step required — keep it simple
- Follow existing code style

### Skills

- One skill per directory
- Include a comprehensive `SKILL.md`
- Add safety constraints for destructive operations
- Test with various prompt phrasings

---

## Commit Messages

Use conventional commits:

```
feat: add PostgreSQL management skill
fix: installer fails on Ubuntu 22.04 minimal
docs: add troubleshooting guide for Docker
style: improve dashboard mobile layout
refactor: extract shared installer functions
test: add install verification checks
chore: update dependencies
```

---

## Pull Request Guidelines

1. **One feature/fix per PR** — keep them focused
2. **Describe what and why** — not just what changed
3. **Include testing steps** — how to verify your changes work
4. **Update docs** if your change affects user-facing behavior
5. **Screenshots** for UI changes

### PR Template

```markdown
## What

Brief description of the change.

## Why

Why this change is needed.

## How to Test

1. Step 1
2. Step 2
3. Expected result

## Checklist

- [ ] Tested on fresh Ubuntu VM
- [ ] Updated documentation
- [ ] No breaking changes
```

---

## Security Vulnerabilities

If you discover a security vulnerability, please **do NOT** open a public issue. Instead:

1. Email the maintainer directly
2. Include a description of the vulnerability
3. Steps to reproduce
4. Potential impact

We'll respond within 48 hours and work with you on a fix.

---

## Code of Conduct

Be respectful and constructive. We're all here to build something useful.

- Be welcoming to newcomers
- Give and accept constructive feedback gracefully
- Focus on what's best for the project
- Show empathy toward others

---

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

Thank you for helping make CortexOS Server better! 🧠
