# 🧪 QQClub 测试命令菜单

## 📋 核心测试命令

### 🚀 日常开发推荐
- **`/qq-test-quick`** - 快速检查 (2-3分钟) ⭐ 日常推荐
  - API服务器连接、数据库连接、核心端点基础功能
  - 脚本：`scripts/qq-test.sh quick`

### 📊 主要测试选项
1. **`/qq-test`** - **完整测试套件** (15-25分钟) 🔥
   - 模型 + API + 权限 + 可选性能测试 + 覆盖率报告
   - 脚本：`scripts/qq-test.sh all`

2. **`/qq-test models`** - 模型测试 (3-5分钟)
   - User、Post、ReadingEvent等核心业务逻辑测试
   - 脚本：`scripts/qq-test.sh models`

3. **`/qq-test api`** - API功能测试 (5-10分钟)
   - 认证、论坛、活动、权限端点测试
   - 脚本：`scripts/qq-test.sh api`

4. **`/qq-test permissions`** - 权限系统测试 (5-8分钟)
   - 3层权限体系、角色权限、边界测试
   - 脚本：`scripts/qq-test.sh permissions`

5. **`/qq-test controllers`** - 控制器测试 (3-5分钟)
   - 路由、参数处理、错误处理测试
   - 脚本：`scripts/qq-test.sh controllers`

6. **`/qq-test diagnose`** - 详细诊断 (15-20分钟)
   - 完整测试集 + 性能测试 + 详细报告
   - 脚本：`scripts/qq-test.sh diagnose`

### 🛠️ 专用命令
- **`/qq-permissions`** - 权限系统专项检查
  - 3层权限架构深度验证、安全评估

## 💡 使用建议

### 日常开发流程
1. **开发完成** → `/qq-test-quick` (2分钟)
2. **功能验证** → `/qq-test api` (5分钟)
3. **提交前检查** → `/qq-test diagnose` (15分钟)

### 发布前检查清单
1. **完整测试** → `/qq-test` (20分钟)
2. **权限验证** → `/qq-permissions` (8分钟)
3. **模型测试** → `/qq-test models` (5分钟)

### 问题排查
1. **快速诊断** → `/qq-test-quick --debug`
2. **API问题** → `/qq-test api --verbose`
3. **权限问题** → `/qq-test-permissions --debug`
4. **模型问题** → `/qq-test models --verbose`

## 🔧 通用选项
所有 `/qq-test` 命令都支持以下选项：
- `--verbose` - 详细输出
- `--debug` - 调试模式
- `--api-url <url>` - 指定API服务器地址
- `--no-coverage` - 跳过覆盖率测试
- `--performance` - 包含性能测试
- `--parallel` - 并行执行测试

## ⏰ 时间预估总结
- **快速检查**: 2-3分钟
- **单项测试**: 3-10分钟
- **详细诊断**: 15-20分钟
- **完整测试**: 15-25分钟

选择适合您当前需求的测试命令！