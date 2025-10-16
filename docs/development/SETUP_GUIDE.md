# QQClub 开发环境搭建指南

本指南将帮助您快速搭建 QQClub 项目的本地开发环境。

## 📋 环境要求

### 必需软件
- **Ruby**: 3.3.0+
- **Rails**: 8.0.0+
- **PostgreSQL**: 14+ (生产环境)
- **Git**: 2.30+
- **Node.js**: 18+ (用于前端工具)

### 推荐工具
- **VS Code** 或 **RubyMine** - IDE
- **Postico** 或 **pgAdmin** - 数据库管理工具
- **Postman** - API 测试工具
- **Docker** - 容器化部署
- **Git** - 版本控制（必需）

## 🚀 快速开始

### 1. 克隆项目
```bash
git clone <repository-url>
cd QQClub
```

### 2. 安装 Ruby 依赖
```bash
cd qqclub_api
bundle install
```

### 3. 配置数据库
```bash
# 创建数据库
rails db:create

# 运行迁移
rails db:migrate

# 可选：填充测试数据
rails db:seed
```

### 4. 项目目录结构说明
```bash
# 统一仓库目录结构
QQClub/                          # 完全统一的项目仓库
├── qqclub_api/                  # Rails 8 API后端
│   ├── app/                     # 应用代码
│   ├── config/                  # 配置文件
│   ├── db/                      # 数据库文件
│   └── test/                    # 测试文件
├── qqclub-miniprogram/          # 微信小程序前端
│   ├── pages/                   # 页面文件
│   ├── components/              # 组件文件
│   ├── services/                # 服务层
│   ├── utils/                   # 工具函数
│   └── styles/                  # 样式文件
├── docs/                        # 项目文档
│   ├── business/                # 业务文档
│   ├── technical/               # 技术文档
│   └── development/             # 开发文档
├── scripts/                     # 工具脚本和自动化工具
├── backups/                     # 备份目录
└── .claude/commands/            # 自定义命令
```

### 5. 启动开发环境
```bash
# 启动Rails API服务器（在qqclub_api目录中）
cd qqclub_api
rails server

# 在另一个终端启动小程序开发者工具（可选）
# 导入 qqclub-miniprogram 目录
```

### 4. 配置环境变量
创建 `.env` 文件：
```bash
cp .env.example .env
```

编辑 `.env` 文件：
```bash
# JWT密钥
JWT_SECRET_KEY=your_secret_key_here

# 数据库配置
DATABASE_URL=postgresql://localhost/qqclub_development

# 微信API配置（开发环境可选）
WECHAT_APP_ID=your_wechat_app_id
WECHAT_APP_SECRET=your_wechat_app_secret

# Rails密钥
RAILS_MASTER_KEY=your_rails_master_key
```

### 5. 启动开发服务器
```bash
rails server
```

服务器将在 `http://localhost:3000` 启动。

## 🧪 运行测试

```bash
# 运行所有测试
rails test

# 运行特定测试
rails test test/models/user_test.rb

# 运行系统测试
rails test:system

# 生成测试覆盖率报告
rails test:coverage
```

## 🔧 开发工具配置

### VS Code 推荐插件
- **Ruby** - Ruby 语言支持
- **Rails** - Rails 框架支持
- **PostgreSQL** - 数据库支持
- **REST Client** - API 测试
- **GitLens** - Git 增强工具

### 数据库管理

#### 使用 psql 命令行
```bash
# 连接到开发数据库
psql -d qqclub_development

# 查看所有表
\dt

# 退出
\q
```

#### 使用 GUI 工具
1. **Postico** (Mac) - 直观的 PostgreSQL 客户端
2. **pgAdmin** (跨平台) - 功能丰富的数据库管理工具

### API 测试

#### 使用 curl
```bash
# 获取当前用户信息
curl -H "Authorization: Bearer YOUR_JWT_TOKEN" \
     http://localhost:3000/api/auth/me

# 创建新帖子
curl -X POST \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer YOUR_JWT_TOKEN" \
     -d '{"post":{"title":"测试标题","content":"测试内容"}}' \
     http://localhost:3000/api/posts
```

#### 使用 Postman
1. 导入 API 集合（见 `docs/postman_collection.json`）
2. 配置环境变量
3. 设置 JWT Token 认证

## 🐛 常见问题解决

### Ruby 版本问题
```bash
# 使用 rbenv 管理 Ruby 版本
rbenv install 3.3.0
rbenv local 3.3.0

# 或使用 rvm
rvm install 3.3.0
rvm use 3.3.0
```

### 数据库连接问题
```bash
# 检查 PostgreSQL 服务状态
brew services list

# 启动 PostgreSQL 服务
brew services start postgresql

# 重置数据库
rails db:reset
```

### 依赖安装问题
```bash
# 清理并重新安装
bundle clean --force
bundle install

# 如果遇到 pg gem 问题
gem install pg -- --with-pg-config=/usr/local/bin/pg_config
```

### 权限问题
```bash
# 如果遇到文件权限问题
sudo chown -R $USER:$(id -gn $USER) /path/to/project

# 或使用 rbenv rehash
rbenv rehash
```

## 🔄 日常开发工作流

### 1. 创建功能分支
```bash
git checkout -b feature/new-feature-name
```

### 2. 开发和测试
```bash
# 运行测试
rails test

# 启动服务器进行手动测试
rails server

# 检查代码质量
rails lint
```

### 3. 提交代码
```bash
# 方法一：使用 qq-deploy 自动化部署（推荐）
./scripts/qq-deploy.sh --feature="新功能名称"

# 方法二：手动提交
git add .
git commit -m "feat: 添加新功能描述"

# 推送到远程仓库
git push origin feature/new-feature-name
```

### 4. 创建 Pull Request
1. 在 GitHub/GitLab 上创建 PR
2. 请求代码审查
3. 通过 CI/CD 检查
4. 合并到主分支

## 📊 性能监控

### 开发环境性能分析
```bash
# 启动性能监控
rails server --profile

# 查看查询统计
rails log:query:stats

# 内存使用分析
rails memory_bloat
```

### 数据库查询优化
```bash
# 查找 N+1 查询问题
rails log:find_n_plus_one

# 生成查询计划
EXPLAIN ANALYZE SELECT * FROM users WHERE id = 1;
```

## 🔐 安全开发

### 环境变量管理
```bash
# 查看当前环境变量
rails credentials:edit

# 加密敏感信息
rails encrypted:edit
```

### 测试用户认证
```bash
# 创建测试用户
rails console
> User.create!(wx_openid: 'test_openid', nickname: '测试用户')
```

## 🚀 QQClub 部署系统

项目内置了完整的自动化部署系统 `qq-deploy`，让代码提交和部署变得简单、标准化。

### 快速使用

#### 标准部署
```bash
# 完整的部署流程，包含测试和文档更新
./scripts/qq-deploy.sh
```

#### 功能发布
```bash
# 标记特定功能的发布
./scripts/qq-deploy.sh --feature="论坛系统"
```

#### 版本发布
```bash
# 生产环境版本发布
./scripts/qq-deploy.sh --release --version="v1.2.0"
```

#### 紧急修复
```bash
# 快速修复线上问题
./scripts/qq-deploy.sh --hotfix --message="修复权限越界问题"
```

#### 预览模式
```bash
# 查看将要执行的操作，不实际执行
./scripts/qq-deploy.sh --dry-run --debug
```

### 配置部署系统

#### 创建配置文件
首次使用时会自动创建 `.qq-deploy.yml` 配置文件：

```yaml
# 基础配置
auto_commit: true          # 自动提交代码
auto_push: true           # 自动推送到远程仓库
run_tests: true           # 运行测试套件
update_docs: true         # 更新项目文档

# 环境特定配置
environments:
  development:
    auto_push: true
    run_tests: true
    create_backup: false

  production:
    auto_push: true
    create_backup: true
    require_tag: true

# 分支保护
branch_protection:
  protected_branches: [main, master]
  require_confirmation: true
```

### 部署流程说明

qq-deploy 会按以下顺序执行：

1. **环境检查** - 验证 Git 状态和分支
2. **项目评估** - 分析变更内容和类型
3. **文档更新** - 自动运行 `/qq-docs` 命令
4. **测试执行** - 自动运行 `/qq-test` 命令
5. **Git 操作** - 智能生成 Commit 消息并推送
6. **生成报告** - 输出详细的部署报告

### 智能 Commit 消息

系统会根据变更内容自动生成有意义的 Commit 消息：

```
[auto] 2025-10-15 - 新增权限系统和论坛功能

变更统计：
- 修改: 5 个文件
- 新增: 3 个文件
- 删除: 2 个文件

主要变更：
  - app/models/user.rb
  - app/controllers/admin_controller.rb
  - app/controllers/posts_controller.rb
```

### 安全特性

- **分支保护** - 主分支操作需要确认
- **权限验证** - 检查推送权限
- **回滚机制** - 保存回滚点，支持快速恢复
- **备份策略** - 重要操作前自动备份

### 常用命令选项

| 选项 | 说明 | 示例 |
|------|------|------|
| `--dry-run` | 模拟执行，不实际操作 | `./scripts/qq-deploy.sh --dry-run` |
| `--force` | 强制执行，跳过某些检查 | `./scripts/qq-deploy.sh --force` |
| `--skip-tests` | 跳过测试执行 | `./scripts/qq-deploy.sh --skip-tests` |
| `--skip-docs` | 跳过文档更新 | `./scripts/qq-deploy.sh --skip-docs` |
| `--message` | 自定义 Commit 消息 | `./scripts/qq-deploy.sh --message="修复登录问题"` |
| `--debug` | 显示详细调试信息 | `./scripts/qq-deploy.sh --debug` |
| `--help` | 显示帮助信息 | `./scripts/qq-deploy.sh --help` |

### 最佳实践

1. **日常开发** - 使用 `./scripts/qq-deploy.sh --feature="功能名称"`
2. **版本发布** - 使用 `./scripts/qq-deploy.sh --release --version="版本号"`
3. **紧急修复** - 使用 `./scripts/qq-deploy.sh --hotfix`
4. **测试验证** - 使用 `./scripts/qq-deploy.sh --dry-run` 预览操作

## 📚 相关文档

- [系统架构概览](../technical/ARCHITECTURE.md) - 高层架构设计，快速了解系统架构
- [API 接口文档](../technical/API_REFERENCE.md) - 完整的API规格和接口说明
- [技术实现细节](../technical/TECHNICAL_DESIGN.md) - 深度技术实现和设计决策
- [权限系统指南](../technical/PERMISSIONS_GUIDE.md) - 权限系统使用指南
- [测试框架指南](../technical/TESTING_GUIDE.md) - 测试框架和规范
- [代码规范](CODING_STANDARDS.md)
- [部署指南](DEPLOYMENT.md)

## 🆘 获取帮助

### 项目资源
- **项目仓库**: [GitHub Repository]
- **问题反馈**: [GitHub Issues]
- **讨论交流**: [GitHub Discussions]

### 社区资源
- **Ruby on Rails Guides**: https://guides.rubyonrails.org/
- **PostgreSQL 文档**: https://www.postgresql.org/docs/
- **Stack Overflow**: https://stackoverflow.com/questions/tagged/ruby-on-rails

---

**最后更新**: 2025-10-15
**维护者**: QQClub 开发团队