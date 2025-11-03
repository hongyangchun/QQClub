# Branch Protection Setup Guide

Since this is a personal GitHub repository, some branch protection features need to be configured manually through the GitHub web interface. Follow this guide to set up proper branch protection for your main and develop branches.

## Quick Setup Instructions

### Step 1: Access Branch Protection Settings

1. Navigate to: https://github.com/hongyangchun/QQClub/settings/branches
2. Or go to your repository → Settings → Branches

### Step 2: Protect Main Branch

Click "Add rule" or "Add branch protection rule" and configure:

**Branch name pattern**: `main`

#### Protection Rules to Enable:

✅ **Require a pull request before merging**
- Required number of approvals: `1`
- ✅ Dismiss stale pull request approvals when new commits are pushed
- ✅ Require review from Code Owners (if you set up CODEOWNERS file)

✅ **Require status checks to pass before merging**
- ✅ Require branches to be up to date before merging
- Status checks to require (add as you set up CI/CD):
  - `test` (when you set up automated tests)
  - `lint` (when you set up linting)
  - `build` (when you set up build verification)

✅ **Require conversation resolution before merging**

✅ **Require signed commits** (optional but recommended)

✅ **Require linear history** (optional - prevents merge commits)

✅ **Do not allow bypassing the above settings**
- ⚠️ Only enable this after ensuring CI/CD is working properly

❌ **Do not allow force pushes**

❌ **Do not allow deletions**

#### Rules Applied:

- Pull requests required
- Code review required (1 approval)
- Stale reviews dismissed
- Conversation resolution required
- Force pushes blocked
- Branch deletion blocked

### Step 3: Protect Develop Branch

Click "Add rule" again and configure:

**Branch name pattern**: `develop`

#### Protection Rules to Enable:

✅ **Require a pull request before merging**
- Required number of approvals: `1`
- ✅ Dismiss stale pull request approvals when new commits are pushed

✅ **Require status checks to pass before merging**
- ✅ Require branches to be up to date before merging
- Status checks to require (same as main):
  - `test`
  - `lint`
  - `build`

✅ **Require conversation resolution before merging**

⚠️ **Allow force pushes** (for administrators only)
- Enable this but restrict to administrators
- Useful for rebasing and cleaning up history when needed

❌ **Do not allow deletions**

#### Rules Applied:

- Pull requests required
- Code review required (1 approval)
- Stale reviews dismissed
- Conversation resolution required
- Force pushes allowed (admins only)
- Branch deletion blocked

## Current Repository Settings

The following settings have been automatically configured:

✅ **Merge button options**:
- Allow merge commits: Enabled
- Allow squash merging: Enabled
- Allow rebase merging: Enabled
- Automatically delete head branches: Enabled

## Additional Recommended Configurations

### 1. Set Up CODEOWNERS File

Create a `.github/CODEOWNERS` file to automatically request reviews from specific people or teams:

```
# CODEOWNERS file
# These owners will be requested for review when someone opens a pull request

# Global owners for all files
* @hongyangchun

# API backend code
/qqclub_api/ @hongyangchun

# WeChat Mini Program
/qqclub-miniprogram/ @hongyangchun

# Documentation
/docs/ @hongyangchun
*.md @hongyangchun

# Configuration files
/config/ @hongyangchun
/.github/ @hongyangchun
```

### 2. Create Pull Request Template

Create `.github/pull_request_template.md`:

```markdown
## Summary
<!-- Brief description of what this PR does -->

## Type of Change
<!-- Mark the relevant option with an 'x' -->

- [ ] 🐛 Bug fix (non-breaking change which fixes an issue)
- [ ] ✨ New feature (non-breaking change which adds functionality)
- [ ] 💥 Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] 📝 Documentation update
- [ ] 🎨 Style/UI update (no functional changes)
- [ ] ♻️ Code refactoring (no functional changes)
- [ ] ⚡️ Performance improvement
- [ ] ✅ Test update

## Changes
<!-- List the changes made in this PR -->

- Change 1
- Change 2
- Change 3

## Testing Checklist
<!-- Mark completed items with an 'x' -->

- [ ] Unit tests added/updated
- [ ] Integration tests pass
- [ ] Manual testing completed
- [ ] Edge cases considered and tested

## Screenshots
<!-- If applicable, add screenshots to help explain your changes -->

## Related Issues
<!-- Link related issues here. Use "Closes #123" to auto-close issues when PR is merged -->

Closes #

## Additional Notes
<!-- Any additional information that reviewers should know -->

## Reviewer Checklist
<!-- For reviewers to complete -->

- [ ] Code follows project conventions
- [ ] Changes are well-documented
- [ ] No security vulnerabilities introduced
- [ ] Performance impact is acceptable
- [ ] Tests adequately cover the changes
```

### 3. Set Up GitHub Actions for CI/CD

Create `.github/workflows/ci.yml`:

```yaml
name: CI

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]

jobs:
  test:
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres:14
        env:
          POSTGRES_PASSWORD: postgres
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432

    steps:
    - uses: actions/checkout@v3

    - name: Set up Ruby
      uses: ruby/setup-ruby@v1
      with:
        ruby-version: 3.2
        bundler-cache: true
        working-directory: ./qqclub_api

    - name: Install dependencies
      working-directory: ./qqclub_api
      run: bundle install

    - name: Set up database
      working-directory: ./qqclub_api
      env:
        RAILS_ENV: test
        DATABASE_URL: postgres://postgres:postgres@localhost:5432/qqclub_test
      run: |
        bundle exec rails db:create
        bundle exec rails db:schema:load

    - name: Run tests
      working-directory: ./qqclub_api
      env:
        RAILS_ENV: test
        DATABASE_URL: postgres://postgres:postgres@localhost:5432/qqclub_test
      run: bundle exec rails test

    - name: Run RuboCop
      working-directory: ./qqclub_api
      run: bundle exec rubocop
      continue-on-error: true

  lint:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v3

    - name: Set up Ruby
      uses: ruby/setup-ruby@v1
      with:
        ruby-version: 3.2
        bundler-cache: true
        working-directory: ./qqclub_api

    - name: Run RuboCop
      working-directory: ./qqclub_api
      run: bundle exec rubocop --format github
```

### 4. Security Settings

Navigate to: https://github.com/hongyangchun/QQClub/settings/security_analysis

✅ Enable:
- Dependency graph
- Dependabot alerts
- Dependabot security updates
- Secret scanning (if available for private repos)

### 5. Notification Settings

Configure notifications for:
- Pull request reviews
- Status check failures
- Security alerts
- Dependabot alerts

## Verification Steps

After setting up branch protection, verify it works:

### Test Main Branch Protection

```bash
# Try to push directly to main (should fail)
git checkout main
echo "test" >> test.txt
git add test.txt
git commit -m "test: verify branch protection"
git push origin main
# Expected: Push should be rejected or require a PR
```

### Test PR Workflow

```bash
# Create a feature branch
git checkout develop
git checkout -b feature/test-protection
echo "test" >> test.txt
git add test.txt
git commit -m "feat: test branch protection workflow"
git push -u origin feature/test-protection

# Create PR via GitHub web interface
gh pr create --base develop --title "feat: test branch protection" --body "Testing PR workflow"

# Try to merge without approval (should fail)
# Request review and get approval
# Then merge should succeed
```

## Troubleshooting

### Issue: Cannot push to protected branch

**Solution**: Create a feature branch and submit a PR instead
```bash
git checkout develop
git checkout -b feature/your-change
# Make changes
git push -u origin feature/your-change
gh pr create
```

### Issue: Status checks not showing up

**Solution**:
1. Ensure GitHub Actions workflows are configured
2. Check workflow runs in Actions tab
3. Verify workflow names match required status checks

### Issue: Need to bypass protection for emergency fix

**Solution**:
1. Temporarily disable protection for main branch (admin only)
2. Make the emergency fix
3. Re-enable protection immediately after
4. Document the bypass in your changelog

## Maintenance

### Regular Reviews

Review and update branch protection settings:
- Monthly: Review required status checks
- Quarterly: Audit bypass usage and approvers
- Yearly: Review overall branch strategy

### Status Check Updates

When adding new CI/CD checks:
1. Add workflow to `.github/workflows/`
2. Test workflow on feature branch
3. Update required status checks in branch protection

## Quick Reference

### GitHub Settings URLs

- Branch protection: https://github.com/hongyangchun/QQClub/settings/branches
- General settings: https://github.com/hongyangchun/QQClub/settings
- Security: https://github.com/hongyangchun/QQClub/settings/security_analysis
- Actions: https://github.com/hongyangchun/QQClub/settings/actions

### CLI Commands

```bash
# View branch protection
gh api repos/hongyangchun/QQClub/branches/main/protection

# Create PR
gh pr create --base develop --title "Title" --body "Description"

# View PR checks
gh pr checks

# Merge PR
gh pr merge --squash
```

## Resources

- [GitHub Branch Protection Documentation](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/defining-the-mergeability-of-pull-requests/about-protected-branches)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [CODEOWNERS Documentation](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners)

---

**Last Updated**: 2025-01-16
**Version**: 1.0.0
**Status**: Manual setup required (personal repository limitations)
