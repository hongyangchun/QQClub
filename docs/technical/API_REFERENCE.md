# QQClub API 接口文档

## 📋 文档说明

**定位**: QQClub 后端 API 的完整接口规格说明，供前端开发者使用的接口参考
**目标读者**: 前端开发者、API 集成开发者、测试工程师
**文档深度**: 详细的 API 端点说明，包含请求/响应格式、认证方式、错误处理

---

## 🔗 基础信息

### API 基础配置

- **Base URL**: `https://api.qqclub.com` (生产环境) / `http://localhost:3000` (开发环境)
- **协议**: HTTPS (生产环境) / HTTP (开发环境)
- **数据格式**: JSON
- **字符编码**: UTF-8

### 认证方式

所有需要认证的 API 请求都需要在 Header 中包含 JWT Token：

```
Authorization: Bearer <your_jwt_token>
```

### 响应格式规范

#### 成功响应格式
```json
{
  "message": "操作成功",
  "data": {
    // 具体数据内容
  }
}
```

#### 错误响应格式
```json
{
  "error": "错误描述",
  "errors": [
    // 详细错误信息数组
  ]
}
```

#### 分页响应格式
```json
{
  "data": [
    // 数据列表
  ],
  "pagination": {
    "current_page": 1,
    "total_pages": 10,
    "total_count": 100,
    "per_page": 10
  }
}
```

### HTTP 状态码

| 状态码 | 说明 |
|--------|------|
| 200 | 成功 |
| 201 | 创建成功 |
| 400 | 请求参数错误 |
| 401 | 未认证 |
| 403 | 权限不足 |
| 404 | 资源不存在 |
| 422 | 数据验证失败 |
| 500 | 服务器内部错误 |

---

## 🔐 认证接口

### 微信模拟登录
```http
POST /api/auth/mock_login
```

**请求体**:
```json
{
  "openid": "test_user_001",
  "nickname": "测试用户",
  "avatar_url": "https://example.com/avatar.jpg"
}
```

**响应**:
```json
{
  "message": "登录成功",
  "data": {
    "token": "eyJhbGciOiJIUzI1NiJ9...",
    "user": {
      "id": 1,
      "openid": "test_user_001",
      "nickname": "测试用户",
      "avatar_url": "https://example.com/avatar.jpg",
      "role": "user",
      "created_at": "2025-10-16T10:00:00Z"
    }
  }
}
```

### 获取当前用户信息
```http
GET /api/auth/me
Authorization: Bearer <token>
```

**响应**:
```json
{
  "message": "获取成功",
  "data": {
    "id": 1,
    "openid": "test_user_001",
    "nickname": "测试用户",
    "avatar_url": "https://example.com/avatar.jpg",
      "role": "user",
    "created_at": "2025-10-16T10:00:00Z",
    "updated_at": "2025-10-16T10:00:00Z"
  }
}
```

### 更新用户资料
```http
PUT /api/auth/profile
Authorization: Bearer <token>
```

**请求体**:
```json
{
  "nickname": "新昵称",
  "avatar_url": "https://example.com/new_avatar.jpg"
}
```

---

## 💬 论坛接口

### 获取帖子列表
```http
GET /api/posts?page=1&per_page=10&sort=created_at&order=desc
```

**查询参数**:
- `page`: 页码 (默认: 1)
- `per_page`: 每页数量 (默认: 10, 最大: 50)
- `sort`: 排序字段 (created_at, updated_at, likes_count)
- `order`: 排序方向 (asc, desc)

**响应**:
```json
{
  "data": [
    {
      "id": 1,
      "title": "帖子标题",
      "content": "帖子内容摘要...",
      "user": {
        "id": 1,
        "nickname": "用户昵称",
        "avatar_url": "https://example.com/avatar.jpg"
      },
      "pinned": false,
      "hidden": false,
      "likes_count": 5,
      "comments_count": 3,
      "created_at": "2025-10-16T10:00:00Z",
      "updated_at": "2025-10-16T10:00:00Z"
    }
  ],
  "pagination": {
    "current_page": 1,
    "total_pages": 5,
    "total_count": 45,
    "per_page": 10
  }
}
```

### 获取帖子详情
```http
GET /api/posts/:id
```

**响应**:
```json
{
  "message": "获取成功",
  "data": {
    "id": 1,
    "title": "帖子标题",
    "content": "帖子完整内容...",
    "user": {
      "id": 1,
      "nickname": "用户昵称",
      "avatar_url": "https://example.com/avatar.jpg"
    },
    "pinned": false,
    "hidden": false,
    "likes_count": 5,
    "comments_count": 3,
    "comments": [
      {
        "id": 1,
        "content": "评论内容",
        "user": {
          "id": 2,
          "nickname": "评论者",
          "avatar_url": "https://example.com/avatar2.jpg"
        },
        "created_at": "2025-10-16T11:00:00Z"
      }
    ],
    "created_at": "2025-10-16T10:00:00Z",
    "updated_at": "2025-10-16T10:00:00Z"
  }
}
```

### 创建帖子
```http
POST /api/posts
Authorization: Bearer <token>
```

**请求体**:
```json
{
  "title": "帖子标题",
  "content": "帖子内容，至少10个字符"
}
```

**响应**:
```json
{
  "message": "创建成功",
  "data": {
    "id": 1,
    "title": "帖子标题",
    "content": "帖子内容...",
    "user": {
      "id": 1,
      "nickname": "用户昵称",
      "avatar_url": "https://example.com/avatar.jpg"
    },
    "pinned": false,
    "hidden": false,
    "likes_count": 0,
    "comments_count": 0,
    "created_at": "2025-10-16T10:00:00Z",
    "updated_at": "2025-10-16T10:00:00Z"
  }
}
```

### 更新帖子
```http
PUT /api/posts/:id
Authorization: Bearer <token>
```

**请求体**:
```json
{
  "title": "更新的标题",
  "content": "更新的内容"
}
```

### 删除帖子
```http
DELETE /api/posts/:id
Authorization: Bearer <token>
```

### 置顶帖子 (管理员)
```http
POST /api/posts/:id/pin
Authorization: Bearer <admin_token>
```

### 隐藏帖子 (管理员)
```http
POST /api/posts/:id/hide
Authorization: Bearer <admin_token>
```

---

## 📚 活动接口

### 获取活动列表
```http
GET /api/events?page=1&per_page=10&status=all&sort=created_at&order=desc
```

**查询参数**:
- `page`: 页码
- `per_page`: 每页数量
- `status`: 活动状态 (all, draft, enrolling, in_progress, completed)
- `sort`: 排序字段 (created_at, start_date, end_date)
- `order`: 排序方向

**响应**:
```json
{
  "data": [
    {
      "id": 1,
      "title": "《三体》读书会",
      "book_name": "三体",
      "book_cover_url": "https://example.com/book_cover.jpg",
      "description": "一起探索三体世界...",
      "start_date": "2025-11-01",
      "end_date": "2025-11-15",
      "max_participants": 30,
      "current_participants": 15,
      "enrollment_fee": "100.0",
      "status": "enrolling",
      "approval_status": "approved",
      "leader": {
        "id": 1,
        "nickname": "小组长",
        "avatar_url": "https://example.com/avatar.jpg"
      },
      "created_at": "2025-10-16T10:00:00Z",
      "updated_at": "2025-10-16T10:00:00Z"
    }
  ],
  "pagination": {
    "current_page": 1,
    "total_pages": 3,
    "total_count": 25,
    "per_page": 10
  }
}
```

### 获取活动详情
```http
GET /api/events/:id
```

**响应**:
```json
{
  "message": "获取成功",
  "data": {
    "id": 1,
    "title": "《三体》读书会",
    "book_name": "三体",
    "book_cover_url": "https://example.com/book_cover.jpg",
    "description": "一起探索三体世界...",
    "start_date": "2025-11-01",
    "end_date": "2025-11-15",
    "max_participants": 30,
    "current_participants": 15,
    "enrollment_fee": "100.0",
    "status": "enrolling",
    "approval_status": "approved",
    "leader": {
      "id": 1,
      "nickname": "小组长",
      "avatar_url": "https://example.com/avatar.jpg"
    },
    "schedules": [
      {
        "id": 1,
        "day_number": 1,
        "date": "2025-11-01",
        "reading_progress": "第1-2章",
        "daily_leader": {
          "id": 2,
          "nickname": "领读人",
          "avatar_url": "https://example.com/avatar2.jpg"
        }
      }
    ],
    "enrollment_status": null,
    "created_at": "2025-10-16T10:00:00Z",
    "updated_at": "2025-10-16T10:00:00Z"
  }
}
```

### 创建活动
```http
POST /api/events
Authorization: Bearer <token>
```

**请求体**:
```json
{
  "title": "《三体》读书会",
  "book_name": "三体",
  "book_cover_url": "https://example.com/book_cover.jpg",
  "description": "一起探索三体世界...",
  "start_date": "2025-11-01",
  "end_date": "2025-11-15",
  "max_participants": 30,
  "enrollment_fee": "100.0",
  "leader_assignment_type": "voluntary"
}
```

### 报名参加活动
```http
POST /api/events/:id/enroll
Authorization: Bearer <token>
```

**请求体**:
```json
{
  "payment_method": "wechat_pay"
}
```

**响应**:
```json
{
  "message": "报名成功",
  "data": {
    "id": 1,
    "user_id": 1,
    "reading_event_id": 1,
    "payment_status": "paid",
    "role": "participant",
    "paid_amount": "100.0",
    "created_at": "2025-10-16T10:00:00Z"
  }
}
```

### 获取活动参与者列表
```http
GET /api/events/:id/participants
Authorization: Bearer <token>
```

**响应**:
```json
{
  "message": "获取成功",
  "data": [
    {
      "id": 1,
      "user": {
        "id": 1,
        "nickname": "参与者",
        "avatar_url": "https://example.com/avatar.jpg"
      },
      "role": "participant",
      "payment_status": "paid",
      "enrollment_date": "2025-10-16T10:00:00Z",
      "completion_rate": 0.0,
      "flowers_count": 0
    }
  ]
}
```

### 审批活动 (管理员)
```http
POST /api/events/:id/approve
Authorization: Bearer <admin_token>
```

### 拒绝活动 (管理员)
```http
POST /api/events/:id/reject
Authorization: Bearer <admin_token>
```

**请求体**:
```json
{
  "reason": "活动内容不符合规范"
}
```

---

## 📖 阅读计划接口

### 获取活动阅读计划
```http
GET /api/events/:id/schedules
Authorization: Bearer <token>
```

**响应**:
```json
{
  "message": "获取成功",
  "data": [
    {
      "id": 1,
      "day_number": 1,
      "date": "2025-11-01",
      "reading_progress": "第1-2章",
      "daily_leader": {
        "id": 2,
        "nickname": "领读人",
        "avatar_url": "https://example.com/avatar2.jpg"
      },
      "daily_leading": {
        "id": 1,
        "reading_suggestion": "建议重点理解...",
        "questions": ["问题1", "问题2", "问题3"]
      },
      "check_ins_count": 5,
      "created_at": "2025-10-16T10:00:00Z"
    }
  ]
}
```

### 创建阅读计划 (小组长)
```http
POST /api/events/:id/schedules
Authorization: Bearer <leader_token>
```

**请求体**:
```json
{
  "schedules": [
    {
      "day_number": 1,
      "date": "2025-11-01",
      "reading_progress": "第1-2章"
    }
  ]
}
```

### 获取领读内容
```http
GET /api/events/:event_id/schedules/:schedule_id/daily_leading
Authorization: Bearer <token>
```

**响应**:
```json
{
  "message": "获取成功",
  "data": {
    "id": 1,
    "reading_suggestion": "建议重点理解三体世界的物理法则...",
    "questions": [
      "三体文明面临的根本问题是什么？",
      "黑暗森林法则的核心逻辑是什么？",
      "如果你是叶文洁，你会做出同样的选择吗？"
    ],
    "leader": {
      "id": 2,
      "nickname": "领读人",
      "avatar_url": "https://example.com/avatar2.jpg"
    },
    "created_at": "2025-10-16T10:00:00Z",
    "updated_at": "2025-10-16T10:00:00Z"
  }
}
```

### 创建领读内容 (领读人)
```http
POST /api/events/:event_id/schedules/:schedule_id/daily_leading
Authorization: Bearer <leader_token>
```

**请求体**:
```json
{
  "reading_suggestion": "建议重点理解三体世界的物理法则...",
  "questions": [
    "三体文明面临的根本问题是什么？",
    "黑暗森林法则的核心逻辑是什么？"
  ]
}
```

---

## ✅ 打卡接口

### 提交打卡
```http
POST /api/reading_events/:event_id/schedules/:schedule_id/check_ins
Authorization: Bearer <token>
```

**请求体**:
```json
{
  "content": "今天读了第1-2章，深深被三体世界的设定震撼了..."
}
```

**响应**:
```json
{
  "message": "打卡成功",
  "data": {
    "id": 1,
    "content": "今天读了第1-2章，深深被三体世界的设定震撼了...",
    "word_count": 156,
    "status": "normal",
    "submitted_at": "2025-10-16T10:00:00Z",
    "user": {
      "id": 1,
      "nickname": "用户昵称",
      "avatar_url": "https://example.com/avatar.jpg"
    },
    "has_flower": false
  }
}
```

### 获取当日打卡列表
```http
GET /api/reading_events/:event_id/schedules/:schedule_id/check_ins
Authorization: Bearer <token>
```

**响应**:
```json
{
  "message": "获取成功",
  "data": [
    {
      "id": 1,
      "content": "今天读了第1-2章...",
      "word_count": 156,
      "status": "normal",
      "submitted_at": "2025-10-16T10:00:00Z",
      "user": {
        "id": 1,
        "nickname": "用户昵称",
        "avatar_url": "https://example.com/avatar.jpg"
      },
      "has_flower": true,
      "flower": {
        "id": 1,
        "comment": "读得很认真，思考深入！",
        "giver": {
          "id": 2,
          "nickname": "领读人",
          "avatar_url": "https://example.com/avatar2.jpg"
        }
      }
    }
  ]
}
```

### 获取打卡详情
```http
GET /api/check_ins/:id
Authorization: Bearer <token>
```

### 更新打卡 (补卡)
```http
PUT /api/check_ins/:id
Authorization: Bearer <token>
```

**请求体**:
```json
{
  "content": "补卡内容：今天读了第1-2章..."
}
```

---

## 🌸 小红花接口

### 发放小红花 (领读人)
```http
POST /api/check_ins/:id/flower
Authorization: Bearer <leader_token>
```

**请求体**:
```json
{
  "comment": "读得很认真，思考深入！"
}
```

**响应**:
```json
{
  "message": "小红花发放成功",
  "data": {
    "id": 1,
    "check_in_id": 1,
    "giver_id": 2,
    "recipient_id": 1,
    "reading_schedule_id": 1,
    "comment": "读得很认真，思考深入！",
    "created_at": "2025-10-16T10:00:00Z"
  }
}
```

### 撤销小红花 (领读人)
```http
DELETE /api/flowers/:id
Authorization: Bearer <leader_token>
```

### 获取活动小红花排行榜
```http
GET /api/events/:id/flower_ranking
Authorization: Bearer <token>
```

**响应**:
```json
{
  "message": "获取成功",
  "data": [
    {
      "user": {
        "id": 1,
        "nickname": "用户昵称",
        "avatar_url": "https://example.com/avatar.jpg"
      },
      "flowers_count": 5,
      "check_ins_count": 10,
      "completion_rate": 80.0
    }
  ]
}
```

---

## 🛠️ 管理员接口

### 获取管理面板数据
```http
GET /api/admin/dashboard
Authorization: Bearer <admin_token>
```

**响应**:
```json
{
  "message": "获取成功",
  "data": {
    "stats": {
      "total_users": 156,
      "total_events": 12,
      "total_posts": 89,
      "pending_events": 3
    },
    "recent_activities": [
      {
        "type": "event_created",
        "description": "新活动《三体》读书会",
        "user": "用户A",
        "created_at": "2025-10-16T10:00:00Z"
      }
    ]
  }
}
```

### 获取用户列表
```http
GET /api/admin/users?page=1&per_page=20&role=all&search=
Authorization: Bearer <admin_token>
```

**查询参数**:
- `page`: 页码
- `per_page`: 每页数量
- `role`: 用户角色 (all, user, admin, root)
- `search`: 搜索关键词 (昵称)

### 提升用户为管理员
```http
PUT /api/admin/users/:id/promote_admin
Authorization: Bearer <root_token>
```

### 降级用户
```http
PUT /api/admin/users/:id/demote
Authorization: Bearer <admin_token>
```

### 获取待审批活动
```http
GET /api/admin/events/pending
Authorization: Bearer <admin_token>
```

### 初始化 Root 用户
```http
POST /api/admin/init_root
Authorization: Bearer <token>
```

---

## 📊 统计接口

### 获取活动统计
```http
GET /api/events/:id/summary
Authorization: Bearer <token>
```

**响应**:
```json
{
  "message": "获取成功",
  "data": {
    "event_id": 1,
    "total_participants": 15,
    "completion_stats": [
      {
        "user_id": 1,
        "nickname": "用户昵称",
        "completion_rate": 80.0,
        "total_check_ins": 12,
        "flowers_count": 3
      }
    ],
    "flower_ranking": [
      {
        "user_id": 1,
        "nickname": "用户昵称",
        "flowers_count": 3
      }
    ],
    "refund_calculations": [
      {
        "user_id": 1,
        "refund_amount": "80.0"
      }
    ]
  }
}
```

### 活动结算 (小组长)
```http
POST /api/events/:id/finalize
Authorization: Bearer <leader_token>
```

---

## ❌ 错误处理

### 常见错误响应

#### 400 Bad Request
```json
{
  "error": "请求参数错误",
  "errors": [
    "标题不能为空",
    "内容至少需要10个字符"
  ]
}
```

#### 401 Unauthorized
```json
{
  "error": "未认证",
  "errors": [
    "请先登录"
  ]
}
```

#### 403 Forbidden
```json
{
  "error": "权限不足",
  "errors": [
    "您没有权限执行此操作"
  ]
}
```

#### 404 Not Found
```json
{
  "error": "资源不存在",
  "errors": [
    "帖子不存在"
  ]
}
```

#### 422 Unprocessable Entity
```json
{
  "error": "数据验证失败",
  "errors": [
    "活动结束时间不能早于开始时间",
    "报名人数不能超过最大限制"
  ]
}
```

#### 500 Internal Server Error
```json
{
  "error": "服务器内部错误",
  "errors": [
    "服务器暂时无法处理请求，请稍后重试"
  ]
}
```

### 错误码说明

| 错误码 | 说明 | 解决方案 |
|--------|------|----------|
| AUTH_001 | Token 无效 | 重新登录获取新 Token |
| AUTH_002 | Token 过期 | 重新登录获取新 Token |
| PERM_001 | 权限不足 | 联系管理员或检查用户角色 |
| VAL_001 | 参数验证失败 | 检查请求参数格式和内容 |
| RES_001 | 资源不存在 | 检查资源 ID 是否正确 |
| SYS_001 | 系统错误 | 稍后重试或联系技术支持 |

---

## 🔄 API 版本

### 版本控制
- 当前版本: v1.0.0
- 版本策略: 语义化版本控制
- 向后兼容: 保证同一主版本内的向后兼容

### 版本更新通知
- 重大更新会提前30天通知
- 废弃接口会提供过渡期
- 新接口会标注推荐使用

---

## 📞 技术支持

如有 API 使用问题，请联系：
- **技术文档**: [技术实现细节文档](./TECHNICAL_DESIGN.md)
- **权限指南**: [权限系统使用指南](./PERMISSIONS_GUIDE.md)
- **测试指南**: [API 测试指南](./TESTING_GUIDE.md)

---

*本文档最后更新: 2025-10-16*