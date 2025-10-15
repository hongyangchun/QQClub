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

## 📚 相关文档

- [系统架构设计](../technical/ARCHITECTURE.md)
- [API 接口文档](../technical/API_REFERENCE.md)
- [代码规范](CODING_STANDARDS.md)
- [测试指南](TESTING_GUIDE.md)
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