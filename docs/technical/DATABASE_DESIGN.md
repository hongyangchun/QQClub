# QQClub 数据库设计文档

## 📋 文档说明

**定位**: QQClub 项目的完整数据库设计说明，包含所有数据表结构、关系和设计决策
**目标读者**: 后端开发者、数据库管理员、系统架构师
**文档深度**: 详细的表结构说明，包含字段类型、约束、索引和关系

---

## 🗄️ 数据库概览

### 技术栈
- **数据库**: SQLite (开发) / PostgreSQL (生产)
- **ORM**: Active Record
- **迁移框架**: Rails Migrations
- **字符集**: UTF-8
- **时区**: UTC

### 设计原则
1. **规范化**: 遵循第三范式，避免数据冗余
2. **可扩展**: 预留扩展字段，支持未来功能迭代
3. **性能优先**: 合理使用索引，优化查询性能
4. **数据完整性**: 使用外键约束和数据验证
5. **命名规范**: 统一使用下划线命名法

---

## 👥 用户系统 (User System)

### users 表
用户核心信息表，存储用户基本资料和权限信息。

```sql
CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  wx_openid VARCHAR(255) NOT NULL UNIQUE,
  wx_unionid VARCHAR(255) UNIQUE,
  nickname VARCHAR(100),
  avatar_url VARCHAR(500),
  phone VARCHAR(20),
  role INTEGER DEFAULT 0 NOT NULL,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);
```

**字段说明**:
- `id`: 主键，自增
- `wx_openid`: 微信OpenID，唯一标识用户
- `wx_unionid`: 微信UnionID，跨应用统一标识
- `nickname`: 用户昵称
- `avatar_url`: 头像URL
- `phone`: 手机号码
- `role`: 用户角色 (0: 用户, 1: 管理员, 2: 超级管理员)

**索引**:
- `index_users_on_wx_openid` (unique)
- `index_users_on_wx_unionid` (unique)
- `index_users_on_role`

**约束**:
- `wx_openid` 必须唯一
- `role` 值在 [0, 1, 2] 范围内

---

## 📚 读书活动系统 (Reading Events System)

### reading_events 表
读书活动主表，存储活动基本信息。

```sql
CREATE TABLE reading_events (
  id SERIAL PRIMARY KEY,
  title VARCHAR(200) NOT NULL,
  book_name VARCHAR(200) NOT NULL,
  book_cover_url VARCHAR(500),
  description TEXT,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  max_participants INTEGER NOT NULL,
  enrollment_fee DECIMAL(10,2) DEFAULT 0.0,
  service_fee DECIMAL(10,2) DEFAULT 0.0,
  deposit DECIMAL(10,2) DEFAULT 0.0,
  status INTEGER DEFAULT 0 NOT NULL,
  approval_status INTEGER,
  leader_assignment_type INTEGER,
  leader_id INTEGER,
  approved_by INTEGER,
  approved_at TIMESTAMP,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL,
  FOREIGN KEY (leader_id) REFERENCES users(id),
  FOREIGN KEY (approved_by) REFERENCES users(id)
);
```

**字段说明**:
- `title`: 活动标题
- `book_name`: 书籍名称
- `book_cover_url`: 书籍封面URL
- `description`: 活动描述
- `start_date`: 开始日期
- `end_date`: 结束日期
- `max_participants`: 最大参与人数
- `enrollment_fee`: 报名费用
- `service_fee`: 服务费
- `deposit`: 押金
- `status`: 活动状态 (0: 草稿, 1: 报名中, 2: 进行中, 3: 已完成)
- `approval_status`: 审批状态
- `leader_assignment_type`: 领读人分配方式
- `leader_id`: 小组长ID
- `approved_by`: 审批人ID
- `approved_at`: 审批时间

### enrollments 表
活动报名记录表，存储用户参与活动的信息。

```sql
CREATE TABLE enrollments (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL,
  reading_event_id INTEGER NOT NULL,
  payment_status INTEGER DEFAULT 0 NOT NULL,
  role INTEGER DEFAULT 0 NOT NULL,
  paid_amount DECIMAL(10,2) DEFAULT 0.0,
  enrollment_date DATE NOT NULL,
  completion_rate DECIMAL(5,2) DEFAULT 0.0,
  flowers_count INTEGER DEFAULT 0,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (reading_event_id) REFERENCES reading_events(id) ON DELETE CASCADE,
  UNIQUE(user_id, reading_event_id)
);
```

**字段说明**:
- `payment_status`: 支付状态 (0: 未支付, 1: 已支付, 2: 已退款)
- `role`: 角色 (0: 参与者, 1: 小组长)
- `paid_amount`: 已支付金额
- `enrollment_date`: 报名日期
- `completion_rate`: 完成率
- `flowers_count`: 获得小红花数量

### reading_schedules 表
阅读计划表，定义每日阅读安排。

```sql
CREATE TABLE reading_schedules (
  id SERIAL PRIMARY KEY,
  reading_event_id INTEGER NOT NULL,
  day_number INTEGER NOT NULL,
  date DATE NOT NULL,
  reading_progress VARCHAR(200),
  daily_leader_id INTEGER,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL,
  FOREIGN KEY (reading_event_id) REFERENCES reading_events(id) ON DELETE CASCADE,
  FOREIGN KEY (daily_leader_id) REFERENCES users(id)
);
```

**字段说明**:
- `day_number`: 第几天
- `date`: 计划日期
- `reading_progress`: 阅读进度
- `daily_leader_id`: 当日领读人ID

---

## 📝 论坛系统 (Forum System)

### posts 表
论坛帖子表，存储用户发布的帖子内容。

```sql
CREATE TABLE posts (
  id SERIAL PRIMARY KEY,
  title VARCHAR(100) NOT NULL,
  content TEXT NOT NULL,
  category VARCHAR(20),
  images JSON,
  tags JSON,
  user_id INTEGER NOT NULL,
  pinned BOOLEAN DEFAULT FALSE,
  hidden BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
```

**字段说明**:
- `title`: 帖子标题 (最大100字符)
- `content`: 帖子内容 (10-5000字符)
- `category`: 帖子分类 (reading, activity, chat, help)
- `images`: 图片URL数组 (JSON格式)
- `tags`: 标签数组 (JSON格式)
- `user_id`: 作者ID
- `pinned`: 是否置顶
- `hidden`: 是否隐藏

**索引**:
- `index_posts_on_user_id`
- `index_posts_on_category`
- `index_posts_on_pinned`
- `index_posts_on_hidden`
- `index_posts_on_created_at`
- `index_posts_on_pinned_and_created_at`

**约束**:
- `title` 不能为空，长度不超过100字符
- `content` 不能为空，长度在10-5000字符之间
- `category` 只能是 'reading', 'activity', 'chat', 'help' 或为空

### comments 表
评论表，存储对帖子的评论。

```sql
CREATE TABLE comments (
  id SERIAL PRIMARY KEY,
  content TEXT NOT NULL,
  user_id INTEGER NOT NULL,
  post_id INTEGER NOT NULL,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE
);
```

**字段说明**:
- `content`: 评论内容
- `user_id`: 评论者ID
- `post_id`: 帖子ID

---

## ❤️ 社交互动系统 (Social Interaction System)

### likes 表
点赞表，存储用户对各种内容的点赞记录。

```sql
CREATE TABLE likes (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL,
  target_type VARCHAR(255) NOT NULL,
  target_id INTEGER NOT NULL,
  created_at TIMESTAMP NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  UNIQUE(user_id, target_type, target_id)
);
```

**字段说明**:
- `target_type`: 目标类型 (Post, CheckIn 等)
- `target_id`: 目标ID
- 使用多态关联支持对多种内容类型点赞

### flowers 表
小红花表，存储领读人给打卡用户的鼓励记录。

```sql
CREATE TABLE flowers (
  id SERIAL PRIMARY KEY,
  check_in_id INTEGER NOT NULL,
  giver_id INTEGER NOT NULL,
  recipient_id INTEGER NOT NULL,
  reading_schedule_id INTEGER NOT NULL,
  comment TEXT,
  created_at TIMESTAMP NOT NULL,
  FOREIGN KEY (check_in_id) REFERENCES check_ins(id) ON DELETE CASCADE,
  FOREIGN KEY (giver_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (recipient_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (reading_schedule_id) REFERENCES reading_schedules(id) ON DELETE CASCADE
);
```

**字段说明**:
- `check_in_id`: 打卡记录ID
- `giver_id`: 发放者ID
- `recipient_id`: 接收者ID
- `reading_schedule_id`: 阅读计划ID
- `comment`: 评语

---

## ✅ 打卡系统 (Check-in System)

### check_ins 表
打卡记录表，存储用户的每日打卡内容。

```sql
CREATE TABLE check_ins (
  id SERIAL PRIMARY KEY,
  content TEXT NOT NULL,
  word_count INTEGER,
  status INTEGER DEFAULT 0 NOT NULL,
  submitted_at TIMESTAMP,
  user_id INTEGER NOT NULL,
  reading_schedule_id INTEGER NOT NULL,
  enrollment_id INTEGER NOT NULL,
  flower_id INTEGER,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (reading_schedule_id) REFERENCES reading_schedules(id) ON DELETE CASCADE,
  FOREIGN KEY (enrollment_id) REFERENCES enrollments(id) ON DELETE CASCADE,
  FOREIGN KEY (flower_id) REFERENCES flowers(id) ON DELETE SET NULL
);
```

**字段说明**:
- `content`: 打卡内容
- `word_count`: 字数统计
- `status`: 状态 (0: 正常, 1: 补卡, 2: 缺卡)
- `submitted_at`: 提交时间
- `enrollment_id`: 报名记录ID
- `flower_id`: 关联的小红花ID

### daily_leadings 表
领读内容表，存储每日领读人发布的内容和问题。

```sql
CREATE TABLE daily_leadings (
  id SERIAL PRIMARY KEY,
  reading_suggestion TEXT NOT NULL,
  questions TEXT,
  reading_schedule_id INTEGER NOT NULL,
  leader_id INTEGER NOT NULL,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL,
  FOREIGN KEY (reading_schedule_id) REFERENCES reading_schedules(id) ON DELETE CASCADE,
  FOREIGN KEY (leader_id) REFERENCES users(id) ON DELETE CASCADE,
  UNIQUE(reading_schedule_id)
);
```

**字段说明**:
- `reading_suggestion`: 阅读建议
- `questions`: 思考问题 (JSON格式)
- `reading_schedule_id`: 阅读计划ID
- `leader_id`: 领读人ID

---

## 🔗 关系图 (Relationship Diagram)

```
Users (1) -----> (N) Posts
Users (1) -----> (N) Comments
Users (1) -----> (N) Likes
Posts (1) -----> (N) Comments
Posts (1) -----> (N) Likes

Users (1) -----> (N) ReadingEvents (as leader)
Users (N) -----> (N) ReadingEvents (through enrollments)
ReadingEvents (1) -----> (N) ReadingSchedules
ReadingSchedules (1) -----> (N) CheckIns
ReadingSchedules (1) -----> (1) DailyLeadings

Users (N) -----> (N) CheckIns (through enrollments)
CheckIns (1) -----> (1) Flowers
Users (1) -----> (N) Flowers (as giver)
Users (1) -----> (N) Flowers (as recipient)
```

---

## 📊 索引策略

### 主要索引
1. **用户表索引**
   - `wx_openid` (unique) - 微信登录查询
   - `role` - 权限查询

2. **帖子表索引**
   - `user_id` - 用户帖子查询
   - `category` - 分类筛选
   - `pinned, created_at` - 置顶排序
   - `hidden` - 隐藏状态筛选

3. **活动表索引**
   - `leader_id` - 小组长查询
   - `status` - 活动状态筛选
   - `start_date, end_date` - 时间范围查询

4. **关联表索引**
   - 外键字段自动索引
   - 复合索引用于常见查询组合

### 查询优化
1. 使用 `includes` 预加载关联数据避免N+1查询
2. 使用 `limit` 和 `offset` 实现分页
3. 使用 `where` 条件过滤减少数据量
4. 合理使用 `counter_cache` 缓存计数

---

## 🔒 数据安全

### 敏感数据处理
1. 微信OpenID和UnionID加密存储
2. 用户手机号脱敏显示
3. 定期备份重要数据
4. 数据访问日志记录

### 权限控制
1. 数据库级别的访问控制
2. 应用级别的权限验证
3. API级别的参数验证
4. 行级别的安全策略 (RLS)

---

## 📈 性能优化

### 查询优化
1. 合理使用索引，避免全表扫描
2. 分页查询减少单次数据量
3. 使用缓存减少数据库压力
4. 定期分析慢查询并优化

### 存储优化
1. JSON字段用于存储结构化数据
2. TEXT字段用于长文本内容
3. 合理设置字段长度避免浪费
4. 定期清理过期数据

---

## 🔄 数据迁移

### 版本控制
- 使用Rails Migrations管理数据库结构变更
- 每个迁移文件包含向前和回滚操作
- 生产环境迁移前必须备份数据

### 迁移策略
1. 新增字段使用默认值
2. 删除字段先确认无使用
3. 修改字段类型考虑数据兼容性
4. 大表操作分批执行避免锁表

---

## 📝 数据字典

### 枚举值定义

#### 用户角色 (users.role)
- `0`: 普通用户 (user)
- `1`: 管理员 (admin)
- `2`: 超级管理员 (root)

#### 活动状态 (reading_events.status)
- `0`: 草稿 (draft)
- `1`: 报名中 (enrolling)
- `2`: 进行中 (in_progress)
- `3`: 已完成 (completed)

#### 支付状态 (enrollments.payment_status)
- `0`: 未支付 (unpaid)
- `1`: 已支付 (paid)
- `2`: 已退款 (refunded)

#### 帖子分类 (posts.category)
- `reading`: 读书心得
- `activity`: 活动讨论
- `chat`: 闲聊区
- `help`: 求助问答

#### 打卡状态 (check_ins.status)
- `0`: 正常 (normal)
- `1`: 补卡 (makeup)
- `2`: 缺卡 (missed)

---

## 🛠️ 维护指南

### 日常维护
1. 监控数据库性能指标
2. 定期清理日志数据
3. 检查索引使用情况
4. 备份重要数据

### 故障处理
1. 数据库连接失败处理
2. 死锁检测和解决
3. 数据一致性检查
4. 性能问题诊断

---

*本文档最后更新: 2025-10-16*