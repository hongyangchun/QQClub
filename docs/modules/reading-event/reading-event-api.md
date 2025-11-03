# QQClub 共读活动模块 - API设计

## 📋 文档说明

**目标读者**: 前端开发者、API集成开发者、测试工程师
**文档内容**: 完整的API接口规格、请求/响应格式、错误处理

---

## 🔗 API基础信息

### 基础配置
- **Base URL**: `https://api.qqclub.com` (生产环境) / `http://localhost:3000` (开发环境)
- **协议**: HTTPS (生产环境) / HTTP (开发环境)
- **数据格式**: JSON
- **字符编码**: UTF-8

### 认证方式
所有需要认证的API请求都需要在Header中包含JWT Token：
```
Authorization: Bearer <your_jwt_token>
```

### 响应格式规范

#### 成功响应格式
```json
{
  "success": true,
  "message": "操作成功",
  "data": {
    // 具体数据内容
  }
}
```

#### 错误响应格式
```json
{
  "success": false,
  "error": "错误描述",
  "errors": [
    // 详细错误信息数组
  ]
}
```

#### 列表响应格式
```json
{
  "success": true,
  "message": "获取成功",
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

---

## 📚 活动管理API

### 1. 获取活动列表
```http
GET /api/reading_events
Authorization: Bearer <token>
```

**查询参数**:
- `page`: 页码 (默认: 1)
- `per_page`: 每页数量 (默认: 10, 最大: 50)
- `status`: 状态筛选 (draft, enrolling, in_progress, completed)
- `activity_mode`: 活动模式筛选 (note_checkin, free_discussion, video_conference, offline_meeting)
- `fee_type`: 费用类型筛选 (free, deposit, paid)
- `keyword`: 搜索关键词 (搜索标题和书籍名称)

**响应**:
```json
{
  "success": true,
  "message": "获取成功",
  "data": [
    {
      "id": 1,
      "title": "《三体》读书会",
      "book_name": "三体",
      "book_cover_url": "https://example.com/cover.jpg",
      "description": "一起探索三体世界的奥秘...",
      "activity_mode": "note_checkin",
      "activity_mode_name": "笔记打卡",
      "fee_type": "deposit",
      "fee_amount": 100.0,
      "status": "enrolling",
      "status_name": "报名中",
      "start_date": "2025-11-01",
      "end_date": "2025-11-15",
      "current_participants": 15,
      "max_participants": 25,
      "leader": {
        "id": 1,
        "nickname": "张三",
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

### 2. 获取活动详情
```http
GET /api/reading_events/:id
Authorization: Bearer <token>
```

**响应**:
```json
{
  "success": true,
  "message": "获取成功",
  "data": {
    "id": 1,
    "title": "《三体》读书会",
    "book_name": "三体",
    "book_cover_url": "https://example.com/cover.jpg",
    "description": "一起探索三体世界的奥秘...",
    "activity_mode": "note_checkin",
    "activity_mode_name": "笔记打卡",
    "weekend_rest": false,
    "completion_standard": 80,
    "fee_type": "deposit",
    "fee_amount": 100.0,
    "leader_reward_percentage": 20.0,
    "status": "enrolling",
    "start_date": "2025-11-01",
    "end_date": "2025-11-15",
    "current_participants": 15,
    "max_participants": 25,
    "leader": {
      "id": 1,
      "nickname": "张三",
      "avatar_url": "https://example.com/avatar.jpg"
    },
    "reading_schedules": [
      {
        "id": 1,
        "day_number": 1,
        "date": "2025-11-01",
        "reading_progress": "第1-2章",
        "daily_leader": {
          "id": 2,
          "nickname": "李四",
          "avatar_url": "https://example.com/avatar2.jpg"
        }
      }
    ],
    "user_enrollment": {
      "is_participating": true,
      "is_observer": false,
      "enrollment_date": "2025-10-16T10:30:00Z",
      "completion_rate": 85.5,
      "check_ins_count": 12,
      "flowers_received_count": 3
    },
    "created_at": "2025-10-16T10:00:00Z",
    "updated_at": "2025-10-16T10:00:00Z"
  }
}
```

### 3. 创建活动
```http
POST /api/reading_events
Authorization: Bearer <token>
Content-Type: application/json
```

**请求体**:
```json
{
  "reading_event": {
    "title": "《三体》读书会",
    "book_name": "三体",
    "book_cover_url": "https://example.com/cover.jpg",
    "description": "一起探索三体世界的奥秘...",
    "activity_mode": "note_checkin",
    "weekend_rest": false,
    "completion_standard": 80,
    "leader_assignment_type": "voluntary",
    "fee_type": "deposit",
    "fee_amount": 100.0,
    "max_participants": 25,
    "start_date": "2025-11-01",
    "end_date": "2025-11-15",
    "reading_schedules": [
      {
        "day_number": 1,
        "date": "2025-11-01",
        "reading_progress": "第1-2章"
      }
    ]
  }
}
```

**响应**:
```json
{
  "success": true,
  "message": "活动创建成功",
  "data": {
    "id": 123,
    "title": "《三体》读书会",
    "status": "draft",
    "enrollment_url": "/events/123/enroll"
  }
}
```

### 4. 更新活动
```http
PUT /api/reading_events/:id
Authorization: Bearer <token>
Content-Type: application/json
```

**请求体**:
```json
{
  "reading_event": {
    "title": "更新后的标题",
    "description": "更新后的描述",
    "max_participants": 30
  }
}
```

### 5. 删除活动
```http
DELETE /api/reading_events/:id
Authorization: Bearer <token>
```

**响应**: HTTP 204 No Content

---

## 👤 报名管理API

### 1. 报名参与活动
```http
POST /api/reading_events/:id/enroll
Authorization: Bearer <token>
Content-Type: application/json
```

**请求体**:
```json
{
  "agreement_terms": true
}
```

**响应**:
```json
{
  "success": true,
  "message": "报名成功",
  "data": {
    "enrollment_id": 789,
    "status": "enrolled",
    "enrollment_date": "2025-10-25T10:30:00Z",
    "fee_required": true,
    "fee_amount": 100.0,
    "fee_type": "deposit",
    "fee_description": "20%小组长报酬，80%押金池"
  }
}
```

### 2. 围观活动
```http
POST /api/reading_events/:id/observe
Authorization: Bearer <token>
Content-Type: application/json
```

**响应**:
```json
{
  "success": true,
  "message": "围观成功",
  "data": {
    "enrollment_id": 790,
    "status": "observing",
    "enrollment_date": "2025-10-25T10:30:00Z",
    "can_comment": true,
    "can_check_in": false
  }
}
```

### 3. 取消报名
```http
DELETE /api/reading_events/:id/enroll
Authorization: Bearer <token>
```

### 4. 获取参与者列表
```http
GET /api/reading_events/:id/participants
Authorization: Bearer <token>
```

**响应**:
```json
{
  "success": true,
  "message": "获取成功",
  "data": [
    {
      "user_id": 1,
      "nickname": "张三",
      "avatar_url": "https://example.com/avatar1.jpg",
      "enrollment_type": "participant",
      "enrollment_date": "2025-10-25T10:30:00Z",
      "completion_rate": 85.5,
      "check_ins_count": 12,
      "leader_days_count": 2,
      "flowers_received": 5,
      "current_leader": true
    }
  ],
  "pagination": {
    "current_page": 1,
    "total_pages": 3,
    "total_count": 28,
    "per_page": 10
  }
}
```

---

## 📖 领读计划API

### 1. 获取阅读计划
```http
GET /api/reading_events/:id/schedules
Authorization: Bearer <token>
```

**响应**:
```json
{
  "success": true,
  "message": "获取成功",
  "data": [
    {
      "id": 1,
      "day_number": 1,
      "date": "2025-11-01",
      "reading_progress": "第1-2章",
      "daily_leader": {
        "id": 2,
        "nickname": "李四",
        "avatar_url": "https://example.com/avatar2.jpg"
      },
      "daily_leading": {
        "id": 1,
        "reading_suggestion": "建议重点理解三体世界的物理法则...",
        "questions": [
          "三体文明面临的根本问题是什么？",
          "黑暗森林法则的核心逻辑是什么？"
        ],
        "created_at": "2025-10-31T22:00:00Z"
      },
      "check_ins_count": 5,
      "flowers_count": 2,
      "user_check_in": {
        "has_checked_in": true,
        "check_in_content": "今天读了第1-2章...",
        "check_in_time": "2025-11-01T20:30:00Z",
        "received_flower": true
      }
    }
  ]
}
```

### 2. 获取领读内容
```http
GET /api/reading_events/:event_id/schedules/:schedule_id/daily_leading
Authorization: Bearer <token>
```

**响应**:
```json
{
  "success": true,
  "message": "获取成功",
  "data": {
    "id": 1,
    "reading_suggestion": "建议重点理解三体世界的物理法则...",
    "questions": [
      "三体文明面临的根本问题是什么？",
      "黑暗森林法则的核心逻辑是什么？"
    ],
    "leader": {
      "id": 2,
      "nickname": "李四",
      "avatar_url": "https://example.com/avatar2.jpg"
    },
    "schedule": {
      "id": 1,
      "day_number": 1,
      "date": "2025-11-01",
      "reading_progress": "第1-2章"
    },
    "created_at": "2025-10-31T22:00:00Z",
    "updated_at": "2025-10-31T22:00:00Z"
  }
}
```

### 3. 创建领读内容
```http
POST /api/reading_events/:event_id/schedules/:schedule_id/daily_leading
Authorization: Bearer <token>
Content-Type: application/json
```

**请求体**:
```json
{
  "daily_leading": {
    "reading_suggestion": "建议重点理解三体世界的物理法则...",
    "questions": [
      "三体文明面临的根本问题是什么？",
      "黑暗森林法则的核心逻辑是什么？"
    ]
  }
}
```

---

## ✅ 打卡管理API

### 1. 提交打卡
```http
POST /api/reading_events/:event_id/schedules/:schedule_id/check_ins
Authorization: Bearer <token>
Content-Type: application/json
```

**请求体**:
```json
{
  "check_in": {
    "content": "今天读了第1-2章，深深被三体世界的设定震撼了..."
  }
}
```

**响应**:
```json
{
  "success": true,
  "message": "打卡成功",
  "data": {
    "id": 1,
    "content": "今天读了第1-2章，深深被三体世界的设定震撼了...",
    "word_count": 156,
    "status": "normal",
    "submitted_at": "2025-11-01T20:30:00Z",
    "user": {
      "id": 1,
      "nickname": "张三",
      "avatar_url": "https://example.com/avatar.jpg"
    },
    "has_flower": false
  }
}
```

### 2. 获取当日打卡列表
```http
GET /api/reading_events/:event_id/schedules/:schedule_id/check_ins
Authorization: Bearer <token>
```

**响应**:
```json
{
  "success": true,
  "message": "获取成功",
  "data": [
    {
      "id": 1,
      "content": "今天读了第1-2章，深深被三体世界的设定震撼了...",
      "word_count": 156,
      "status": "normal",
      "submitted_at": "2025-11-01T20:30:00Z",
      "user": {
        "id": 1,
        "nickname": "张三",
        "avatar_url": "https://example.com/avatar.jpg"
      },
      "has_flower": true,
      "flower": {
        "id": 1,
        "comment": "读得很认真，思考深入！",
        "giver": {
          "id": 2,
          "nickname": "李四",
          "avatar_url": "https://example.com/avatar2.jpg"
        }
      }
    }
  ]
}
```

### 3. 更新打卡
```http
PUT /api/check_ins/:id
Authorization: Bearer <token>
Content-Type: application/json
```

**请求体**:
```json
{
  "check_in": {
    "content": "更新后的打卡内容：今天读了第1-2章..."
  }
}
```

### 4. 删除打卡
```http
DELETE /api/check_ins/:id
Authorization: Bearer <token>
```

**响应**: HTTP 204 No Content

---

## 🌸 小红花API

### 1. 发放小红花
```http
POST /api/check_ins/:id/flower
Authorization: Bearer <token>
Content-Type: application/json
```

**请求体**:
```json
{
  "flower": {
    "comment": "读得很认真，思考深入！"
  }
}
```

**响应**:
```json
{
  "success": true,
  "message": "小红花发放成功",
  "data": {
    "id": 1,
    "check_in_id": 1,
    "comment": "读得很认真，思考深入！",
    "giver": {
      "id": 2,
      "nickname": "李四",
      "avatar_url": "https://example.com/avatar2.jpg"
    },
    "recipient": {
      "id": 1,
      "nickname": "张三",
      "avatar_url": "https://example.com/avatar.jpg"
    },
    "created_at": "2025-11-02T10:00:00Z"
  }
}
```

### 2. 撤销小红花
```http
DELETE /api/flowers/:id
Authorization: Bearer <token>
```

### 3. 获取小红花排行榜
```http
GET /api/reading_events/:id/flower_ranking
Authorization: Bearer <token>
```

**响应**:
```json
{
  "success": true,
  "message": "获取成功",
  "data": {
    "event_id": 123,
    "total_participants": 25,
    "ranking": [
      {
        "rank": 1,
        "user_id": 1,
        "nickname": "张三",
        "avatar_url": "https://example.com/avatar1.jpg",
        "flowers_count": 8,
        "check_ins_count": 14,
        "completion_rate": 100.0
      },
      {
        "rank": 2,
        "user_id": 2,
        "nickname": "李四",
        "avatar_url": "https://example.com/avatar2.jpg",
        "flowers_count": 5,
        "check_ins_count": 12,
        "completion_rate": 92.9
      }
    ],
    "user_rank": {
      "rank": 5,
      "flowers_count": 2,
      "check_ins_count": 10,
      "completion_rate": 78.6
    }
  }
}
```

---

## 📊 统计API

### 1. 获取活动统计
```http
GET /api/reading_events/:id/statistics
Authorization: Bearer <token>
```

**响应**:
```json
{
  "success": true,
  "message": "获取成功",
  "data": {
    "overview": {
      "total_participants": 25,
      "active_participants": 23,
      "average_completion_rate": 85.2,
      "days_elapsed": 8,
      "total_days": 15,
      "total_check_ins": 312,
      "total_flowers": 156
    },
    "participation_stats": {
      "completed": 21,
      "in_progress": 2,
      "not_started": 2
    },
    "activity_breakdown": {
      "note_checkin": 20,
      "free_discussion": 3,
      "video_conference": 2,
      "offline_meeting": 0
    },
    "fee_stats": {
      "total_collected": 2500.0,
      "total_refunded": 1600.0,
      "total_leader_reward": 500.0,
      "forfeited_amount": 400.0
    }
  }
}
```

### 2. 获取完成率排行榜
```http
GET /api/reading_events/:id/completion_ranking
Authorization: Bearer <token>
```

**响应**:
```json
{
  "success": true,
  "message": "获取成功",
  "data": {
    "event_id": 123,
    "total_participants": 25,
    "ranking": [
      {
        "rank": 1,
        "user_id": 1,
        "nickname": "张三",
        "avatar_url": "https://example.com/avatar1.jpg",
        "completion_rate": 100.0,
        "check_ins_count": 14,
        "leader_days_count": 1,
        "flowers_received": 8,
        "current_streak": 7
      }
    ],
    "user_rank": {
      "rank": 5,
      "completion_rate": 78.6,
      "check_ins_count": 11,
      "leader_days_count": 1,
      "flowers_received": 2
    }
  }
}
```

---

## 🏆 证书API

### 1. 生成证书
```http
POST /api/reading_events/:id/generate_certificates
Authorization: Bearer <token>
```

**响应**:
```json
{
  "success": true,
  "message": "证书生成成功",
  "data": {
    "certificates_count": 12,
    "certificate_types": {
      "completion": 8,
      "flower_top3": 3,
      "custom": 1
    },
    "certificates": [
      {
        "id": 1,
        "user_id": 1,
        "certificate_type": "completion",
        "certificate_number": "QQCL202511150001",
        "issued_at": "2025-11-15T10:00:00Z",
        "achievement_data": {
          "completion_rate": 95.0,
          "total_check_ins": 18,
          "flowers_count": 3,
          "event_title": "《三体》深度共读"
        },
        "certificate_url": "https://qqclub.com/certificates/QQCL202511150001"
      }
    ]
  }
}
```

### 2. 获取用户证书列表
```http
GET /api/users/:user_id/certificates
Authorization: Bearer <token>
```

**查询参数**:
- `event_id`: 特定活动证书筛选
- `certificate_type`: 证书类型筛选
- `page`: 页码
- `per_page`: 每页数量

### 3. 获取证书详情
```http
GET /api/certificates/:id
Authorization: Bearer <token>
```

---

## ⚠️ 错误处理

### HTTP状态码
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

### 错误响应示例

#### 400 Bad Request
```json
{
  "success": false,
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
  "success": false,
  "error": "未认证",
  "errors": [
    "请先登录"
  ]
}
```

#### 403 Forbidden
```json
{
  "success": false,
  "error": "权限不足",
  "errors": [
    "您没有权限执行此操作"
  ]
}
```

#### 404 Not Found
```json
{
  "success": false,
  "error": "资源不存在",
  "errors": [
    "活动不存在"
  ]
}
```

#### 422 Unprocessable Entity
```json
{
  "success": false,
  "error": "数据验证失败",
  "errors": [
    "活动结束时间不能早于开始时间",
    "报名人数不能超过最大限制"
  ]
}
```

---

## 🔗 API版本控制

### 版本策略
- 当前版本: v1.0
- 版本策略: URL路径版本控制 (`/api/v1/`)
- 向后兼容: 保证同一主版本内的向后兼容

### 版本更新通知
- 重大更新会提前30天通知
- 废弃接口会提供过渡期
- 新接口会标注推荐使用

---

## 📝 API测试用例

### 测试环境配置
```ruby
# spec/support/api_helper.rb
module ApiHelper
  def auth_headers(user)
    token = JwtService.encode(user_id: user.id)
    {
      'Authorization' => "Bearer #{token}",
      'Content-Type' => 'application/json'
    }
  end

  def json_response(data)
    JSON.parse(data.body)
  end
end
```

### 示例测试用例
```ruby
# spec/requests/reading_events_spec.rb
RSpec.describe "Reading Events API", type: :request do
  include ApiHelper

  describe "GET /api/reading_events" do
    it "returns reading events list" do
      get "/api/reading_events", headers: auth_headers(user)

      expect(response).to have_http_status(:ok)
      expect(json_response(response)['success']).to be true
      expect(json_response(response)['data']).to be_an(Array)
    end

    it "supports filtering by status" do
      get "/api/reading_events?status=enrolling", headers: auth_headers(user)

      events = json_response(response)['data']
      expect(events.all? { |e| e['status'] == 'enrolling' }).to be true
    end
  end
end
```

---

*本文档最后更新: 2025-10-17*