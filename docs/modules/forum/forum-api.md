# QQClub 论坛交流模块 - API规范

## 📋 文档说明

**目标读者**: 前端开发者、API集成开发者、测试工程师
**文档内容**: 论坛模块完整的API接口规格、请求/响应格式、错误处理
**与其他文档关系**: 本文档详细描述API接口，业务逻辑请参考 [论坛业务设计](forum-business.md)

---

## 🔗 API基础信息

### 基础配置
- **Base URL**: `https://api.qqclub.com` (生产环境) / `http://localhost:3000` (开发环境)
- **API版本**: `/api/v1/`
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
  },
  "meta": {
    // 元数据（分页、统计等）
  }
}
```

#### 错误响应格式
```json
{
  "success": false,
  "message": "错误描述",
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
    "per_page": 10,
    "has_next_page": true,
    "has_prev_page": false
  }
}
```

---

## 📚 分类管理API

### 1. 获取分类列表
```http
GET /api/v1/categories
Authorization: Bearer <token>
```

**查询参数**:
- `include_stats`: 是否包含统计信息 (true/false, 默认: false)

**响应**:
```json
{
  "success": true,
  "message": "获取成功",
  "data": [
    {
      "id": 1,
      "name": "读书心得",
      "description": "分享读书心得和感悟",
      "icon": "book",
      "color": "#667eea",
      "posts_count": 156,
      "is_moderated": true,
      "moderators": [
        {
          "id": 5,
          "nickname": "版主小王",
          "avatar_url": "https://example.com/avatar.jpg"
        }
      ],
      "created_at": "2025-01-01T10:00:00Z",
      "updated_at": "2025-01-15T14:30:00Z"
    }
  ]
}
```

### 2. 获取分类详情
```http
GET /api/v1/categories/:id
Authorization: Bearer <token>
```

**响应**:
```json
{
  "success": true,
  "message": "获取成功",
  "data": {
    "id": 1,
    "name": "读书心得",
    "description": "分享读书心得和感悟",
    "icon": "book",
    "color": "#667eea",
    "posts_count": 156,
    "is_moderated": true,
    "moderators": [
      {
        "id": 5,
        "nickname": "版主小王",
        "avatar_url": "https://example.com/avatar.jpg"
      }
    ],
    "rules": "请发布原创内容，禁止广告刷屏",
    "recent_posts": [
      {
        "id": 123,
        "title": "《三体》读后感",
        "author": {
          "id": 10,
          "nickname": "书虫小李",
          "avatar_url": "https://example.com/avatar2.jpg"
        },
        "created_at": "2025-01-15T10:00:00Z"
      }
    ],
    "created_at": "2025-01-01T10:00:00Z",
    "updated_at": "2025-01-15T14:30:00Z"
  }
}
```

---

## 📝 帖子管理API

### 1. 获取帖子列表
```http
GET /api/v1/posts
Authorization: Bearer <token>
```

**查询参数**:
- `page`: 页码 (默认: 1)
- `per_page`: 每页数量 (默认: 20, 最大: 50)
- `category_id`: 分类ID筛选
- `status`: 状态筛选 (published, pending_review, rejected)
- `sort`: 排序方式 (hot, new, top)
- `time_range`: 时间范围 (day, week, month, year)
- `q`: 搜索关键词

**响应**:
```json
{
  "success": true,
  "message": "获取成功",
  "data": [
    {
      "id": 123,
      "title": "《三体》读后感",
      "content": "最近读完了刘慈欣的《三体》，深受震撼...",
      "excerpt": "最近读完了刘慈欣的《三体》，深受震撼。这本书不仅仅是一部科幻小说...",
      "status": "published",
      "status_name": "已发布",
      "is_pinned": false,
      "is_locked": false,
      "views_count": 1250,
      "likes_count": 89,
      "comments_count": 23,
      "shares_count": 12,
      "hot_score": 876.5,
      "quality_score": 0.85,
      "author": {
        "id": 10,
        "nickname": "书虫小李",
        "avatar_url": "https://example.com/avatar2.jpg",
        "level": "学者",
        "level_badge": "https://example.com/badges/scholar.png"
      },
      "category": {
        "id": 1,
        "name": "读书心得",
        "icon": "book"
      },
      "tags": [
        {
          "id": 5,
          "name": "科幻小说"
        },
        {
          "id": 6,
          "name": "刘慈欣"
        }
      ],
      "attachments": [
        {
          "id": 45,
          "filename": "cover.jpg",
          "url": "https://example.com/attachments/45/cover.jpg",
          "size": 256000,
          "type": "image"
        }
      ],
      "created_at": "2025-01-15T10:00:00Z",
      "updated_at": "2025-01-15T14:30:00Z"
    }
  ],
  "pagination": {
    "current_page": 1,
    "total_pages": 8,
    "total_count": 156,
    "per_page": 20,
    "has_next_page": true,
    "has_prev_page": false
  }
}
```

### 2. 获取帖子详情
```http
GET /api/v1/posts/:id
Authorization: Bearer <token>
```

**响应**:
```json
{
  "success": true,
  "message": "获取成功",
  "data": {
    "id": 123,
    "title": "《三体》读后感",
    "content": "最近读完了刘慈欣的《三体》，深受震撼。这本书不仅仅是一部科幻小说...",
    "excerpt": "最近读完了刘慈欣的《三体》，深受震撼。这本书不仅仅是一部科幻小说...",
    "status": "published",
    "status_name": "已发布",
    "is_pinned": false,
    "is_locked": false,
    "views_count": 1250,
    "likes_count": 89,
    "comments_count": 23,
    "shares_count": 12,
    "hot_score": 876.5,
    "quality_score": 0.85,
    "author": {
      "id": 10,
      "nickname": "书虫小李",
      "avatar_url": "https://example.com/avatar2.jpg",
      "level": "学者",
      "level_badge": "https://example.com/badges/scholar.png",
      "posts_count": 45,
      "followers_count": 156,
      "created_at": "2024-06-01T10:00:00Z"
    },
    "category": {
      "id": 1,
      "name": "读书心得",
      "icon": "book",
      "color": "#667eea"
    },
    "tags": [
      {
        "id": 5,
        "name": "科幻小说"
      },
      {
        "id": 6,
        "name": "刘慈欣"
      }
    ],
    "attachments": [
      {
        "id": 45,
        "filename": "cover.jpg",
        "url": "https://example.com/attachments/45/cover.jpg",
        "size": 256000,
        "type": "image"
      }
    ],
    "user_interaction": {
      "is_liked": true,
      "is_followed": false,
      "is_saved": false
    },
    "comments": [
      {
        "id": 456,
        "content": "写得很好，我也很喜欢这本书",
        "author": {
          "id": 12,
          "nickname": "读者小张",
          "avatar_url": "https://example.com/avatar3.jpg"
        },
        "likes_count": 5,
        "created_at": "2025-01-15T12:00:00Z",
        "replies": [
          {
            "id": 457,
            "content": "谢谢支持！",
            "author": {
              "id": 10,
              "nickname": "书虫小李",
              "avatar_url": "https://example.com/avatar2.jpg"
            },
            "created_at": "2025-01-15T12:30:00Z"
          }
        ]
      }
    ],
    "created_at": "2025-01-15T10:00:00Z",
    "updated_at": "2025-01-15T14:30:00Z"
  }
}
```

### 3. 创建帖子
```http
POST /api/v1/posts
Authorization: Bearer <token>
Content-Type: application/json
```

**请求体**:
```json
{
  "post": {
    "title": "《三体》读后感",
    "content": "最近读完了刘慈欣的《三体》，深受震撼。这本书不仅仅是一部科幻小说...",
    "category_id": 1,
    "tag_ids": [5, 6],
    "attachments": [
      {
        "id": "temp_attachment_123",
        "filename": "cover.jpg"
      }
    ]
  }
}
```

**响应**:
```json
{
  "success": true,
  "message": "帖子创建成功，正在审核中",
  "data": {
    "id": 123,
    "title": "《三体》读后感",
    "status": "pending_review",
    "status_name": "审核中",
    "created_at": "2025-01-15T10:00:00Z"
  }
}
```

### 4. 更新帖子
```http
PUT /api/v1/posts/:id
Authorization: Bearer <token>
Content-Type: application/json
```

**请求体**:
```json
{
  "post": {
    "title": "更新后的标题",
    "content": "更新后的内容...",
    "tag_ids": [5, 6, 7]
  }
}
```

### 5. 删除帖子
```http
DELETE /api/v1/posts/:id
Authorization: Bearer <token>
```

**响应**: HTTP 204 No Content

### 6. 点赞帖子
```http
POST /api/v1/posts/:id/like
Authorization: Bearer <token>
```

**响应**:
```json
{
  "success": true,
  "message": "点赞成功",
  "data": {
    "likes_count": 90,
    "is_liked": true
  }
}
```

### 7. 取消点赞
```http
DELETE /api/v1/posts/:id/like
Authorization: Bearer <token>
```

**响应**:
```json
{
  "success": true,
  "message": "取消点赞成功",
  "data": {
    "likes_count": 89,
    "is_liked": false
  }
}
```

### 8. 举报帖子
```http
POST /api/v1/posts/:id/report
Authorization: Bearer <token>
Content-Type: application/json
```

**请求体**:
```json
{
  "report": {
    "reason": "spam",
    "description": "该帖子包含广告内容",
    "category": "advertising"
  }
}
```

**响应**:
```json
{
  "success": true,
  "message": "举报成功，我们会尽快处理",
  "data": {
    "report_id": 789
  }
}
```

---

## 💬 评论管理API

### 1. 获取帖子评论列表
```http
GET /api/v1/posts/:post_id/comments
Authorization: Bearer <token>
```

**查询参数**:
- `page`: 页码 (默认: 1)
- `per_page`: 每页数量 (默认: 20, 最大: 50)
- `sort`: 排序方式 (new, old, hot)

**响应**:
```json
{
  "success": true,
  "message": "获取成功",
  "data": [
    {
      "id": 456,
      "content": "写得很好，我也很喜欢这本书",
      "author": {
        "id": 12,
        "nickname": "读者小张",
        "avatar_url": "https://example.com/avatar3.jpg",
        "level": "学徒"
      },
      "likes_count": 5,
      "is_liked": true,
      "replies_count": 1,
      "created_at": "2025-01-15T12:00:00Z",
      "updated_at": "2025-01-15T12:30:00Z",
      "replies": [
        {
          "id": 457,
          "content": "谢谢支持！",
          "author": {
            "id": 10,
            "nickname": "书虫小李",
            "avatar_url": "https://example.com/avatar2.jpg"
          },
          "likes_count": 2,
          "is_liked": false,
          "created_at": "2025-01-15T12:30:00Z"
        }
      ]
    }
  ],
  "pagination": {
    "current_page": 1,
    "total_pages": 2,
    "total_count": 23,
    "per_page": 20
  }
}
```

### 2. 创建评论
```http
POST /api/v1/posts/:post_id/comments
Authorization: Bearer <token>
Content-Type: application/json
```

**请求体**:
```json
{
  "comment": {
    "content": "这是一条评论内容",
    "parent_id": 456
  }
}
```

**响应**:
```json
{
  "success": true,
  "message": "评论创建成功",
  "data": {
    "id": 458,
    "content": "这是一条评论内容",
    "author": {
      "id": 13,
      "nickname": "评论者小王",
      "avatar_url": "https://example.com/avatar4.jpg"
    },
    "likes_count": 0,
    "replies_count": 0,
    "created_at": "2025-01-15T15:00:00Z"
  }
}
```

### 3. 更新评论
```http
PUT /api/v1/comments/:id
Authorization: Bearer <token>
Content-Type: application/json
```

**请求体**:
```json
{
  "comment": {
    "content": "更新后的评论内容"
  }
}
```

### 4. 删除评论
```http
DELETE /api/v1/comments/:id
Authorization: Bearer <token>
```

**响应**: HTTP 204 No Content

---

## 👤 用户管理API

### 1. 获取用户详情
```http
GET /api/v1/users/:id
Authorization: Bearer <token>
```

**响应**:
```json
{
  "success": true,
  "message": "获取成功",
  "data": {
    "id": 10,
    "nickname": "书虫小李",
    "avatar_url": "https://example.com/avatar2.jpg",
    "bio": "热爱阅读，喜欢分享读书心得",
    "level": "学者",
    "level_badge": "https://example.com/badges/scholar.png",
    "points": 1250,
    "posts_count": 45,
    "comments_count": 234,
    "likes_received": 567,
    "followers_count": 156,
    "following_count": 89,
    "badges": [
      {
        "id": 1,
        "name": "创作达人",
        "description": "累计发帖100篇",
        "icon_url": "https://example.com/badges/creator.png",
        "earned_at": "2025-01-01T00:00:00Z"
      }
    ],
    "stats": {
      "this_month_posts": 5,
      "this_month_comments": 12,
      "total_likes_given": 234,
      "total_likes_received": 567
    },
    "is_following": false,
    "is_blocked": false,
    "created_at": "2024-06-01T10:00:00Z",
    "last_active_at": "2025-01-15T15:00:00Z"
  }
}
```

### 2. 获取用户帖子
```http
GET /api/v1/users/:id/posts
Authorization: Bearer <token>
```

**查询参数**:
- `page`: 页码 (默认: 1)
- `per_page`: 每页数量 (默认: 20)
- `status`: 状态筛选

**响应**:
```json
{
  "success": true,
  "message": "获取成功",
  "data": [
    {
      "id": 123,
      "title": "《三体》读后感",
      "excerpt": "最近读完了刘慈欣的《三体》...",
      "views_count": 1250,
      "likes_count": 89,
      "comments_count": 23,
      "created_at": "2025-01-15T10:00:00Z"
    }
  ],
  "pagination": {
    "current_page": 1,
    "total_pages": 3,
    "total_count": 45,
    "per_page": 20
  }
}
```

### 3. 获取用户评论
```http
GET /api/v1/users/:id/comments
Authorization: Bearer <token>
```

### 4. 关注用户
```http
POST /api/v1/users/:id/follow
Authorization: Bearer <token>
```

**响应**:
```json
{
  "success": true,
  "message": "关注成功",
  "data": {
    "is_following": true,
    "followers_count": 157
  }
}
```

### 5. 取消关注
```http
DELETE /api/v1/users/:id/follow
Authorization: Bearer <token>
```

---

## 🔍 搜索API

### 1. 搜索帖子
```http
GET /api/v1/search/posts
Authorization: Bearer <token>
```

**查询参数**:
- `q`: 搜索关键词 (必需)
- `category_id`: 分类筛选
- `time_range`: 时间范围 (day, week, month, year)
- `sort`: 排序方式 (relevance, hot, new)
- `page`: 页码 (默认: 1)
- `per_page`: 每页数量 (默认: 20)

**响应**:
```json
{
  "success": true,
  "message": "搜索成功",
  "data": [
    {
      "id": 123,
      "title": "《三体》读后感",
      "excerpt": "最近读完了刘慈欣的《三体》，深受震撼...",
      "relevance_score": 0.95,
      "highlights": [
        {
          "field": "title",
          "value": "<mark>《三体》</mark>读后感",
          "offset": 0
        }
      ],
      "created_at": "2025-01-15T10:00:00Z"
    }
  ],
  "pagination": {
    "current_page": 1,
    "total_pages": 2,
    "total_count": 15,
    "per_page": 20
  },
  "search_meta": {
    "query": "三体",
    "took": 45,
    "suggestions": ["三体系列", "三体黑暗森林"]
  }
}
```

### 2. 搜索用户
```http
GET /api/v1/search/users
Authorization: Bearer <token>
```

**查询参数**:
- `q`: 搜索关键词 (必需)
- `level`: 等级筛选
- `page`: 页码 (默认: 1)
- `per_page`: 每页数量 (默认: 20)

---

## 🏆 管理员API

### 1. 获取待审核内容
```http
GET /api/v1/admin/posts/pending_review
Authorization: Bearer <admin_token>
```

**响应**:
```json
{
  "success": true,
  "message": "获取成功",
  "data": [
    {
      "id": 456,
      "title": "待审核帖子标题",
      "content": "帖子内容预览...",
      "author": {
        "id": 20,
        "nickname": "用户小王"
      },
      "moderation_status": "pending",
      "auto_moderation_score": 65,
      "created_at": "2025-01-15T10:00:00Z"
    }
  ]
}
```

### 2. 审核通过
```http
POST /api/v1/admin/posts/:id/approve
Authorization: Bearer <admin_token>
```

**请求体**:
```json
{
  "admin_note": "内容质量良好，审核通过"
}
```

### 3. 审核拒绝
```http
POST /api/v1/admin/posts/:id/reject
Authorization: Bearer <admin_token>
```

**请求体**:
```json
{
  "reason": "内容质量不符合标准",
  "admin_note": "需要修改后重新提交"
}
```

### 4. 置顶帖子
```http
POST /api/v1/admin/posts/:id/pin
Authorization: Bearer <admin_token>
```

### 5. 获取举报列表
```http
GET /api/v1/admin/reports
Authorization: Bearer <admin_token>
```

**查询参数**:
- `status`: 状态筛选 (pending, processing, resolved)
- `type`: 举报类型筛选
- `page`: 页码
- `per_page`: 每页数量

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
| 429 | 请求过于频繁 |
| 500 | 服务器内部错误 |

### 错误响应示例

#### 400 Bad Request
```json
{
  "success": false,
  "message": "请求参数错误",
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
  "message": "未认证",
  "errors": [
    "请先登录"
  ]
}
```

#### 403 Forbidden
```json
{
  "success": false,
  "message": "权限不足",
  "errors": [
    "您没有权限执行此操作"
  ]
}
```

#### 404 Not Found
```json
{
  "success": false,
  "message": "资源不存在",
  "errors": [
    "帖子不存在"
  ]
}
```

#### 422 Unprocessable Entity
```json
{
  "success": false,
  "message": "数据验证失败",
  "errors": [
    "标题长度必须在5-100个字符之间",
    "分类ID不能为空"
  ]
}
```

#### 429 Too Many Requests
```json
{
  "success": false,
  "message": "请求过于频繁",
  "errors": [
    "请稍后再试"
  ],
  "retry_after": 60
}
```

---

## 📝 API测试用例

### 认证测试
```ruby
# spec/requests/authentication_spec.rb
RSpec.describe "Authentication", type: :request do
  describe "POST /api/v1/auth/login" do
    it "returns JWT token for valid credentials" do
      user = create(:user, :verified)

      post api_v1_auth_login_path, params: {
        auth: {
          openid: user.wx_openid,
          nickname: user.nickname
        }
      }

      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response['success']).to be true
      expect(json_response['data']['token']).to be_present
    end

    it "returns error for invalid credentials" do
      post api_v1_auth_login_path, params: {
        auth: {
          openid: 'invalid_openid',
          nickname: 'test'
        }
      }

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
```

### 帖子管理测试
```ruby
# spec/requests/posts_spec.rb
RSpec.describe "Posts", type: :request do
  let(:user) { create(:user, :verified) }
  let(:auth_headers) { auth_headers_for(user) }

  describe "GET /api/v1/posts" do
    it "returns paginated posts list" do
      create_list(:post, 25)

      get api_v1_posts_path, headers: auth_headers

      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response['success']).to be true
      expect(json_response['data']).to be_an(Array)
      expect(json_response['pagination']).to be_present
    end

    it "filters posts by category" do
      category = create(:category)
      post1 = create(:post, category: category)
      post2 = create(:post)

      get api_v1_posts_path, params: { category_id: category.id }, headers: auth_headers

      json_response = JSON.parse(response.body)
      post_ids = json_response['data'].map { |p| p['id'] }
      expect(post_ids).to include(post1.id)
      expect(post_ids).not_to include(post2.id)
    end
  end

  describe "POST /api/v1/posts" do
    it "creates a new post" do
      category = create(:category)

      post api_v1_posts_path, params: {
        post: {
          title: "测试帖子",
          content: "这是测试内容",
          category_id: category.id
        }
      }, headers: auth_headers

      expect(response).to have_http_status(:created)
      json_response = JSON.parse(response.body)
      expect(json_response['success']).to be true
      expect(json_response['data']['title']).to eq("测试帖子")
    end

    it "validates required fields" do
      post api_v1_posts_path, params: {
        post: {
          title: "",
          content: "",
          category_id: nil
        }
      }, headers: auth_headers

      expect(response).to have_http_status(:unprocessable_entity)
      json_response = JSON.parse(response.body)
      expect(json_response['success']).to be false
      expect(json_response['errors']).to include("标题不能为空")
    end
  end
end
```

---

## 🔗 API版本控制

### 版本策略
- **当前版本**: v1.0
- **版本控制**: URL路径版本控制 (`/api/v1/`)
- **向后兼容**: 保证同一主版本内的向后兼容

### 版本更新通知
- **重大更新**: 提前30天通知
- **废弃接口**: 提供过渡期
- **新接口**: 标注推荐使用

---

## 📊 性能考虑

### 请求限制
- **默认限制**: 每用户每分钟100次请求
- **搜索限制**: 每用户每分钟20次搜索请求
- **发帖限制**: 每用户每5分钟最多发帖3次

### 响应时间
- **目标响应时间**: 95%的请求在200ms内完成
- **复杂查询**: 全文搜索等操作允许500ms内完成
- **超时设置**: 所有接口30秒超时

---

*本文档最后更新: 2025-10-17*