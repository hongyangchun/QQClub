# 单人开发工作流指南

## 适用场景
本指南适用于 **QQClub 项目只有一个开发者（你）** 的情况。

## 简化版 Git Flow

### 核心原则
1. ✅ 保持 `main` 分支稳定（只放可部署的代码）
2. ✅ 在 `develop` 分支上开发和测试
3. ✅ 大功能使用 feature 分支
4. ✅ 小改动可以直接在 `develop` 上进行

### 分支策略

```
main        生产环境代码（严格保护）
  ↑
develop     开发和测试（适度保护）
  ↑
feature/*   大功能开发（灵活）
```

## 简化的分支保护设置

### `main` 分支 - 最小化保护
```
目标：防止误操作，确保质量

必须设置：
✅ Require status checks to pass before merging
   └─ ✅ Require branches to be up to date before merging

可选设置（强烈推荐）：
✅ Do not allow force pushes  （防止 git push -f 误操作）
✅ Do not allow deletions      （防止误删除 main 分支）

可以不设置：
❌ Require a pull request      （一个人开发时太繁琐）
❌ Require approvals           （自己审核自己没意义）
```

### `develop` 分支 - 极简保护
```
可选设置：
✅ Require status checks to pass  （可选，确保测试通过）

其他不需要设置
```

## 日常工作流程

### 场景 1：小改动、bug 修复
```bash
# 直接在 develop 分支上工作
git checkout develop
git pull origin develop

# 修改代码
# ...

# 提交
git add .
git commit -m "fix: 修复登录问题"

# 运行测试
bundle exec rails test

# ✅ 测试通过后推送
git push origin develop
```

### 场景 2：新功能开发
```bash
# 创建 feature 分支
git checkout develop
git pull origin develop
git checkout -b feature/reading-event-enhancement

# 开发功能
# ...

# 提交到 feature 分支
git add .
git commit -m "feat: 添加共读活动增强功能"
git push origin feature/reading-event-enhancement

# 测试通过后，合并回 develop
git checkout develop
git merge --no-ff feature/reading-event-enhancement
git push origin develop

# 删除 feature 分支
git branch -d feature/reading-event-enhancement
git push origin --delete feature/reading-event-enhancement
```

### 场景 3：发布到生产环境
```bash
# 确保 develop 分支稳定且测试通过
git checkout develop
bundle exec rails test
# ✅ 所有测试通过

# 合并到 main
git checkout main
git pull origin main
git merge --no-ff develop

# 打标签
git tag -a v1.2.0 -m "Release v1.2.0: 添加共读活动增强功能"

# 推送
git push origin main --tags

# 如果设置了状态检查，GitHub 会自动运行测试
# 测试通过后才能推送成功
```

### 场景 4：紧急修复
```bash
# 从 main 创建 hotfix 分支
git checkout main
git pull origin main
git checkout -b hotfix/critical-bug

# 修复问题
# ...

git add .
git commit -m "fix: 修复支付系统严重漏洞"
git push origin hotfix/critical-bug

# 测试通过后，合并到 main
git checkout main
git merge --no-ff hotfix/critical-bug
git tag -a v1.2.1 -m "Hotfix v1.2.1: 修复支付漏洞"
git push origin main --tags

# 也合并到 develop
git checkout develop
git merge --no-ff hotfix/critical-bug
git push origin develop

# 清理
git branch -d hotfix/critical-bug
git push origin --delete hotfix/critical-bug
```

## 利用 CI/CD 自动化测试

即使只有一个人开发，**自动化测试也非常有价值**！

### GitHub Actions 会自动：
```yaml
每次推送到 main 或 develop 时：
✓ 运行所有测试
✓ 检查代码风格
✓ 安全扫描
✓ 生成测试覆盖率报告

如果测试失败：
❌ GitHub 会显示红色 ❌
✉️ 发邮件通知你
🚫 如果设置了分支保护，会阻止合并
```

### 查看测试结果
```bash
# 在 GitHub 上查看
open "https://github.com/hongyangchun/QQClub/actions"

# 或者用命令行
gh run list
gh run view
```

## 最小化的分支保护设置步骤

### 设置 `main` 分支保护

1. 访问：https://github.com/hongyangchun/QQClub/settings/branches
2. 点击 "Add branch protection rule"
3. Branch name pattern: `main`
4. **只勾选以下选项**：
   ```
   ✅ Require status checks to pass before merging
      └─ ✅ Require branches to be up to date before merging

   ✅ Do not allow force pushes
   ✅ Do not allow deletions
   ```
5. 点击 "Create" 保存

### `develop` 分支
```
可以不设置任何保护，保持灵活
或者只设置：
✅ Require status checks to pass （可选）
```

## 什么时候需要完整的分支保护？

当项目发展到以下情况时，再考虑完整的保护规则：

- ✅ 有第二个开发者加入
- ✅ 项目变得很重要，不能容忍任何失误
- ✅ 需要完整的审计追踪
- ✅ 团队协作需要

## 核心建议

### ⭐ 必须做的
1. **设置 CI/CD 自动测试** - 这是最重要的！
2. **保护 main 分支不被强制推送和删除**
3. **养成写清晰 commit message 的习惯**
4. **定期推送到远程仓库**（防止本地数据丢失）

### 👍 建议做的
1. 大功能用 feature 分支
2. 发布时打 tag
3. 保持 main 分支的稳定性

### 🤷 可以不做的
1. 创建 PR 后自己审核自己
2. 要求多人 approval
3. 过于严格的保护规则

## 工具推荐

### 快速命令别名
```bash
# 添加到 ~/.zshrc 或 ~/.bashrc
alias gdev="git checkout develop && git pull origin develop"
alias gmain="git checkout main && git pull origin main"
alias gtest="bundle exec rails test"
alias gdeploy="./scripts/qq-deploy.sh"

# 使用
gdev      # 快速切换到 develop 并更新
gtest     # 快速运行测试
```

### GitHub CLI 工具
```bash
# 查看最近的提交
gh repo view --web

# 查看 CI 状态
gh run list

# 查看分支
gh api repos/hongyangchun/QQClub/branches
```

## 总结

**单人开发的最佳实践 = 简化 + 自动化**

```
✅ 必须有：自动化测试（CI/CD）
✅ 必须有：防止误操作的基本保护
✅ 建议有：清晰的分支策略
❌ 不需要：复杂的人工审核流程
```

记住：**工具是为了提高效率，而不是增加负担**。选择适合你的工作流程！💪

---

**Last Updated**: 2025-01-16
**适用于**: 单人开发的 QQClub 项目
