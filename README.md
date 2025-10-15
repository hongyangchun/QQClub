# QQClub 读书社区

一个基于 Rails 8 + 微信小程序的读书社群平台，致力于打造高质量的共读体验。

## 🌟 项目简介

QQClub 是一个现代化的读书社区平台，支持：

- 📚 **读书活动管理**: 创建、组织、管理读书共读活动
- 💬 **论坛讨论**: 社区成员自由交流学习心得
- ✅ **每日打卡**: 记录阅读进度，分享学习感悟
- 🌸 **小红花互动**: 社区化的鼓励和认可机制
- 👥 **多层权限**: 灵活的角色权限管理体系

## 🏗️ 技术架构

### 后端技术栈
- **Ruby on Rails 8** - 现代 Web 框架
- **PostgreSQL** - 可靠的关系型数据库
- **JWT** - 无状态用户认证
- **Active Record** - 强大的 ORM
- **Solid Queue** - Rails 8 内置后台任务

### 前端技术栈
- **微信小程序** - 原生小程序开发
- **Vant Weapp** - UI 组件库
- **MobX** - 状态管理（可选）

### 部署架构
- **Kamal 2** - Rails 8 零停机部署
- **Docker** - 容器化部署
- **Let's Encrypt** - SSL 证书

## 🚀 快速开始

### 环境要求
- Ruby 3.3+
- PostgreSQL 14+
- Rails 8.0+

### 安装步骤
```bash
# 1. 克隆项目
git clone <repository-url>
cd QQClub

# 2. 进入后端目录
cd qqclub_api

# 3. 安装依赖
bundle install

# 4. 配置数据库
rails db:create
rails db:migrate

# 5. 启动开发服务器
rails server
```

详细的环境搭建指南请参考：[📖 开发环境搭建指南](docs/development/SETUP_GUIDE.md)

## 📚 文档中心

### 📊 业务文档
- [业务分析文档](docs/business/BUSINESS_ANALYSIS.md) - 用户角色、业务流程、商业模式
- [用户故事](docs/business/USER_STORIES.md) - 用户场景和需求描述
- [MVP范围](docs/business/MVP_SCOPE.md) - 最小可行产品功能规划

### 🔧 技术文档
- [系统架构设计](docs/technical/ARCHITECTURE.md) - 技术栈、架构图、设计决策
- [API接口文档](docs/technical/API_REFERENCE.md) - 完整的API规范和示例
- [数据库设计](docs/technical/DATABASE_DESIGN.md) - 数据模型、表结构
- [安全设计](docs/technical/SECURITY_DESIGN.md) - 认证、授权、安全机制

### 👨‍💻 开发文档
- [环境搭建指南](docs/development/SETUP_GUIDE.md) - 本地开发环境配置
- [代码规范](docs/development/CODING_STANDARDS.md) - 编码风格和最佳实践
- [测试指南](docs/development/TESTING_GUIDE.md) - 单元测试、集成测试规范
- [部署指南](docs/development/DEPLOYMENT.md) - 测试和生产环境部署

完整文档导航请访问：[📚 文档中心](docs/README.md)

## 🎯 核心功能

### 📚 读书活动
- **活动创建**: 任何人都可以发起读书活动，管理员审批后生效
- **智能排期**: 自动生成每日阅读计划和领读安排
- **灵活管理**: 支持自由报名和随机分配领读人

### 💬 社区论坛
- **自由讨论**: 社区成员可以发布帖子、评论互动
- **内容管理**: 管理员可以置顶优质内容、隐藏不当言论
- **权限控制**: 作者可以编辑自己的内容，管理员有审核权限

### ✅ 打卡系统
- **每日记录**: 参与者每天提交阅读心得和体会
- **质量控制**: 最低字数要求，确保内容质量
- **灵活修改**: 支持补卡功能，适应不同作息习惯

### 🌸 互动机制
- **小红花**: 领读人评选当日优秀打卡，送小红花鼓励
- **积分体系**: 小红花数量反映参与度和贡献度
- **社区氛围**: 形成积极向上的学习氛围

## 👥 权限体系

QQClub 采用 3 层权限架构：

### 管理员级别
- **Root**: 系统超级管理员，拥有最高权限
- **Admin**: 社区管理员，负责日常管理和审批

### 活动级别
- **Group Leader**: 读书活动创建者，全程管理权限
- **Daily Leader**: 每日领读人，3天权限窗口管理

### 用户级别
- **Forum User**: 论坛用户，基础发帖评论权限
- **Participant**: 活动参与者，完整的活动参与权限

详细权限设计请参考：[系统架构设计](docs/technical/ARCHITECTURE.md)

## 🔗 API 接口

### 认证接口
- `POST /api/auth/login` - 用户登录
- `GET /api/auth/me` - 获取当前用户信息

### 论坛接口
- `GET /api/posts` - 获取帖子列表
- `POST /api/posts` - 创建帖子
- `POST /api/posts/:id/pin` - 置顶帖子

### 活动接口
- `GET /api/events` - 获取活动列表
- `POST /api/events` - 创建活动
- `POST /api/events/:id/enroll` - 报名活动

完整 API 文档请参考：[API接口文档](docs/technical/API_REFERENCE.md)

## 📊 项目状态

### 开发进度
- ✅ **后端API**: 核心功能完成
- ✅ **用户认证**: 微信登录集成
- ✅ **权限系统**: 3层权限架构
- ✅ **业务逻辑**: 6大核心模块
- 🚧 **小程序前端**: 开发中
- 📋 **支付集成**: 规划中

### 测试覆盖率
- 单元测试: 85%+
- 集成测试: 70%+
- API测试: 90%+

### 部署状态
- 开发环境: ✅ 运行中
- 测试环境: 🚧 配置中
- 生产环境: 📋 规划中

## 🤝 贡献指南

我们欢迎所有形式的贡献！

### 贡献方式
1. **报告问题**: 在 Issues 中报告 bug 或提出功能建议
2. **代码贡献**: Fork 项目，创建功能分支，提交 Pull Request
3. **文档改进**: 完善文档，修正错误，提升可读性
4. **测试**: 编写测试用例，提高代码覆盖率

### 开发流程
1. 阅读 [开发指南](docs/development/SETUP_GUIDE.md)
2. Fork 项目并创建功能分支
3. 编写代码和测试
4. 确保所有测试通过
5. 提交 Pull Request

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 🆘 联系我们

- **项目仓库**: [GitHub Repository]
- **问题反馈**: [GitHub Issues]
- **讨论交流**: [GitHub Discussions]
- **邮箱**: [project-email@example.com]

## 🙏 致谢

感谢所有为 QQClub 项目做出贡献的开发者和社区成员！

---

**QQClub** - 让阅读更有温度，让社区更有力量 🌸

*最后更新: 2025-10-15*