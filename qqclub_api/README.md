# QQClub 读书社区 API

基于 Rails 8 构建的读书社区API后端，支持论坛讨论、读书活动、打卡记录、小红花互动等功能。

## 核心功能

- 📚 **读书活动管理**：创建、审批、报名读书活动
- 💬 **论坛讨论**：发帖、评论、置顶、隐藏
- ✅ **每日打卡**：阅读进度记录和内容分享
- 🌸 **小红花互动**：给优秀打卡送花鼓励
- 👥 **角色权限**：多层级的权限管理体系

## 快速开始

### 环境要求
- Ruby 3.3+
- PostgreSQL 14+
- Rails 8

### 安装步骤
```bash
# 克隆项目
git clone <repository-url>
cd qqclub_api

# 安装依赖
bundle install

# 配置数据库
rails db:create
rails db:migrate

# 启动服务
rails server
```

### 环境变量
```bash
# JWT密钥
JWT_SECRET_KEY=your_secret_key

# 数据库配置
DATABASE_URL=postgresql://user:password@localhost/qqclub_development

# 微信API配置（可选）
WECHAT_APP_ID=your_wechat_app_id
WECHAT_APP_SECRET=your_wechat_app_secret
```

## 技术架构

### 核心技术栈
- **Ruby on Rails 8** - API模式
- **PostgreSQL** - 主数据库
- **JWT** - 用户认证
- **Active Record** - ORM
- **RSpec** - 测试框架

### 关键特性
- **3层权限体系**：管理员级别、活动级别、用户级别
- **RESTful API**：标准化的API设计
- **模块化架构**：清晰的业务模块划分
- **安全机制**：JWT认证、权限控制、输入验证

## 主要API端点

### 认证
- `POST /api/auth/mock_login` - 微信模拟登录
- `GET /api/auth/me` - 获取当前用户信息

### 论坛
- `GET /api/posts` - 获取帖子列表
- `POST /api/posts` - 创建帖子
- `POST /api/posts/:id/pin` - 置顶帖子

### 活动
- `GET /api/events` - 获取活动列表
- `POST /api/events` - 创建活动
- `POST /api/events/:id/enroll` - 报名活动

### 打卡
- `POST /api/reading_schedules/:schedule_id/check_ins` - 创建打卡
- `POST /api/check_ins/:id/flower` - 送小红花

### 管理
- `GET /api/admin/dashboard` - 管理面板
- `GET /api/admin/events/pending` - 待审批活动

## 文档

- 📖 [技术设计文档](./TECHNICAL_DESIGN.md) - 详细的系统架构和权限设计
- 🔧 [API文档](./API_DOCS.md) - 完整的API接口文档

## 贡献指南

1. Fork 项目
2. 创建功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

## 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 部署说明

### 环境要求
- Ruby 3.3+
- PostgreSQL 14+
- Rails 8

### 安装步骤
```bash
# 克隆项目
git clone <repository-url>
cd qqclub_api

# 安装依赖
bundle install

# 配置数据库
rails db:create
rails db:migrate

# 启动服务
rails server
```

### 环境变量
```bash
# JWT密钥
JWT_SECRET_KEY=your_secret_key

# 数据库配置
DATABASE_URL=postgresql://user:password@localhost/qqclub_development

# 微信API配置（可选）
WECHAT_APP_ID=your_wechat_app_id
WECHAT_APP_SECRET=your_wechat_app_secret
```

## 贡献指南

1. Fork 项目
2. 创建功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

## 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。
