# QQClub Deploy - 项目部署和发布命令

这个命令帮助你完成每日工作的最后一步：代码提交、文档更新、测试验证和发布部署。

## 执行流程

### 1. 环境检查
首先确保发布环境准备就绪：
- 检查 Git 工作区状态
- 验证是否有未提交的变更
- 确认分支状态
- 检查远程连接

### 2. 项目状态评估
评估当前项目状态：
- 检查代码完整性
- 验证测试通过状态
- 确认文档同步状态
- 统计今日完成内容

### 3. 自动化准备工作
自动执行发布前的准备工作：
```bash
# 更新项目文档
/qq-docs

# 运行完整测试
/qq-test

# 权限系统检查（可选）
/qq-permissions
```

### 4. 版本管理
处理版本相关信息：
- 更新版本号（如需要）
- 生成变更日志
- 创建 Git 标签（如需要）
- 更新项目统计

### 5. Git 操作
执行标准的 Git 提交流程：
```bash
# 添加所有变更
git add .

# 生成智能 commit 消息
git commit -m "[auto] $(date +'%Y-%m-%d') - 今日开发进展

$(git status --porcelain | grep '^ M' | wc -l) 个文件修改
$(git status --porcelain | grep '^ A' | wc -l) 个文件新增
$(git status --porcelain | grep '^ D' | wc -l) 个文件删除

主要变更：
- $(git diff --cached --name-only | head -5 | sed 's/^/  - /')
"

# 推送到远程仓库
git push origin main
```

### 6. 后续处理
完成发布后的清理工作：
- 清理临时文件
- 更新本地统计
- 生成发布报告
- 可选：发送通知

## 智能特性

### 自动 Commit 消息生成
根据变更内容自动生成有意义的 commit 消息：

#### 开发功能类
```
[auto] 2025-10-15 - 新增权限系统和论坛功能

变更类型：
- 新增: 3个模型文件, 2个控制器文件
- 修改: 5个配置文件, 1个数据库迁移
- 删除: 2个废弃文件

主要功能：
- 实现3层权限架构
- 添加论坛发帖功能
- 完善权限验证机制
```

#### 文档更新类
```
[auto] 2025-10-15 - 更新项目文档架构

变更类型：
- 新增: 8个文档文件
- 修改: 3个配置文件
- 删除: 1个重复文档

主要更新：
- 重构文档目录结构
- 更新API测试指南
- 同步权限体系文档
```

### 工作流检测
根据当前工作内容自动调整部署流程：

#### 包含新功能时
- 自动运行完整测试套件
- 验证权限系统
- 更新API文档

#### 仅文档更新时
- 跳过性能测试
- 验证文档链接
- 生成变更摘要

#### 修复Bug时
- 运行相关测试
- 验证修复效果
- 记录问题解决

## 配置选项

### 发布配置
在项目根目录创建 `.qq-deploy.yml` 配置文件：

```yaml
# 基础配置
auto_commit: true
auto_push: true
auto_tag: false

# 测试配置
run_tests: true
test_timeout: 300

# 文档配置
update_docs: true
update_api_docs: true

# 通知配置
enable_notifications: false
webhook_url: ""

# 备份配置
create_backup: false
backup_path: "./backups"
```

### 环境检测
```yaml
# 开发环境
development:
  auto_push: true
  run_tests: true
  create_backup: false

# 生产环境
production:
  auto_push: true
  run_tests: true
  create_backup: true
  require_tag: true
```

## 使用场景

### 日常开发完成时
```bash
# 完成一天的开发工作后
/qq-deploy
```

### 功能模块完成时
```bash
# 完成一个完整功能模块
/qq-deploy --feature="权限系统"
```

### 发布版本时
```bash
# 准备发布新版本
/qq-deploy --release --version="v1.2.0"
```

### 紧急修复时
```bash
# 快速修复紧急问题
/qq-deploy --hotfix --message="修复权限越界问题"
```

## 命令参数

### 基础参数
```bash
/qq-deploy [options]
```

### 可选参数
- `--dry-run` - 模拟执行，不实际提交
- `--force` - 强制提交，跳过某些检查
- `--skip-tests` - 跳过测试执行
- `--skip-docs` - 跳过文档更新
- `--message "<text>"` - 自定义 commit 消息
- `--feature "<name>"` - 标记功能名称
- `--release` - 标记为发布版本
- `--hotfix` - 标记为紧急修复
- `--version "<version>"` - 指定版本号

### 示例用法
```bash
# 标准部署
/qq-deploy

# 模拟执行
/qq-deploy --dry-run

# 功能发布
/qq-deploy --feature="论坛系统"

# 版本发布
/qq-deploy --release --version="v1.2.0"

# 紧急修复
/qq-deploy --hotfix --message="修复权限越界问题"
```

## 安全考虑

### 分支保护
- 检查当前分支状态
- 防止直接推送到 main 分支（可配置）
- 验证 commit 信息格式

### 权限验证
- 检查推送权限
- 验证身份认证
- 记录操作日志

### 回滚机制
- 保存回滚点
- 提供回滚命令
- 备份重要文件

## 故障处理

### 常见问题
1. **Git 状态错误**
   - 工作区不干净
   - 分支冲突
   - 远程连接失败

2. **测试失败**
   - 测试环境问题
   - 依赖缺失
   - 数据库连接错误

3. **文档冲突**
   - 文档版本不一致
   - 链接失效
   - 格式错误

### 恢复策略
```bash
# 如果部署失败，提供恢复命令
echo "部署失败，执行恢复操作..."
git reset --soft HEAD~1
echo "已回滚到上一个提交状态"
```

## 统计和报告

### 发布统计
- **代码统计**: 文件变更数量、代码行数变化
- **功能统计**: 新增功能、修复bug数量
- **时间统计**: 开发时间、测试时间
- **质量统计**: 测试覆盖率、bug数量

### 报告生成
```markdown
# QQClub 发布报告 - 2025-10-15

## 📊 今日统计
- **代码文件**: +5/-2
- **代码行数**: +234/-56
- **测试通过**: 18/18
- **文档更新**: 3个文件

## 🚀 主要功能
- 实现权限系统架构
- 添加论坛发帖功能
- 完善API测试指南

## 📝 下一步计划
- Service Objects重构
- 性能优化
- 用户界面改进
```

---

这个命令让你的每日工作收尾变得简单、标准化、可追溯，确保代码质量和项目健康度。