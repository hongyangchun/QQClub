# QQClub 读书社群 - Rails 学习总计划

## 项目目标
构建一个现代化的读书社群平台，采用前后端分离架构：
- 🏗️ **Rails 8 API 后端** + 📱 **微信小程序前端**
- 👥 **多层权限体系** (管理员级别、活动级别、用户级别)
- 💬 **论坛功能** (发帖、评论、置顶、隐藏)
- 📚 **读书活动管理** (创建、审批、报名、打卡)
- 🌸 **小红花互动** (评选、激励、排行榜)

## 学习理念（DHH 的话）
> "你要的不是完美的全部，而是厉害的一半。我们会先构建核心功能，让它跑起来，然后逐步完善。这就是 Rails 之道 - Progressive Disclosure（渐进式揭示）。"

---

## 第一阶段：Rails 8 API 基础 & 认证系统（第 1 周）

### Phase 1.1: Rails 8 API 项目创建 ✅
**目标：** 创建现代化 API 后端项目

- [x] 创建 Rails 8.0 API 项目（`rails new qqclub_api --api`）
- [x] 配置 SQLite 数据库（Rails 8 生产就绪）
- [x] 设置 CORS 跨域支持
- [x] 添加必要 gems（JWT、认证等）
- [x] 理解 API 模式的目录结构

**Rails 核心概念：**
- API 模式（去除 View 层）
- Convention over Configuration（约定优于配置）
- ActionController::API 基类

### Phase 1.2: 微信登录 & JWT 认证 ✅
**目标：** 实现无状态用户认证系统

- [x] 创建 User 模型（微信 OpenID 登录）
- [x] 实现 JWT token 生成和验证
- [x] 创建 Authenticable concern
- [x] 实现认证 API 端点
- [x] 添加 mock_login 用于测试

**Rails 核心概念：**
- JWT 无状态认证
- Concerns（关注点分离）
- Strong Parameters（强参数）

---

## 第二阶段：核心业务模块 & 权限体系（第 2 周）

### Phase 2.1: 读书活动核心模型 ✅
**目标：** 构建完整的读书活动业务逻辑

- [x] **ReadingEvent 模型**（共读活动）
- [x] **Enrollment 模型**（报名记录）
- [x] **ReadingSchedule 模型**（每日阅读计划）
- [x] **CheckIn 模型**（打卡记录）
- [x] **DailyLeading 模型**（领读内容）
- [x] **Flower 模型**（小红花）

**Rails 核心概念：**
- 复杂关联关系设计
- 枚举类型使用
- 自定义验证规则
- 回调方法
- 作用域查询

### Phase 2.2: 论坛功能系统 ✅
**目标：** 实现社区交流功能

- [x] **Post 模型**（论坛帖子）
- [x] 帖子 CRUD API
- [x] 帖子置顶和隐藏功能
- [x] 权限控制（作者编辑、管理员管理）
- [x] 帖子列表和详情 API

**Rails 核心概念：**
- RESTful API 设计
- 权限验证模式
- JSON 序列化

### Phase 2.3: 3层权限体系 ✅
**目标：** 构建灵活的权限管理系统

- [x] **Admin Level**（管理员级别：Root + Admin）
- [x] **Event Level**（活动级别：Group Leader + Daily Leader）
- [x] **User Level**（用户级别：Forum User + Participant）
- [x] 权限验证 Concern（AdminAuthorizable）
- [x] 3天权限窗口机制
- [x] 备份机制（Group Leader 补位）

**Rails 核心概念：**
- 基于角色的权限控制（RBAC）
- Concerns 模式
- 时间窗口权限验证
- 条件权限检查

---

---

## 第三阶段：高级功能 & 优化（第 3 周）

### Phase 3.1: Service Objects & 业务逻辑优化
**目标：** 重构复杂业务逻辑，提高代码质量

- [ ] **EventCreationService**（活动创建服务）
- [ ] **CheckInValidationService**（打卡验证服务）
- [ ] **FlowerAwardService**（小红花发放服务）
- [ ] **EventSummaryService**（活动统计服务）
- [ ] **PermissionService**（权限检查服务）

**Rails 核心概念：**
- Service Objects 模式
- 业务逻辑分离
- 依赖注入
- 错误处理

### Phase 3.2: 测试覆盖 & API 完善
**目标：** 确保系统稳定性和API完整性

- [ ] 模型单元测试
- [ ] API 集成测试
- [ ] 权限系统测试
- [ ] 边界条件测试
- [ ] API 文档生成

**Rails 核心概念：**
- Test::Unit 框架
- Fixtures & Factories
- Mocking & Stubbing
- API 测试最佳实践

### Phase 3.3: 性能优化 & 缓存
**目标：** 优化系统性能，提升用户体验

- [ ] N+1 查询优化
- [ ] 数据库索引优化
- [ ] Solid Cache 缓存策略
- [ ] API 响应时间优化
- [ ] 分页查询实现

**Rails 核心概念：**
- 查询优化技术
- Bullet gem（N+1 检测）
- Solid Cache（Rails 8 内置）
- 数据库索引设计

---

## 第四阶段：部署 & 前端集成（第 4 周）

### Phase 4.1: 生产环境部署
**目标：** 将应用部署到生产环境

- [ ] Kamal 2 部署配置
- [ ] PostgreSQL 生产数据库
- [ ] 环境变量管理
- [ ] SSL 证书配置
- [ ] 监控和日志设置

**Rails 核心概念：**
- Kamal 2（零停机部署）
- 环境配置管理
- Credentials 加密
- 生产环境优化

### Phase 4.2: 微信小程序前端开发
**目标：** 开发微信小程序前端

- [ ] 小程序项目初始化
- [ ] 微信登录集成
- [ ] 活动列表和详情页面
- [ ] 打卡和领读功能
- [ ] 小红花互动界面

**技术栈：**
- 微信小程序原生
- Vant Weapp UI 组件
- API 请求封装
- 状态管理

### Phase 4.3: 支付集成 & 高级功能
**目标：** 完善商业功能

- [ ] 微信支付集成
- [ ] 模板消息通知
- [ ] 数据统计和报表
- [ ] 用户行为分析
- [ ] 系统监控告警

**Rails 核心概念：**
- Payment Gateway 集成
- Action Mailer / Action Text
- Background Jobs（Solid Queue）
- 监控和日志系统

---

## 项目架构总结

### 🏗️ 技术架构
- **后端**: Rails 8 API + SQLite/PostgreSQL
- **前端**: 微信小程序原生
- **认证**: JWT + 微信 OpenID
- **部署**: Kamal 2 + Docker
- **队列**: Solid Queue (数据库驱动)
- **缓存**: Solid Cache (数据库驱动)

### 👥 权限体系
- **3层架构**: Admin Level → Event Level → User Level
- **灵活角色**: Root, Admin, Group Leader, Daily Leader, Forum User, Participant
- **时间窗口**: 领读人3天权限机制
- **备份机制**: Group Leader 全程补位权限

### 📊 核心功能模块
1. **用户认证**: 微信登录 + JWT
2. **论坛系统**: 发帖、评论、置顶、隐藏
3. **读书活动**: 创建、审批、报名、管理
4. **打卡系统**: 每日记录、内容管理
5. **领读功能**: 内容发布、问题设计
6. **小红花**: 评选、激励、排行榜

---

## 学习方法（DHH 的建议）

### 1. **先让它跑起来，再让它完美**
不要一开始就追求完美的代码。先实现功能，理解概念，然后重构。

### 2. **遵循 Rails 约定**
当你不确定时，问自己："Rails 的方式是什么？" 查阅 Rails Guides。

### 3. **小步快跑**
每完成一个小功能就测试。频繁提交代码（git commit）。

### 4. **阅读官方文档**
Rails Guides 是你最好的朋友：https://guides.rubyonrails.org

### 5. **享受过程**
编程应该带来快乐。当你看到功能跑起来时，庆祝它！

---

## 技术栈（Rails 8 Omakase）

- **框架：** Ruby on Rails 8.0
- **数据库：** SQLite（开发）/ PostgreSQL（生产）
- **队列：** Solid Queue（数据库驱动）
- **缓存：** Solid Cache（数据库驱动）
- **WebSocket：** Solid Cable（数据库驱动）
- **前端：** Hotwire（Turbo + Stimulus）
- **样式：** Tailwind CSS
- **部署：** Kamal 2

**这就是 "No PaaS Required" 的威力！** 你不需要 Redis、不需要复杂的云服务，一个数据库搞定一切。

---

## 下一步
开始 Phase 1.1 - 创建项目！
