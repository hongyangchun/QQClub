# QQClub API 测试指南

## 📖 概述

本指南提供 QQClub API 的完整测试方法，包括认证、论坛、活动、打卡、小红花等所有功能模块的测试用例。

## 🚀 快速开始

### 服务器信息
- **本地开发地址**: `http://localhost:3000`
- **Rails 版本**: 8.0.3
- **Ruby 版本**: 3.3.0
- **数据库**: SQLite (开发) / PostgreSQL (生产)

### 基础测试流程
```bash
# 1. 启动服务器
cd qqclub_api
bin/rails server

# 2. 在另一个终端测试
# (以下测试用例在新终端中执行)
```

---

## 🔐 认证系统测试

### 1. 模拟登录（测试用）
**用途**: 无需真实微信 code，直接创建用户并获取 token

```bash
curl -X POST http://localhost:3000/api/auth/mock_login \
  -H "Content-Type: application/json" \
  -d '{
    "nickname": "测试用户",
    "wx_openid": "test_user_001"
  }'
```

**返回示例**:
```json
{
  "token": "eyJhbGciOiJIUzI1NiJ9...",
  "user": {
    "id": 1,
    "nickname": "测试用户",
    "role": "user",
    "avatar_url": null,
    "wx_openid": "test_user_001"
  }
}
```

### 2. 获取当前用户信息
```bash
# 先保存 token
TOKEN=$(curl -s -X POST http://localhost:3000/api/auth/mock_login \
  -H "Content-Type: application/json" \
  -d '{"nickname": "DHH", "wx_openid": "test_dhh"}' | jq -r '.token')

# 使用 token 获取用户信息
curl -X GET http://localhost:3000/api/auth/me \
  -H "Authorization: Bearer $TOKEN"
```

### 3. 创建管理员用户
```bash
# 创建 Root 用户
curl -X POST http://localhost:3000/api/admin/init_root \
  -H "Content-Type: application/json" \
  -d '{
    "root": {
      "nickname": "超级管理员",
      "wx_openid": "root_user_001"
    }
  }'
```

---

## 💬 论坛系统测试

### 1. 创建帖子
```bash
curl -X POST http://localhost:3000/api/posts \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "post": {
      "title": "我的第一篇读书笔记",
      "content": "今天读了《Ruby元编程》的前三章，深深被Ruby的灵活性所震撼。元编程不仅仅是技术，更是一种思维方式。"
    }
  }'
```

### 2. 获取帖子列表
```bash
curl -X GET http://localhost:3000/api/posts
```

### 3. 获取帖子详情
```bash
# 假设帖子 ID 为 1
curl -X GET http://localhost:3000/api/posts/1
```

### 4. 更新帖子
```bash
curl -X PUT http://localhost:3000/api/posts/1 \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "post": {
      "title": "更新后的标题",
      "content": "更新后的内容，至少10个字符。"
    }
  }'
```

### 5. 置顶帖子（管理员权限）
```bash
# 需要管理员 token
ADMIN_TOKEN=$(curl -s -X POST http://localhost:3000/api/auth/mock_login \
  -H "Content-Type: application/json" \
  -d '{"nickname": "管理员", "wx_openid": "admin_user_001"}' | jq -r '.token')

curl -X POST http://localhost:3000/api/posts/1/pin \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

### 6. 隐藏帖子（管理员权限）
```bash
curl -X POST http://localhost:3000/api/posts/1/hide \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

---

## 📚 读书活动测试

### 1. 创建读书活动
```bash
curl -X POST http://localhost:3000/api/events \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "event": {
      "title": "《Ruby元编程》共读活动",
      "book_name": "Ruby元编程",
      "description": "深入学习Ruby的元编程技术，提升编程思维",
      "start_date": "2025-10-20",
      "end_date": "2025-11-10",
      "max_participants": 20,
      "enrollment_fee": "100.0",
      "leader_assignment_type": "voluntary"
    }
  }'
```

### 2. 获取活动列表
```bash
curl -X GET http://localhost:3000/api/events
```

### 3. 获取活动详情
```bash
curl -X GET http://localhost:3000/api/events/1
```

### 4. 报名参加活动
```bash
curl -X POST http://localhost:3000/api/events/1/enroll \
  -H "Authorization: Bearer $TOKEN"
```

### 5. 审批活动（管理员权限）
```bash
curl -X POST http://localhost:3000/api/events/1/approve \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

---

## ✅ 打卡系统测试

### 1. 提交打卡
```bash
# 首先获取阅读计划 ID（假设为 1）
curl -X POST http://localhost:3000/api/reading_schedules/1/check_ins \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "check_in": {
      "content": "今天学习了Ruby的class_eval和instance_eval方法。class_eval可以在类级别动态定义方法，而instance_eval则在对象级别执行。这种灵活性让Ruby能够实现很多其他语言难以做到的元编程技巧。通过今天的学习，我理解了Open Class的概念，以及如何在运行时修改类。这是Ruby元编程的基础，也是理解Rails许多神奇特性的关键。"
    }
  }'
```

### 2. 获取当日打卡列表
```bash
curl -X GET http://localhost:3000/api/reading_schedules/1/check_ins
```

### 3. 获取打卡详情
```bash
curl -X GET http://localhost:3000/api/check_ins/1
```

### 4. 更新打卡内容
```bash
curl -X PUT http://localhost:3000/api/check_ins/1 \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "check_in": {
      "content": "更新后的打卡内容，补充了一些学习心得和体会。"
    }
  }'
```

---

## 🌸 小红花系统测试

### 1. 发布领读内容
```bash
curl -X POST http://localhost:3000/api/reading_schedules/1/daily_leading \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "daily_leading": {
      "reading_suggestion": "今天我们重点学习第1-3章，理解Ruby对象模型。建议关注：1. 类与对象的关系 2. 方法的查找链 3. singleton class 的概念",
      "questions": "1. 什么是开放类（Open Class）？它有什么作用？\n2. 简述Ruby的方法查找过程。\n3. singleton class 与普通类有什么区别？"
    }
  }'
```

### 2. 送小红花
```bash
curl -X POST http://localhost:3000/api/check_ins/1/flower \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "flower": {
      "comment": "打卡内容很深入，对元编程概念理解准确！特别是对方法查找链的分析很到位。"
    }
  }'
```

### 3. 获取小红花列表
```bash
curl -X GET http://localhost:3000/api/reading_schedules/1/flowers
```

### 4. 获取用户收到的小红花
```bash
curl -X GET http://localhost:3000/api/users/1/flowers
```

---

## 👥 管理员功能测试

### 1. 获取管理面板数据
```bash
curl -X GET http://localhost:3000/api/admin/dashboard \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

### 2. 获取用户列表（Root 权限）
```bash
curl -X GET http://localhost:3000/api/admin/users \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

### 3. 提升用户为管理员
```bash
curl -X PUT http://localhost:3000/api/admin/users/2/promote_admin \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

### 4. 获取待审批活动
```bash
curl -X GET http://localhost:3000/api/admin/events/pending \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

---

## 🧪 综合测试场景

### 场景 1：完整的读书活动流程
```bash
#!/bin/bash

# 1. 创建用户（小组长）
LEADER_TOKEN=$(curl -s -X POST http://localhost:3000/api/auth/mock_login \
  -H "Content-Type: application/json" \
  -d '{"nickname": "小组长张三", "wx_openid": "leader_001"}' | jq -r '.token')

# 2. 创建活动
EVENT_ID=$(curl -s -X POST http://localhost:3000/api/events \
  -H "Authorization: Bearer $LEADER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "event": {
      "title": "Ruby元编程精读",
      "book_name": "Ruby元编程",
      "start_date": "2025-10-20",
      "end_date": "2025-10-25",
      "max_participants": 10,
      "enrollment_fee": "50.0"
    }
  }' | jq -r '.id')

echo "创建活动 ID: $EVENT_ID"

# 3. 审批活动（管理员）
ADMIN_TOKEN=$(curl -s -X POST http://localhost:3000/api/auth/mock_login \
  -H "Content-Type: application/json" \
  -d '{"nickname": "管理员", "wx_openid": "admin_001"}' | jq -r '.token')

curl -X POST http://localhost:3000/api/events/$EVENT_ID/approve \
  -H "Authorization: Bearer $ADMIN_TOKEN"

# 4. 用户报名
PARTICIPANT_TOKEN=$(curl -s -X POST http://localhost:3000/api/auth/mock_login \
  -H "Content-Type: application/json" \
  -d '{"nickname": "参与者李四", "wx_openid": "participant_001"}' | jq -r '.token')

curl -X POST http://localhost:3000/api/events/$EVENT_ID/enroll \
  -H "Authorization: Bearer $PARTICIPANT_TOKEN"

echo "活动流程测试完成！"
```

### 场景 2：权限系统测试
```bash
#!/bin/bash

# 1. 创建普通用户
USER_TOKEN=$(curl -s -X POST http://localhost:3000/api/auth/mock_login \
  -H "Content-Type: application/json" \
  -d '{"nickname": "普通用户", "wx_openid": "user_001"}' | jq -r '.token')

# 2. 尝试访问管理员接口（应该失败）
curl -X GET http://localhost:3000/api/admin/dashboard \
  -H "Authorization: Bearer $USER_TOKEN"

# 3. 尝试置顶帖子（应该失败）
curl -X POST http://localhost:3000/api/posts/1/pin \
  -H "Authorization: Bearer $USER_TOKEN"

# 4. 创建管理员用户
ADMIN_TOKEN=$(curl -s -X POST http://localhost:3000/api/auth/mock_login \
  -H "Content-Type: application/json" \
  -d '{"nickname": "管理员", "wx_openid": "admin_001"}' | jq -r '.token')

# 5. 管理员成功访问
curl -X GET http://localhost:3000/api/admin/dashboard \
  -H "Authorization: Bearer $ADMIN_TOKEN"

echo "权限系统测试完成！"
```

---

## 🛠️ 使用 Postman 测试

### 导入测试集合

1. 下载 Postman Collection JSON：
```json
{
  "info": {
    "name": "QQClub API",
    "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
  },
  "variable": [
    {
      "key": "baseUrl",
      "value": "http://localhost:3000"
    },
    {
      "key": "token",
      "value": ""
    },
    {
      "key": "adminToken",
      "value": ""
    }
  ]
}
```

2. 在 Postman 中导入并添加以下请求：

#### 认证请求
- **Mock Login**: POST `{{baseUrl}}/api/auth/mock_login`
- **Get Profile**: GET `{{baseUrl}}/api/auth/me`

#### 论坛请求
- **Create Post**: POST `{{baseUrl}}/api/posts`
- **List Posts**: GET `{{baseUrl}}/api/posts`
- **Pin Post**: POST `{{baseUrl}}/api/posts/:id/pin`

#### 活动请求
- **Create Event**: POST `{{baseUrl}}/api/events`
- **List Events**: GET `{{baseUrl}}/api/events`
- **Enroll Event**: POST `{{baseUrl}}/api/events/:id/enroll`

---

## 🔍 数据库操作

### Rails Console 操作
```bash
# 启动控制台
bin/rails console

# 查看用户
User.all
User.find_by(role: 'root')

# 查看活动
ReadingEvent.all
ReadingEvent.where(status: 'pending')

# 查看帖子
Post.all
Post.where(pinned: true)

# 重置数据库
User.delete_all
ReadingEvent.delete_all
Post.delete_all
```

### 数据库重置
```bash
# 完全重置
bin/rails db:reset

# 仅重置数据
bin/rails db:seed:replant
```

---

## ⚠️ 错误处理

### 常见错误响应

1. **401 Unauthorized** - Token 无效或未提供
```bash
{"error":"需要管理员权限"}
```

2. **403 Forbidden** - 权限不足
```bash
{"error":"无权限编辑此帖子"}
```

3. **422 Unprocessable Entity** - 数据验证失败
```bash
{"errors":["标题不能为空", "内容太短（最少10个字符）"]}
```

4. **404 Not Found** - 资源不存在
```bash
{"error":"帖子已被隐藏"}
```

### 调试技巧

1. **查看日志**:
```bash
tail -f log/development.log
```

2. **检查数据库状态**:
```bash
bin/rails db:migrate:status
```

3. **验证路由**:
```bash
bin/rails routes | grep api
```

---

## 🚀 性能测试

### 简单的压力测试
```bash
# 安装 ab 工具 (Apache Bench)
# macOS: brew install apache2

# 测试 API 响应时间
ab -n 100 -c 10 http://localhost:3000/api/posts
```

### 查询优化检查
```bash
# 安装 bullet gem 进行 N+1 查询检测
# 在 Gemfile 中添加：gem 'bullet', group: :development
# 重启服务器查看日志中的 N+1 警告
```

---

## 📝 测试清单

- [ ] 认证系统（登录、获取用户信息）
- [ ] 论坛功能（CRUD、置顶、隐藏）
- [ ] 活动管理（创建、报名、审批）
- [ ] 打卡系统（提交、查看、更新）
- [ ] 小红花系统（发放、查看统计）
- [ ] 权限系统（角色验证、权限控制）
- [ ] 管理员功能（用户管理、数据统计）
- [ ] 错误处理（各种边界情况）
- [ ] 性能测试（响应时间、并发）

---

**最后更新**: 2025-10-15
**适用版本**: QQClub v1.2 (3层权限架构)