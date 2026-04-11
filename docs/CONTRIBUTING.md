# Contributing Guide

Thank you for your interest in contributing to Enterprise WordPress 2026!

## Getting Started

1. **Fork** the repository on GitHub
2. **Clone** your fork locally
3. **Create a branch** for your changes: `git checkout -b feature/your-feature`
4. **Make your changes** following the guidelines below
5. **Test** your changes: `make validate`
6. **Commit** with a descriptive message
7. **Push** and create a Pull Request

## Development Setup

```bash
# Clone your fork
git clone https://github.com/<your-username>/Enterprise-Wordpress-2026.git
cd Enterprise-Wordpress-2026

# Start development stack
./scripts/deploy.sh --dev

# Validate changes
make validate
```

## Code Standards

### Shell Scripts
- Use `#!/usr/bin/env bash`
- Always `set -euo pipefail`
- Include usage header comments
- Use colored output helpers (info, success, warn, error)
- Pass ShellCheck without warnings

### Docker Compose
- Pin image versions (no `latest` tag)
- Include health checks for all services
- Set resource limits
- Use named volumes
- Add comments explaining non-obvious choices

### Nginx Configuration
- Comment every directive explaining **why**, not just what
- Test with `nginx -t` before committing
- Maintain both production and development configs

### Configuration Files
- Heavy commenting explaining purpose of each setting
- Include tuning guidance for different environments
- Reference official documentation where helpful

## Commit Messages

Use conventional commits:

```
feat: add feature description
fix: fix issue description
docs: update documentation
refactor: refactor component
chore: maintenance task
```

## Pull Request Process

1. Ensure `make validate` passes
2. Update documentation if adding new features
3. Add entries to CHANGELOG.md
4. Request review from maintainers

## Reporting Issues

When filing an issue, include:
- Output of `make status`
- Relevant container logs (`docker compose logs <service>`)
- Your Docker and Docker Compose versions
- Host OS and architecture

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
