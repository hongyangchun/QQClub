# QQClub 自定义命令索引

这里包含了 QQClub 项目的所有自定义 slash 命令，帮助你高效地管理和开发项目。

## 📋 可用命令

### `/qq-continue`
**用途**: QQClub 项目开发助手，DHH 角色指导
- 跟踪项目开发进度
- 提供下一步开发指导
- DHH 风格的技术教学

**适用场景**: 日常开发、学习 Rails、项目推进

### `/qq-docs`
**用途**: QQClub 项目文档更新和同步
- 保持文档与代码一致性
- 自动检测需要更新的文档
- 生成文档更新报告

**适用场景**: 功能开发完成后、发布前准备、文档维护

### `/qq-test`
**用途**: QQClub 项目全面测试执行
- 模型测试 (核心业务逻辑)
- API 功能测试 (端到端验证)
- 权限系统验证 (3层权限体系)
- 可选性能测试和覆盖率报告

**适用场景**: 代码提交前、功能验证、发布前测试
**脚本**: `scripts/qq-test.sh all`

### `/qq-permissions`
**用途**: QQClub 权限系统专项检查
- 3 层权限体系验证
- 角色权限测试
- 时间窗口权限检查
- 安全性评估

**适用场景**: 权限系统变更后、安全审计、定期检查

### `/qq-deploy`
**用途**: QQClub 项目部署和发布
- 自动化 Git 提交流程
- 智能生成 commit 消息
- 自动运行测试和文档更新
- 完整的发布工作流

**适用场景**: 每日工作完成时、功能发布时、版本发布时

## 🚀 使用建议

### 日常开发工作流
1. 开始开发: `/qq-continue`
2. 快速检查: `/qq-test-quick`
3. 完成功能: `/qq-test`
4. 更新文档: `/qq-docs`
5. 权限验证: `/qq-permissions`
6. 完成工作: `/qq-deploy`

### 发布前检查清单
- [ ] `/qq-test` - 完整测试套件 (15-25分钟)
- [ ] `/qq-permissions` - 验证权限系统 (5-8分钟)
- [ ] `/qq-docs` - 同步文档更新
- [ ] `/qq-deploy` - 自动化部署流程
- [ ] 人工 review - 最终检查

### 定期维护
- **每日**: `/qq-test-quick` 快速检查 + `/qq-deploy` 工作收尾
- **每周**: `/qq-permissions` 权限系统检查
- **每版本**: `/qq-docs` 文档更新 + `/qq-test` 完整测试
- **持续**: `/qq-continue` 开发指导

### 测试命令层级
- **快速检查**: `/qq-test-quick` (2-3分钟)
- **单项测试**: `/qq-test models|api|controllers|permissions`
- **完整测试**: `/qq-test` (15-25分钟)
- **详细诊断**: `/qq-test diagnose`
- **测试菜单**: `/qq-test-menu` 查看所有选项

## 📁 命令文件结构

```
.claude/
├── commands/
│   ├── README.md              # 命令索引（本文件）
│   ├── qq-continue.md         # QQClub开发指导命令
│   ├── qq-docs.md            # QQClub文档更新命令
│   ├── qq-test.md            # QQClub完整测试命令
│   ├── qq-test-quick.md      # QQClub快速检查命令
│   ├── qq-test-menu.md       # QQClub测试菜单命令
│   ├── qq-permissions.md     # QQClub权限检查命令
│   └── qq-deploy.md          # QQClub部署发布命令
└── settings.local.json        # Claude Code 配置
```

## 🔧 自定义新命令

如果你想创建新的自定义命令，请遵循以下步骤：

### 1. 创建命令文件
```bash
# 在 .claude/commands/ 目录下创建新的 .md 文件
touch .claude/commands/your-command.md
```

### 2. 编写命令内容
命令文件应包含：
- **命令用途**: 清晰描述命令的目的
- **执行流程**: 详细的执行步骤
- **使用场景**: 适用的使用情况
- **注意事项**: 重要的提醒和限制

### 3. 遵循命名规范
- 使用小写字母和连字符
- 名称要直观地反映命令功能
- 保持简洁明了

### 4. 测试命令
确保命令能够正确执行并产生预期结果

## 🛠️ 配置说明

### 权限配置
`.claude/settings.local.json` 文件配置了 Claude Code 可以执行的命令权限：

```json
{
  "permissions": {
    "allow": [
      "Bash(ruby:*)",
      "Bash(rails -v)",
      "Bash(bin/rails:*)",
      "Bash(curl:*)",
      // ... 其他允许的命令
    ]
  }
}
```

### 添加新权限
如果新命令需要特殊的系统权限，需要在 `settings.local.json` 中添加相应的允许规则。

## 📚 相关资源

- [Claude Code 官方文档](https://docs.anthropic.com/claude/docs/claude-code)
- [QQClub 项目文档](../docs/README.md)
- [Rails Guides](https://guides.rubyonrails.org/)
- [测试指南](../docs/technical/TESTING_GUIDE.md)

## 🤝 贡献指南

如果你有改进建议或发现命令问题：
1. 检查现有命令是否满足需求
2. 提出改进建议或新命令想法
3. 遵循现有的命令格式和风格
4. 确保新命令有明确的用途和价值

---

这些自定义命令将大大提高你的 QQClub 项目开发效率，让常见的开发和维护任务变得简单快捷。