# QQClub Development Workflow

## Overview

This document outlines the development workflow for the QQClub project using Git Flow methodology. Following this workflow ensures code quality, team collaboration, and safe deployment practices.

## Branch Strategy

### Main Branches

| Branch | Purpose | Protection | Merges From | Deploys To |
|--------|---------|------------|-------------|------------|
| `main` | Production-ready code | Protected | `release/*`, `hotfix/*` | Production |
| `develop` | Integration branch | Protected | `feature/*`, `hotfix/*` | Staging/Test |

### Supporting Branches

| Type | Prefix | Created From | Merged To | Lifetime | Purpose |
|------|--------|--------------|-----------|----------|---------|
| Feature | `feature/` | `develop` | `develop` | Until feature completion | New features and enhancements |
| Release | `release/` | `develop` | `main`, `develop` | Until release deployment | Release preparation and bug fixes |
| Hotfix | `hotfix/` | `main` | `main`, `develop` | Until hotfix deployment | Emergency production fixes |

## Workflow Guide

### 1. Feature Development

**Starting a Feature**
```bash
# Switch to develop and update
git checkout develop
git pull origin develop

# Create feature branch
git checkout -b feature/descriptive-feature-name

# Push to remote and set upstream
git push -u origin feature/descriptive-feature-name
```

**Working on Feature**
```bash
# Make changes, commit frequently
git add .
git commit -m "feat: implement user authentication

- Add JWT authentication middleware
- Create login and registration endpoints
- Add user session management

Co-Authored-By: Claude <noreply@anthropic.com>"

# Push changes regularly
git push origin feature/descriptive-feature-name
```

**Completing a Feature**
```bash
# Update develop branch
git checkout develop
git pull origin develop

# Merge feature (create PR on GitHub for code review)
# After PR approval, merge will be done via GitHub

# Clean up local branch after merge
git branch -d feature/descriptive-feature-name
git remote prune origin
```

### 2. Release Process

**Starting a Release**
```bash
# Create release branch from develop
git checkout develop
git pull origin develop
git checkout -b release/v1.2.0

# Update version numbers in relevant files
# - qqclub_api/config/application.rb
# - package.json (if applicable)

git add .
git commit -m "chore: bump version to v1.2.0"
git push -u origin release/v1.2.0
```

**Release Testing & Bug Fixes**
```bash
# Fix bugs found during release testing
git add .
git commit -m "fix: resolve issue in release candidate"
git push origin release/v1.2.0
```

**Completing a Release**
```bash
# Merge to main (via GitHub PR)
git checkout main
git pull origin main
git merge --no-ff release/v1.2.0

# Tag the release
git tag -a v1.2.0 -m "Release version 1.2.0

Major Features:
- Feature A
- Feature B

Bug Fixes:
- Fix C
- Fix D"

git push origin main --tags

# Merge back to develop
git checkout develop
git pull origin develop
git merge --no-ff release/v1.2.0
git push origin develop

# Clean up release branch
git branch -d release/v1.2.0
git push origin --delete release/v1.2.0
```

### 3. Hotfix Process

**Starting a Hotfix**
```bash
# Create hotfix from main
git checkout main
git pull origin main
git checkout -b hotfix/critical-security-fix

# Make the fix
git add .
git commit -m "fix: patch critical security vulnerability

- Update dependency X to version Y
- Add input validation for Z

Security: Fixes CVE-XXXX-YYYY"

git push -u origin hotfix/critical-security-fix
```

**Completing a Hotfix**
```bash
# Merge to main (via GitHub PR for urgent review)
git checkout main
git merge --no-ff hotfix/critical-security-fix

# Tag the hotfix
git tag -a v1.2.1 -m "Hotfix v1.2.1: Critical security patch"
git push origin main --tags

# Merge to develop
git checkout develop
git merge --no-ff hotfix/critical-security-fix
git push origin develop

# Clean up
git branch -d hotfix/critical-security-fix
git push origin --delete hotfix/critical-security-fix
```

## Commit Message Convention

We follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

### Format
```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, no code change)
- `refactor`: Code refactoring
- `perf`: Performance improvements
- `test`: Adding or updating tests
- `chore`: Maintenance tasks, dependency updates
- `ci`: CI/CD configuration changes

### Examples
```bash
# Feature commit
git commit -m "feat(auth): add OAuth2 authentication

- Implement OAuth2 provider integration
- Add social login buttons
- Update user model for OAuth tokens"

# Bug fix commit
git commit -m "fix(api): resolve rate limiting issue

The rate limiter was incorrectly counting requests.
Changed from IP-based to user-based counting.

Fixes #123"

# Breaking change commit
git commit -m "feat(api)!: change authentication endpoint

BREAKING CHANGE: The /auth endpoint now returns a different response format.
Updated documentation to reflect new structure."
```

## Code Review Process

### Pull Request Guidelines

1. **PR Title**: Use conventional commit format
   - Example: `feat(reading-events): add event enrollment system`

2. **PR Description Template**:
   ```markdown
   ## Summary
   Brief description of what this PR does

   ## Changes
   - Change 1
   - Change 2
   - Change 3

   ## Testing
   - [ ] Unit tests added/updated
   - [ ] Integration tests pass
   - [ ] Manual testing completed

   ## Screenshots (if applicable)

   ## Related Issues
   Closes #123
   ```

3. **Review Requirements**:
   - At least 1 approval required
   - All CI checks must pass
   - No merge conflicts
   - Up to date with base branch

4. **PR Size Guidelines**:
   - Small PRs: < 200 lines changed (preferred)
   - Medium PRs: 200-500 lines changed
   - Large PRs: > 500 lines (should be split if possible)

## Development Environment Setup

### Prerequisites
```bash
# Ruby environment
ruby -v  # Should be 3.x

# Rails
bundle install
bundle exec rails db:setup

# WeChat Mini Program development
# Install WeChat DevTools
```

### Running Tests
```bash
# Run all tests
bundle exec rails test

# Run specific test file
bundle exec rails test test/models/user_test.rb

# Run with coverage
COVERAGE=true bundle exec rails test
```

### Local Development Server
```bash
# Start Rails API server
cd qqclub_api
bundle exec rails server -p 3000

# Use the deployment script
./scripts/qq-deploy.sh
```

## Deployment Process

### Environments

| Environment | Branch | URL | Purpose |
|-------------|--------|-----|---------|
| Development | `feature/*` | Local | Feature development |
| Staging | `develop` | TBD | Integration testing |
| Production | `main` | TBD | Live application |

### Deployment Checklist

**Pre-Deployment**
- [ ] All tests passing
- [ ] Code reviewed and approved
- [ ] Documentation updated
- [ ] Database migrations reviewed
- [ ] Environment variables configured
- [ ] Rollback plan prepared

**Deployment Steps**
1. Merge PR to target branch
2. Run database migrations
3. Deploy application
4. Run smoke tests
5. Monitor logs and metrics
6. Verify critical features

**Post-Deployment**
- [ ] Verify deployment in target environment
- [ ] Check error logs
- [ ] Monitor performance metrics
- [ ] Update release notes
- [ ] Notify team

## Branch Protection Rules

### Main Branch (`main`)
- Require pull request reviews before merging (1 approval minimum)
- Require status checks to pass before merging
- Require conversation resolution before merging
- Do not allow force pushes
- Do not allow deletions

### Develop Branch (`develop`)
- Require pull request reviews before merging (1 approval minimum)
- Require status checks to pass before merging
- Allow force pushes by admins only (for exceptional cases)

## Best Practices

### 1. Keep Branches Up to Date
```bash
# Update develop regularly
git checkout develop
git pull origin develop

# Rebase feature branch on latest develop
git checkout feature/your-feature
git rebase develop
git push -f origin feature/your-feature  # Only for feature branches
```

### 2. Write Descriptive Branch Names
- Good: `feature/user-authentication-jwt`
- Good: `hotfix/payment-processing-timeout`
- Bad: `feature/new-stuff`
- Bad: `fix-bug`

### 3. Commit Frequently
- Make small, logical commits
- Each commit should be a complete thought
- Commit messages should explain "why" not "what"

### 4. Keep PRs Focused
- One feature/fix per PR
- Easier to review and understand
- Faster to merge
- Easier to rollback if needed

### 5. Test Before Pushing
```bash
# Run tests
bundle exec rails test

# Run linters
rubocop

# Check for security issues
bundle audit
```

## Troubleshooting

### Merge Conflicts
```bash
# Update your branch with latest develop
git checkout develop
git pull origin develop
git checkout feature/your-feature
git merge develop

# Resolve conflicts in your editor
# Then:
git add .
git commit -m "chore: resolve merge conflicts with develop"
git push origin feature/your-feature
```

### Accidental Commit to Wrong Branch
```bash
# If not pushed yet
git reset HEAD~1  # Undo last commit, keep changes
git stash         # Stash changes
git checkout correct-branch
git stash pop     # Apply changes
```

### Need to Update Commit Message
```bash
# Last commit only, not pushed
git commit --amend -m "New message"

# If already pushed (avoid if possible)
git commit --amend -m "New message"
git push -f origin feature/your-feature  # Only for feature branches!
```

## Quick Reference

### Common Commands
```bash
# Check current branch and status
git status
git branch -vv

# Switch branches
git checkout develop
git checkout -b feature/new-feature

# Update from remote
git pull origin develop
git fetch --all --prune

# Push changes
git push origin feature/your-feature
git push -u origin feature/your-feature  # First push with upstream

# Clean up
git branch -d feature/completed-feature
git remote prune origin

# View commit history
git log --oneline --graph --all
```

## Resources

- [Git Flow Cheat Sheet](https://danielkummer.github.io/git-flow-cheatsheet/)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [Semantic Versioning](https://semver.org/)
- [GitHub Flow Guide](https://guides.github.com/introduction/flow/)

## Team Communication

- **Daily Standups**: Share what you're working on
- **PR Reviews**: Review promptly, provide constructive feedback
- **Code Standards**: Follow project conventions
- **Documentation**: Update docs with code changes

---

**Last Updated**: 2025-01-16
**Version**: 1.0.0
**Maintained By**: QQClub Development Team
