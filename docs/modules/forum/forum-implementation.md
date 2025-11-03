# QQClub 论坛交流模块 - 实施指南

## 📋 文档说明

**目标读者**: 开发团队、DevOps工程师、项目经理
**文档内容**: 论坛模块的开发计划、测试策略、部署指南、运维管理
**与其他文档关系**: 本文档是论坛模块的具体实施指导，技术设计请参考 [论坛技术设计](forum-technical.md)

---

## 🚀 项目实施计划

### 开发阶段规划

#### 第一阶段：基础功能开发 (4周)
**目标**: 建立基础的论坛交流能力

**核心功能**:
- [x] 用户发帖和评论功能
- [x] 基础的内容展示和浏览
- [x] 简单的用户管理
- [x] 基础的内容审核

**开发任务**:
```
Week 1: 数据库设计和基础模型
├── 创建论坛相关数据表
├── 实现User, Post, Comment基础模型
├── 设置基础的数据验证和关联
└── 创建基础测试用例

Week 2: 帖子和评论功能
├── 实现帖子CRUD API
├── 实现评论CRUD API
├── 添加基础的内容展示页面
└── 实现简单的分页功能

Week 3: 用户管理和认证
├── 集成微信登录
├── 实现用户角色权限系统
├── 添加用户个人主页
└── 实现用户关注功能

Week 4: 内容审核和基础管理
├── 实现敏感词过滤
├── 添加举报功能
├── 创建管理员后台界面
└── 完成基础功能测试
```

**交付物**:
- 可运行的论坛基础版本
- 完整的API文档
- 基础功能测试套件
- 用户手册和部署文档

#### 第二阶段：社区治理功能 (3周)
**目标**: 完善社区治理机制

**新增功能**:
- [ ] 完整的内容审核体系
- [ ] 用户举报和处理机制
- [ ] 版主管理系统
- [ ] 社区规则配置

**开发任务**:
```
Week 5: 高级内容审核
├── 实现图片内容识别
├── 添加AI内容检测
├── 实现审核工作流
└── 创建审核历史记录

Week 6: 用户举报系统
├── 实现举报功能
├── 添加举报处理流程
├── 创建举报统计报表
└── 实现自动处理规则

Week 7: 版主管理系统
├── 实现版主权限管理
├── 添加版主工作台
├── 实现版主绩效统计
└── 完成社区治理功能测试
```

#### 第三阶段：激励机制 (2周)
**目标**: 建立用户激励体系

**新增功能**:
- [ ] 积分和等级系统
- [ ] 徽章系统
- [ ] 排行榜功能
- [ ] 用户活跃度统计

**开发任务**:
```
Week 8: 积分等级系统
├── 实现积分获取和消费
├── 添加用户等级升级
├── 创建积分流水记录
└── 实现等级权益配置

Week 9: 徽章和排行榜
├── 实现徽章系统
├── 添加多维度排行榜
├── 创建用户成就页面
└── 完成激励机制测试
```

#### 第四阶段：智能化运营 (3周)
**目标**: 提升用户体验和运营效率

**新增功能**:
- [ ] 智能内容推荐
- [ ] 用户行为分析
- [ ] 自动化运营工具
- [ ] 数据可视化仪表板

#### 第五阶段：性能优化和扩展 (2周)
**目标**: 优化系统性能和扩展功能

**优化重点**:
- [ ] 数据库查询优化
- [ ] 缓存策略优化
- [ ] 前端性能优化
- [ ] 系统监控完善

### 里程碑设置

| 里程碑 | 时间节点 | 主要交付物 | 验收标准 |
|--------|----------|------------|----------|
| M1: MVP版本 | 第4周末 | 基础论坛功能 | 用户可正常发帖评论 |
| M2: 社区治理 | 第7周末 | 完整治理体系 | 内容审核流程完整 |
| M3: 激励机制 | 第9周末 | 用户激励体系 | 积分徽章系统可用 |
| M4: 智能化运营 | 第12周末 | 运营工具包 | 推荐系统上线 |
| M5: 生产就绪 | 第14周末 | 优化版本 | 性能指标达标 |

---

## 👥 团队组织架构

### 开发团队配置

#### 核心团队 (6人)
- **项目经理** (1人): 项目协调、进度管理、风险控制
- **后端开发** (2人): API开发、数据库设计、业务逻辑实现
- **前端开发** (2人): Web界面、小程序界面、交互实现
- **测试工程师** (1人): 测试用例设计、自动化测试、质量保证

#### 支持团队 (3人)
- **UI/UX设计师** (1人): 界面设计、交互设计、设计规范
- **DevOps工程师** (1人): 部署配置、监控运维、性能优化
- **产品经理** (1人): 需求分析、产品规划、用户调研

### 协作流程

#### 开发流程
```mermaid
graph TD
    A[需求分析] --> B[技术设计]
    B --> C[任务分解]
    C --> D[开发实现]
    D --> E[代码审查]
    E --> F[测试验证]
    F --> G[部署上线]
    G --> H[监控维护]
    H --> A
```

#### 每日站会
- **时间**: 每天上午9:30
- **参与者**: 全体开发团队
- **内容**: 昨日完成、今日计划、问题障碍
- **时长**: 15分钟

#### 每周复盘
- **时间**: 每周五下午
- **参与者**: 项目团队 + 产品经理
- **内容**: 进度回顾、问题总结、下周计划
- **时长**: 1小时

---

## 🛠️ 开发环境搭建

### 本地开发环境

#### 1. 系统要求
```bash
# 操作系统
- macOS 10.15+ / Ubuntu 18.04+ / Windows 10+

# 开发工具
- Ruby 3.2.0+
- Rails 8.0+
- PostgreSQL 15+
- Redis 7.0+
- Node.js 18.0+
- Git 2.30+
```

#### 2. 环境配置脚本
```bash
#!/bin/bash
# setup_forum_dev.sh

echo "=== QQClub 论坛模块开发环境搭建 ==="

# 安装Ruby (使用rbenv)
if ! command -v rbenv &> /dev/null; then
    echo "安装rbenv..."
    brew install rbenv
    echo 'eval "$(rbenv init -)"' >> ~/.zshrc
fi

echo "安装Ruby 3.2.0..."
rbenv install 3.2.0
rbenv global 3.2.0

# 安装Rails
echo "安装Rails..."
gem install rails -v 8.0.0

# 安装PostgreSQL
if ! command -v psql &> /dev/null; then
    echo "安装PostgreSQL..."
    brew install postgresql@15
    brew services start postgresql@15
fi

# 创建开发数据库
echo "创建开发数据库..."
createdb qqclub_development
createdb qqclub_test

# 安装Redis
if ! command -v redis-server &> /dev/null; then
    echo "安装Redis..."
    brew install redis
    brew services start redis
fi

# 克隆项目
echo "克隆项目代码..."
git clone https://github.com/your-org/qqclub.git
cd qqclub

# 安装依赖
echo "安装项目依赖..."
bundle install
yarn install

# 配置环境变量
echo "配置环境变量..."
cp .env.example .env.development

# 初始化数据库
echo "初始化数据库..."
rails db:create db:migrate db:seed

echo "=== 开发环境搭建完成 ==="
echo "启动开发服务器: rails server"
echo "运行测试: rails test"
```

#### 3. Docker 开发环境
```dockerfile
# Dockerfile.dev
FROM ruby:3.2.0-alpine

# 安装系统依赖
RUN apk add --no-cache \
    build-base \
    postgresql-dev \
    tzdata \
    nodejs \
    npm \
    git

# 设置工作目录
WORKDIR /app

# 复制Gemfile并安装依赖
COPY Gemfile Gemfile.lock ./
RUN bundle config set --local deployment 'true' && \
    bundle install --jobs 4 --retry 3

# 复制package.json并安装Node.js依赖
COPY package.json yarn.lock ./
RUN yarn install

# 复制应用代码
COPY . .

# 设置环境变量
ENV RAILS_ENV=development
ENV RAILS_LOG_TO_STDOUT=true

# 暴露端口
EXPOSE 3000

# 启动命令
CMD ["rails", "server", "-b", "0.0.0.0"]
```

```yaml
# docker-compose.dev.yml
version: '3.8'

services:
  app:
    build:
      context: .
      dockerfile: Dockerfile.dev
    ports:
      - "3000:3000"
    volumes:
      - .:/app
      - bundle_cache:/usr/local/bundle
    environment:
      - DATABASE_URL=postgresql://postgres:password@db:5432/qqclub_development
      - REDIS_URL=redis://redis:6379/0
    depends_on:
      - db
      - redis
    command: rails server -b 0.0.0.0

  db:
    image: postgres:15-alpine
    environment:
      - POSTGRES_DB=qqclub_development
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=password
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"

  redis:
    image: redis:7.0-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data

volumes:
  bundle_cache:
  postgres_data:
  redis_data:
```

### 开发工具配置

#### 1. VS Code 配置
```json
// .vscode/settings.json
{
  "ruby.useLanguageServer": true,
  "ruby.lint": {
    "rubocop": {
      "lint": true,
      "rails": true
    },
    "reek": true,
    "fasterer": true
  },
  "ruby.format": "rubocop",
  "emmet.includeLanguages": {
    "erb": "html"
  },
  "files.associations": {
    "*.erb": "html.erb"
  },
  "editor.formatOnSave": true,
  "editor.codeActionsOnSave": {
    "source.organizeImports": true
  }
}
```

#### 2. Git Hooks 配置
```bash
#!/bin/bash
# .git/hooks/pre-commit

echo "运行预提交检查..."

# 运行代码风格检查
bundle exec rubocop --parallel
if [ $? -ne 0 ]; then
    echo "❌ 代码风格检查失败，请修复后重新提交"
    exit 1
fi

# 运行静态分析
bundle exec reek
if [ $? -ne 0 ]; then
    echo "⚠️  代码有异味，建议改进"
fi

# 运行基础测试
bundle exec rails test:units
if [ $? -ne 0 ]; then
    echo "❌ 单元测试失败，请修复后重新提交"
    exit 1
fi

echo "✅ 预提交检查通过"
```

---

## 🧪 测试策略

### 测试金字塔

```
        /\
       /  \
      / E2E \     - 端到端测试 (10%)
     /______\
    /        \
   /Integration\ - 集成测试 (20%)
  /__________\
 /            \
/   Unit Test  \  - 单元测试 (70%)
/______________\
```

### 单元测试

#### 1. 模型测试
```ruby
# test/models/post_test.rb
require "test_helper"

class PostTest < ActiveSupport::TestCase
  def setup
    @user = create(:user, :verified)
    @category = create(:category)
    @post = build(:post, user: @user, category: @category)
  end

  test "应该有效且所有验证通过" do
    assert @post.valid?
  end

  test "标题不能为空" do
    @post.title = ""
    assert_not @post.valid?
    assert_includes @post.errors[:title], "不能为空"
  end

  test "内容不能为空" do
    @post.content = ""
    assert_not @post.valid?
    assert_includes @post.errors[:content], "不能为空"
  end

  test "标题长度应该在5-200字符之间" do
    @post.title = "1234"  # 太短
    assert_not @post.valid?

    @post.title = "a" * 201  # 太长
    assert_not @post.valid?

    @post.title = "有效的标题"
    assert @post.valid?
  end

  test "应该自动生成摘要" do
    @post.content = "这是一个很长的帖子内容，应该能够自动生成摘要..."
    @post.save
    assert_not_nil @post.excerpt
    assert @post.excerpt.length <= 200
  end

  test "发布时间应该在创建时间之后" do
    @post.save!
    travel_to 1.hour.from_now
    @post.publish!
    assert @post.published_at > @post.created_at
    travel_back
  end
end
```

#### 2. 服务类测试
```ruby
# test/services/content_moderation_service_test.rb
require "test_helper"

class ContentModerationServiceTest < ActiveSupport::TestCase
  def setup
    @sensitive_word = create(:sensitive_word, word: "违禁词", level: 3)
  end

  test "应该检测到敏感词" do
    content = "这里包含违禁词内容"
    result = ContentModerationService.detect_sensitive_words(content)

    assert result[:score] > 0
    assert_includes result[:words], "违禁词"
    assert result[:positions].any?
  end

  test "正常内容应该通过检测" do
    content = "这是一个正常的帖子内容"
    result = ContentModerationService.detect_sensitive_words(content)

    assert_equal 0, result[:score]
    assert_empty result[:words]
  end

  test "应该计算敏感度分数" do
    create(:sensitive_word, word: "轻微词", level: 1)
    create(:sensitive_word, word: "严重词", level: 3)

    content = "轻微词和严重词混合内容"
    result = ContentModerationService.detect_sensitive_words(content)

    assert result[:score] > 3  # 严重词权重更高
  end

  test "应该处理大小写和空格" do
    variations = [
      "违禁词",
      " 违禁词 ",
      "违 禁 词",
      "WEI JIN CI"
    ]

    variations.each do |content|
      result = ContentModerationService.detect_sensitive_words(content)
      assert result[:score] > 0, "应该检测到变体: #{content}"
    end
  end
end
```

#### 3. 控制器测试
```ruby
# test/controllers/api/posts_controller_test.rb
require "test_helper"

class Api::PostsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = create(:user, :verified)
    @auth_headers = auth_headers_for(@user)
    @category = create(:category)
  end

  test "应该获取帖子列表" do
    create_list(:post, 5, :published, category: @category)

    get api_posts_path, headers: @auth_headers

    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response['success']
    assert_equal 5, json_response['data'].length
    assert json_response['pagination'].present?
  end

  test "应该按分类筛选帖子" do
    category1 = create(:category)
    category2 = create(:category)

    post1 = create(:post, :published, category: category1)
    post2 = create(:post, :published, category: category2)

    get api_posts_path, params: { category_id: category1.id }, headers: @auth_headers

    json_response = JSON.parse(response.body)
    post_ids = json_response['data'].map { |p| p['id'] }
    assert_includes post_ids, post1.id
    assert_not_includes post_ids, post2.id
  end

  test "应该创建新帖子" do
    post_params = {
      title: "测试帖子标题",
      content: "这是一个测试帖子的内容",
      category_id: @category.id
    }

    post api_posts_path, params: { post: post_params }, headers: @auth_headers

    assert_response :created
    json_response = JSON.parse(response.body)
    assert json_response['success']
    assert_equal "测试帖子标题", json_response['data']['title']
    assert_equal "pending_review", json_response['data']['status']
  end

  test "应该验证必填字段" do
    post_params = {
      title: "",
      content: "",
      category_id: nil
    }

    post api_posts_path, params: { post: post_params }, headers: @auth_headers

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_not json_response['success']
    assert json_response['errors'].present?
  end

  test "未认证用户不能发帖" do
    post_params = {
      title: "测试帖子",
      content: "测试内容",
      category_id: @category.id
    }

    post api_posts_path, params: { post: post_params }

    assert_response :unauthorized
  end
end
```

### 集成测试

#### 1. API 集成测试
```ruby
# test/integration/post_management_test.rb
require "test_helper"

class PostManagementTest < ActionDispatch::IntegrationTest
  def setup
    @user = create(:user, :verified)
    @auth_headers = auth_headers_for(@user)
    @category = create(:category)
  end

  test "完整的帖子发布流程" do
    # 1. 用户登录
    post api_auth_login_path, params: {
      auth: { wx_openid: @user.wx_openid, nickname: @user.nickname }
    }
    assert_response :success

    token = JSON.parse(response.body)['data']['token']
    headers = { 'Authorization' => "Bearer #{token}" }

    # 2. 获取分类列表
    get api_categories_path, headers: headers
    assert_response :success

    # 3. 创建帖子
    post_params = {
      title: "我的第一篇帖子",
      content: "这是我的第一篇帖子内容，希望大家喜欢。",
      category_id: @category.id
    }

    post api_posts_path, params: { post: post_params }, headers: headers
    assert_response :created

    post_data = JSON.parse(response.body)['data']
    post_id = post_data['id']

    # 4. 获取帖子详情
    get api_post_path(post_id), headers: headers
    assert_response :success

    # 5. 添加评论
    comment_params = {
      comment: {
        content: "很好的帖子，支持一下！"
      }
    }

    post api_post_comments_path(post_id), params: comment_params, headers: headers
    assert_response :success

    # 6. 点赞帖子
    post like_api_post_path(post_id), headers: headers
    assert_response :success

    # 7. 验证统计数据更新
    get api_post_path(post_id), headers: headers
    updated_post = JSON.parse(response.body)['data']

    assert_equal 1, updated_post['comments_count']
    assert_equal 1, updated_post['likes_count']
  end

  test "帖子审核流程" do
    # 1. 创建帖子
    post = create(:post, :pending_review, user: @user)

    # 2. 管理员审核通过
    admin = create(:user, :admin)
    admin_headers = auth_headers_for(admin)

    post approve_admin_post_path(post), headers: admin_headers
    assert_response :success

    # 3. 验证帖子状态更新
    post.reload
    assert_equal 'published', post.status
  end
end
```

### 端到端测试

#### 1. 用户发帖流程测试
```javascript
// tests/e2e/post_creation.spec.js
const { test, expect } = require('@playwright/test');

test.describe('论坛发帖流程', () => {
  test.beforeEach(async ({ page }) => {
    // 模拟用户登录
    await page.goto('/auth/login');
    await page.fill('[data-testid="openid-input"]', 'test_openid_123');
    await page.click('[data-testid="login-button"]');
    await page.waitForURL('/forum');
  });

  test('用户应该能够成功发帖', async ({ page }) => {
    // 1. 点击发帖按钮
    await page.click('[data-testid="create-post-button"]');

    // 2. 填写帖子信息
    await page.fill('[data-testid="post-title"]', '我的第一篇测试帖子');
    await page.fill('[data-testid="post-content"]', '这是测试帖子的内容，应该能够正常发布。');

    // 3. 选择分类
    await page.selectOption('[data-testid="post-category"]', { label: '读书心得' });

    // 4. 提交帖子
    await page.click('[data-testid="submit-post-button"]');

    // 5. 验证发布成功
    await expect(page.locator('[data-testid="success-message"]')).toBeVisible();
    await expect(page.locator('text=帖子发布成功，正在审核中')).toBeVisible();

    // 6. 验证跳转到帖子列表
    await expect(page).toHaveURL(/\/forum\/posts$/);
  });

  test('应该验证必填字段', async ({ page }) => {
    await page.goto('/forum/posts/new');

    // 不填写任何内容直接提交
    await page.click('[data-testid="submit-post-button"]');

    // 验证错误提示
    await expect(page.locator('[data-testid="title-error"]')).toBeVisible();
    await expect(page.locator('[data-testid="content-error"]')).toBeVisible();
    await expect(page.locator('[data-testid="category-error"]')).toBeVisible();
  });

  test('应该支持图片上传', async ({ page }) => {
    await page.goto('/forum/posts/new');

    // 填写基本信息
    await page.fill('[data-testid="post-title"]', '带图片的帖子');
    await page.fill('[data-testid="post-content"]', '这篇帖子包含图片。');

    // 上传图片
    const fileInput = page.locator('[data-testid="image-upload"]');
    await fileInput.setInputFiles('tests/fixtures/test-image.jpg');

    // 等待上传完成
    await expect(page.locator('[data-testid="upload-success"]')).toBeVisible();

    // 提交帖子
    await page.selectOption('[data-testid="post-category"]', { label: '读书心得' });
    await page.click('[data-testid="submit-post-button"]');

    // 验证发布成功
    await expect(page.locator('[data-testid="success-message"]')).toBeVisible();
  });
});
```

#### 2. 移动端测试
```javascript
// tests/e2e/mobile/mobile_forum.spec.js
const { test, expect } = require('@playwright/test');

test.describe('移动端论坛功能', () => {
  test.use({ viewport: { width: 375, height: 667 } }); // iPhone X 尺寸

  test('移动端发帖体验', async ({ page }) => {
    // 模拟移动端环境
    await page.emulateMedia({ media: 'screen' });

    // 登录
    await page.goto('/auth/login');
    await page.fill('[data-testid="openid-input"]', 'mobile_test_user');
    await page.click('[data-testid="login-button"]');

    // 验证移动端适配
    await expect(page.locator('[data-testid="mobile-nav"]')).toBeVisible();

    // 点击浮动发帖按钮
    await page.click('[data-testid="floating-post-button"]');

    // 验证移动端发帖界面
    await expect(page.locator('[data-testid="mobile-post-form"]')).toBeVisible();

    // 填写并发帖
    await page.fill('[data-testid="mobile-post-title"]', '移动端测试帖子');
    await page.fill('[data-testid="mobile-post-content"]', '这是从移动端发布的帖子。');
    await page.selectOption('[data-testid="mobile-post-category"]', { label: '读书心得' });

    await page.click('[data-testid="mobile-submit-button"]');

    // 验证发布成功
    await expect(page.locator('[data-testid="mobile-success-toast"]')).toBeVisible();
  });
});
```

### 测试数据管理

#### 1. Factory Bot 定义
```ruby
# test/factories/users.rb
FactoryBot.define do
  factory :user do
    sequence(:wx_openid) { |n| "test_openid_#{n}" }
    sequence(:nickname) { |n| "测试用户#{n}" }
    avatar_url { "https://example.com/avatar.jpg" }
    bio { "这是一个测试用户的简介" }
    level { 1 }
    points { 100 }
    verified { false }
    status { 1 }

    trait :verified do
      verified { true }
      status { 1 }
    end

    trait :admin do
      verified { true }
      after(:create) do |user|
        create(:user_role, user: user, role: create(:role, :admin))
      end
    end

    trait :moderator do
      verified { true }
      after(:create) do |user|
        create(:user_role, user: user, role: create(:role, :moderator))
      end
    end
  end
end

# test/factories/posts.rb
FactoryBot.define do
  factory :post do
    sequence(:title) { |n| "测试帖子标题#{n}" }
    content { "这是一个测试帖子的内容，包含足够的文字来满足系统要求。" }
    association :category
    association :author, factory: :user, :verified
    status { 'draft' }

    trait :published do
      status { 'published' }
      published_at { 1.day.ago }
    end

    trait :pending_review do
      status { 'pending_review' }
    end

    trait :featured do
      is_featured { true }
      published
    end

    trait :pinned do
      is_pinned { true }
      published
    end

    trait :with_comments do
      after(:create) do |post|
        create_list(:comment, 3, post: post)
      end
    end
  end
end
```

#### 2. 测试数据清理
```ruby
# test/support/database_cleaner.rb
class DatabaseCleaner
  def self.clean
    # 清理测试数据，保留基础配置数据
    ActiveRecord::Base.connection.execute("
      TRUNCATE TABLE
        posts, comments, likes, follows, collections,
        user_roles, point_transactions, user_badges,
        reports, moderation_logs, attachments
      RESTART IDENTITY CASCADE;
    ")
  end

  def self.clean_with_seed
    clean
    # 加载基础测试数据
    Rails.application.load_seed
  end
end

# 在测试套件中使用
class ActiveSupport::TestCase
  setup do
    DatabaseCleaner.clean_with_seed
  end

  teardown do
    DatabaseCleaner.clean
  end
end
```

---

## 🚀 部署指南

### 开发环境部署

#### 1. 本地启动脚本
```bash
#!/bin/bash
# scripts/start_dev.sh

echo "=== 启动 QQClub 论坛开发环境 ==="

# 检查环境
echo "检查环境依赖..."
ruby -v
rails -v
psql --version
redis-server --version

# 启动数据库
echo "启动 PostgreSQL..."
brew services start postgresql@15

# 启动 Redis
echo "启动 Redis..."
brew services start redis

# 数据库迁移
echo "执行数据库迁移..."
rails db:migrate

# 加载基础数据
echo "加载基础数据..."
rails db:seed

# 启动 Rails 服务
echo "启动 Rails 开发服务器..."
rails server -p 3000 -d

# 启动 Sidekiq
echo "启动后台任务处理..."
bundle exec sidekiq -d

# 启动前端开发服务器
echo "启动前端开发服务器..."
cd qqclub-miniprogram
npm run dev:weapp &

echo "=== 开发环境启动完成 ==="
echo "Rails 服务: http://localhost:3000"
echo "小程序开发者工具: 请打开 qqclub-miniprogram 目录"
echo "Sidekiq Web: http://localhost:3000/sidekiq"
```

### 测试环境部署

#### 1. Docker Compose 配置
```yaml
# docker-compose.test.yml
version: '3.8'

services:
  app:
    build:
      context: .
      dockerfile: Dockerfile.prod
    environment:
      - RAILS_ENV=test
      - DATABASE_URL=postgresql://postgres:password@db:5432/qqclub_test
      - REDIS_URL=redis://redis:6379/0
      - SECRET_KEY_BASE=test_secret_key_base
    depends_on:
      - db
      - redis
    volumes:
      - .:/app
      - bundle_cache:/usr/local/bundle
    command: >
      sh -c "
        bundle exec rails db:test:prepare &&
        bundle exec rails test &&
        bundle exec rails test:system
      "

  db:
    image: postgres:15-alpine
    environment:
      - POSTGRES_DB=qqclub_test
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=password
    volumes:
      - postgres_test_data:/var/lib/postgresql/data

  redis:
    image: redis:7.0-alpine
    volumes:
      - redis_test_data:/data

volumes:
  bundle_cache:
  postgres_test_data:
  redis_test_data:
```

#### 2. CI/CD 配置
```yaml
# .github/workflows/forum_test.yml
name: Forum Module Tests

on:
  push:
    branches: [ main, develop ]
    paths:
      - 'qqclub_api/**'
      - 'qqclub-miniprogram/**'
      - 'docs/modules/forum/**'
  pull_request:
    branches: [ main ]
    paths:
      - 'qqclub_api/**'
      - 'qqclub-miniprogram/**'
      - 'docs/modules/forum/**'

jobs:
  backend_tests:
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: password
          POSTGRES_DB: qqclub_test
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432

      redis:
        image: redis:7
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 6379:6379

    steps:
    - uses: actions/checkout@v3

    - name: Set up Ruby
      uses: ruby/setup-ruby@v1
      with:
        ruby-version: '3.2.0'
        bundler-cache: true
        working-directory: qqclub_api

    - name: Install dependencies
      working-directory: qqclub_api
      run: |
        bundle install
        yarn install

    - name: Setup database
      working-directory: qqclub_api
      env:
        DATABASE_URL: postgresql://postgres:password@localhost:5432/qqclub_test
        REDIS_URL: redis://localhost:6379/0
      run: |
        bundle exec rails db:create
        bundle exec rails db:schema:load

    - name: Run tests
      working-directory: qqclub_api
      env:
        DATABASE_URL: postgresql://postgres:password@localhost:5432/qqclub_test
        REDIS_URL: redis://localhost:6379/0
        RAILS_ENV: test
      run: |
        bundle exec rails test
        bundle exec rails test:system

    - name: Upload coverage reports
      uses: codecov/codecov-action@v3
      with:
        file: ./qqclub_api/coverage/.resultset.json

  frontend_tests:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v3

    - name: Set up Node.js
      uses: actions/setup-node@v3
      with:
        node-version: '18'
        cache: 'npm'
        cache-dependency-path: qqclub-miniprogram/package-lock.json

    - name: Install dependencies
      working-directory: qqclub-miniprogram
      run: npm ci

    - name: Run tests
      working-directory: qqclub-miniprogram
      run: npm test

    - name: Build for production
      working-directory: qqclub-miniprogram
      run: npm run build
```

### 生产环境部署

#### 1. 服务器配置
```bash
#!/bin/bash
# scripts/setup_prod.sh

SERVER_IP="your-server-ip"
APP_NAME="qqclub-forum"
DEPLOY_USER="deploy"

echo "=== 配置生产服务器 ==="

# 创建部署用户
ssh root@$SERVER_IP "useradd -m -s /bin/bash $DEPLOY_USER"
ssh root@$SERVER_IP "usermod -aG sudo $DEPLOY_USER"

# 安装系统依赖
ssh root@$SERVER_IP << 'EOF'
apt update && apt upgrade -y
apt install -y curl wget git nginx postgresql redis-server

# 安装 Ruby
gpg --keyserver keyserver.ubuntu.com --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
curl -sSL https://get.rvm.io | bash -s stable --ruby=3.2.0

# 安装 Node.js
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

# 配置防火墙
ufw allow 22
ufw allow 80
ufw allow 443
ufw --force enable
EOF

# 配置数据库
ssh root@$SERVER_IP << 'EOF'
sudo -u postgres createuser qqclub
sudo -u postgres createdb qqclub_production
sudo -u postgres psql -c "ALTER USER qqclub PASSWORD 'secure_password';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE qqclub_production TO qqclub;"
EOF

echo "=== 生产服务器配置完成 ==="
```

#### 2. 部署脚本
```bash
#!/bin/bash
# scripts/deploy.sh

set -e

SERVER_IP="your-server-ip"
APP_NAME="qqclub-forum"
DEPLOY_USER="deploy"
DEPLOY_PATH="/var/www/$APP_NAME"
BRANCH="main"

echo "=== 开始部署 $APP_NAME ==="

# 1. 备份当前版本
ssh $DEPLOY_USER@$SERVER_IP "cd $DEPLOY_PATH && ./scripts/backup.sh"

# 2. 拉取最新代码
ssh $DEPLOY_USER@$SERVER_IP "cd $DEPLOY_PATH && git fetch origin && git reset --hard origin/$BRANCH"

# 3. 安装依赖
ssh $DEPLOY_USER@$SERVER_IP << EOF
cd $DEPLOY_PATH
source ~/.rvm/scripts/rvm
bundle install --deployment --without development test
yarn install --production
EOF

# 4. 数据库迁移
ssh $DEPLOY_USER@$SERVER_IP << EOF
cd $DEPLOY_PATH
source ~/.rvm/scripts/rvm
RAILS_ENV=production bundle exec rails db:migrate
EOF

# 5. 预编译资源
ssh $DEPLOY_USER@$SERVER_IP << EOF
cd $DEPLOY_PATH
source ~/.rvm/scripts/rvm
RAILS_ENV=production bundle exec rails assets:precompile
EOF

# 6. 重启服务
ssh $DEPLOY_USER@$SERVER_IP << EOF
cd $DEPLOY_PATH
sudo systemctl restart puma
sudo systemctl restart sidekiq
sudo systemctl reload nginx
EOF

# 7. 健康检查
sleep 10
HEALTH_CHECK=$(curl -s -o /dev/null -w "%{http_code}" http://$SERVER_IP/health)
if [ $HEALTH_CHECK -eq 200 ]; then
    echo "✅ 部署成功！"
else
    echo "❌ 部署失败，开始回滚..."
    ssh $DEPLOY_USER@$SERVER_IP "cd $DEPLOY_PATH && ./scripts/rollback.sh"
    exit 1
fi

echo "=== 部署完成 ==="
```

#### 3. Nginx 配置
```nginx
# /etc/nginx/sites-available/qqclub-forum
upstream app {
    server unix:///var/www/qqclub-forum/shared/sockets/puma.sock;
}

server {
    listen 80;
    server_name forum.qqclub.com;

    # 重定向到 HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name forum.qqclub.com;

    # SSL 配置
    ssl_certificate /etc/letsencrypt/live/forum.qqclub.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/forum.qqclub.com/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512;
    ssl_prefer_server_ciphers off;

    # 安全头
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # 日志
    access_log /var/log/nginx/qqclub-forum.access.log;
    error_log /var/log/nginx/qqclub-forum.error.log;

    # 客户端上传大小限制
    client_max_body_size 10M;

    # Gzip 压缩
    gzip on;
    gzip_vary on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

    # Rails 应用
    location / {
        try_files $uri @app;
    }

    location @app {
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Host $host;
        proxy_redirect off;
        proxy_pass http://app;
    }

    # API 路由
    location /api/ {
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Host $host;
        proxy_redirect off;
        proxy_pass http://app;

        # API 特定配置
        proxy_read_timeout 300;
        proxy_connect_timeout 75;
    }

    # 静态文件
    location ~ ^/(assets|packs|uploads)/ {
        root /var/www/qqclub-forum/current/public;
        expires max;
        add_header Cache-Control public;

        # 尝试 Gzip 版本
        gzip_static on;
    }

    # 健康检查
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
```

#### 4. Puma 配置
```ruby
# config/puma.rb
#!/usr/bin/env puma

directory '/var/www/qqclub-forum/current'
environment 'production'

# 监听 Unix socket
bind 'unix:///var/www/qqclub-forum/shared/sockets/puma.sock'

# 进程配置
workers 2
threads 1, 4

# 预加载应用
preload_app!

# PID 文件
pidfile '/var/www/qqclub-forum/shared/pids/puma.pid'

# 状态文件
state_path '/var/www/qqclub-forum/shared/pids/puma.state'

# 日志
stdout_redirect '/var/www/qqclub-forum/shared/log/puma.stdout.log', '/var/www/qqclub-forum/shared/log/puma.stderr.log', true

# 零停机重启
on_restart do
  puts 'On restart...'
end

# 优雅关闭
on_worker_boot do
  require 'active_record'
  ActiveRecord::Base.connection.disconnect! rescue ActiveRecord::ConnectionNotEstablished
  ActiveRecord::Base.establish_connection
end

# 工作进程关闭
on_worker_shutdown do
  require 'active_record'
  ActiveRecord::Base.connection.disconnect!
end
```

---

## 📊 监控与维护

### 系统监控

#### 1. 应用监控配置
```ruby
# config/initializers/monitoring.rb
# Prometheus 指标配置
require 'prometheus_exporter/middleware'

# 自定义指标
POST_COUNTER = PrometheusExporter::Metric::Counter.new(
  "forum_posts_total",
  "Total number of posts created"
)

COMMENT_COUNTER = PrometheusExporter::Metric::Counter.new(
  "forum_comments_total",
  "Total number of comments created"
)

USER_ACTIVE_GAUGE = PrometheusExporter::Metric::Gauge.new(
  "forum_active_users",
  "Number of active users"
)

# 指标收集器
class ForumMetricsCollector < PrometheusExporter::Server::Collector
  def collect(obj)
    case obj[:type]
    when 'post_created'
      POST_COUNTER.observe(1, { category: obj[:category] })
    when 'comment_created'
      COMMENT_COUNTER.observe(1)
    when 'user_activity'
      USER_ACTIVE_GAUGE.set(obj[:count])
    end
  end
end

# 注册收集器
PrometheusExporter::Instrumental.register(ForumMetricsCollector.new)
```

#### 2. 健康检查端点
```ruby
# app/controllers/health_controller.rb
class HealthController < ApplicationController
  skip_before_action :verify_authenticity_token

  def index
    checks = {
      database: check_database,
      redis: check_redis,
      storage: check_storage,
      background_jobs: check_background_jobs
    }

    status = checks.values.all? { |check| check[:status] == "ok" } ? 200 : 503

    render json: {
      status: status == 200 ? "healthy" : "unhealthy",
      checks: checks,
      timestamp: Time.current.iso8601
    }, status: status
  end

  private

  def check_database
    begin
      ActiveRecord::Base.connection.execute("SELECT 1")
      { status: "ok", message: "Database connection successful" }
    rescue => e
      { status: "error", message: e.message }
    end
  end

  def check_redis
    begin
      Redis.current.ping
      { status: "ok", message: "Redis connection successful" }
    rescue => e
      { status: "error", message: e.message }
    end
  end

  def check_storage
    begin
      # 检查文件存储连接
      CloudStorageClient.test_connection
      { status: "ok", message: "Storage connection successful" }
    rescue => e
      { status: "error", message: e.message }
    end
  end

  def check_background_jobs
    begin
      queue_size = Sidekiq::Queue.new.size
      {
        status: queue_size < 1000 ? "ok" : "warning",
        message: "Background jobs queue size: #{queue_size}"
      }
    rescue => e
      { status: "error", message: e.message }
    end
  end
end
```

### 日志管理

#### 1. 结构化日志
```ruby
# config/initializers/lograge.rb
Rails.application.configure do
  config.lograge.enabled = true
  config.lograge.formatter = Lograge::Formatters::Json.new

  config.lograge.custom_payload do |controller|
    {
      user_id: controller.current_user&.id,
      request_id: request.request_id,
      user_agent: request.user_agent,
      remote_ip: request.remote_ip
    }
  end

  config.lograge.custom_options = lambda do |event|
    {
      params: event.payload[:params]&.except("controller", "action", "format", "utf8"),
      duration: event.duration
    }
  end
end

# 论坛专用日志记录器
class ForumLogger
  class << self
    def post_action(action, post, user = nil)
      Rails.logger.info({
        event: "forum_post_action",
        action: action,
        post_id: post.id,
        user_id: user&.id,
        category_id: post.category_id,
        timestamp: Time.current.iso8601
      }.to_json)
    end

    def moderation_action(action, moderator, target, reason = nil)
      Rails.logger.warn({
        event: "forum_moderation_action",
        action: action,
        moderator_id: moderator.id,
        target_type: target.class.name,
        target_id: target.id,
        reason: reason,
        timestamp: Time.current.iso8601
      }.to_json)
    end

    def security_event(event_type, user, details = {})
      Rails.logger.error({
        event: "forum_security_event",
        type: event_type,
        user_id: user&.id,
        ip_address: details[:ip_address],
        user_agent: details[:user_agent],
        details: details,
        timestamp: Time.current.iso8601
      }.to_json)
    end
  end
end
```

### 性能优化

#### 1. 数据库性能监控
```ruby
# app/models/concerns/query_performance_monitor.rb
module QueryPerformanceMonitor
  extend ActiveSupport::Concern

  included do
    # 添加查询性能监控
    def self.with_query_monitoring
      start_time = Time.current
      result = yield
      duration = Time.current - start_time

      if duration > 1.second  # 超过1秒的查询
        Rails.logger.warn({
          event: "slow_query",
          model: name,
          duration: duration,
          query: result.to_sql if result.respond_to?(:to_sql)
        }.to_json)
      end

      result
    end
  end

  class_methods do
    def find_with_monitoring(*args)
      with_query_monitoring { super(*args) }
    end

    def where_with_monitoring(*args)
      with_query_monitoring { super(*args) }
    end
  end
end

# 在关键模型中启用监控
class Post < ApplicationRecord
  include QueryPerformanceMonitor

  # 重写查询方法
  def self.find_by_id(id)
    find_with_monitoring(id)
  end
end
```

#### 2. 缓存监控
```ruby
# app/services/cache_monitor.rb
class CacheMonitor
  class << self
    def track_cache_hit(key, hit: true)
      metric = hit ? :cache_hit : :cache_miss

      Rails.logger.debug({
        event: "cache_access",
        metric: metric,
        key: key,
        timestamp: Time.current.iso8601
      }.to_json)

      # 记录到 Prometheus
      case metric
      when :cache_hit
        Rails.cache.increment("stats:cache_hits")
      when :cache_miss
        Rails.cache.increment("stats:cache_misses")
      end
    end

    def track_cache_write(key, ttl: nil)
      Rails.logger.debug({
        event: "cache_write",
        key: key,
        ttl: ttl,
        timestamp: Time.current.iso8601
      }.to_json)
    end
  end
end

# 重写缓存方法以包含监控
module CacheWithMonitoring
  def read(key, options = nil)
    result = super(key, options)
    CacheMonitor.track_cache_hit(key, hit: result.present?)
    result
  end

  def write(key, value, options = nil)
    CacheMonitor.track_cache_write(key, ttl: options&.dig(:expires_in))
    super(key, value, options)
  end
end

# 在 Rails 初始化时替换缓存客户端
Rails.cache.extend(CacheWithMonitoring)
```

---

## 🔧 故障排除

### 常见问题解决

#### 1. 数据库连接问题
```bash
# 检查数据库连接
rails db:version

# 检查数据库连接池
rails runner "puts ActiveRecord::Base.connection_pool.stat"

# 重启数据库连接
rails runner "ActiveRecord::Base.connection.reconnect!"
```

#### 2. 内存使用过高
```bash
# 检查内存使用
free -h
ps aux --sort=-%mem | head

# 检查 Rails 进程内存
ps aux | grep puma

# 重启应用服务
sudo systemctl restart puma
```

#### 3. 后台任务积压
```bash
# 检查 Sidekiq 队列状态
bundle exec sidekiq-web
# 或使用命令行
bundle exec sidekiqq

# 清理失败任务
bundle exec sidekiqq clear

# 重启 Sidekiq
sudo systemctl restart sidekiq
```

### 应急响应流程

#### 1. 服务宕机处理
```bash
#!/bin/bash
# scripts/emergency_restart.sh

echo "=== 应急重启服务 ==="

# 检查服务状态
systemctl status puma sidekiq nginx

# 重启服务
systemctl restart puma
systemctl restart sidekiq
systemctl reload nginx

# 检查服务重启状态
sleep 10
systemctl status puma sidekiq nginx

# 健康检查
curl -f http://localhost/health || {
  echo "健康检查失败，需要人工介入"
  exit 1
}

echo "=== 应急重启完成 ==="
```

#### 2. 数据库问题处理
```bash
#!/bin/bash
# scripts/database_emergency.sh

echo "=== 数据库应急处理 ==="

# 检查数据库连接
pg_isready -h localhost -p 5432

# 检查数据库连接数
psql -U qqclub -d qqclub_production -c "SELECT count(*) FROM pg_stat_activity;"

# 终止长时间运行的查询
psql -U qqclub -d qqclub_production -c "
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE state = 'active'
AND query_start < now() - interval '5 minutes'
AND pid <> pg_backend_pid();
"

# 重建索引（如果需要）
psql -U qqclub -d qqclub_production -c "REINDEX DATABASE qqclub_production;"

echo "=== 数据库应急处理完成 ==="
```

---

## 📈 性能基准

### 性能指标目标

| 指标 | 目标值 | 当前值 | 监控方式 |
|------|--------|--------|----------|
| API 响应时间 | < 200ms (95%) | - | APM 工具 |
| 数据库查询时间 | < 100ms (95%) | - | 慢查询日志 |
| 页面加载时间 | < 2s (95%) | - | Web Vitals |
| 并发用户数 | 1000+ | - | 负载测试 |
| 系统可用性 | > 99.9% | - | 监控告警 |

### 负载测试

#### 1. API 负载测试
```javascript
// tests/performance/api_load_test.js
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

const errorRate = new Rate('errors');

export let options = {
  stages: [
    { duration: '2m', target: 100 }, // 2分钟内增加到100用户
    { duration: '5m', target: 100 }, // 保持100用户5分钟
    { duration: '2m', target: 200 }, // 2分钟内增加到200用户
    { duration: '5m', target: 200 }, // 保持200用户5分钟
    { duration: '2m', target: 0 },   // 2分钟内减少到0用户
  ],
  thresholds: {
    http_req_duration: ['p(95)<200'], // 95%的请求在200ms内完成
    http_req_failed: ['rate<0.01'],   // 错误率低于1%
    errors: ['rate<0.1'],             // 自定义错误率低于10%
  },
};

export default function () {
  // 获取帖子列表
  let listResponse = http.get('http://localhost:3000/api/posts', {
    headers: { 'Authorization': 'Bearer test_token' }
  });

  let listOk = check(listResponse, {
    '获取帖子列表状态为200': (r) => r.status === 200,
    '获取帖子列表响应时间<200ms': (r) => r.timings.duration < 200,
  });

  errorRate.add(!listOk);

  // 获取帖子详情
  let detailResponse = http.get('http://localhost:3000/api/posts/1', {
    headers: { 'Authorization': 'Bearer test_token' }
  });

  let detailOk = check(detailResponse, {
    '获取帖子详情状态为200': (r) => r.status === 200,
    '获取帖子详情响应时间<200ms': (r) => r.timings.duration < 200,
  });

  errorRate.add(!detailOk);

  sleep(1);
}
```

#### 2. 前端性能测试
```javascript
// tests/performance/frontend_performance.js
const { chromium } = require('playwright');

async function measurePagePerformance() {
  const browser = await chromium.launch();
  const page = await browser.newPage();

  // 监听性能指标
  const metrics = await page.evaluate(() => {
    return new Promise((resolve) => {
      const observer = new PerformanceObserver((list) => {
        const entries = list.getEntries();
        const navigation = entries.find(entry => entry.entryType === 'navigation');
        if (navigation) {
          resolve({
            domContentLoaded: navigation.domContentLoadedEventEnd - navigation.domContentLoadedEventStart,
            loadComplete: navigation.loadEventEnd - navigation.loadEventStart,
            firstPaint: performance.getEntriesByName('first-paint')[0]?.startTime,
            firstContentfulPaint: performance.getEntriesByName('first-contentful-paint')[0]?.startTime,
          });
        }
      });
      observer.observe({ entryTypes: ['navigation', 'paint'] });
    });
  });

  await browser.close();
  return metrics;
}

async function runPerformanceTest() {
  console.log('开始前端性能测试...');

  const metrics = await measurePagePerformance();

  console.log('性能指标:');
  console.log(`DOM 内容加载: ${metrics.domContentLoaded}ms`);
  console.log(`页面完全加载: ${metrics.loadComplete}ms`);
  console.log(`首次绘制: ${metrics.firstPaint}ms`);
  console.log(`首次内容绘制: ${metrics.firstContentfulPaint}ms`);

  // 检查是否符合性能目标
  const targets = {
    domContentLoaded: 1000,
    loadComplete: 2000,
    firstPaint: 800,
    firstContentfulPaint: 1200,
  };

  for (const [metric, target] of Object.entries(targets)) {
    if (metrics[metric] > target) {
      console.warn(`⚠️  ${metric} 超出目标值: ${metrics[metric]}ms > ${target}ms`);
    } else {
      console.log(`✅ ${metric} 符合目标: ${metrics[metric]}ms <= ${target}ms`);
    }
  }
}

runPerformanceTest().catch(console.error);
```

---

## 🔗 相关文档

### 论坛模块内部文档
- **[论坛总览](forum-overview.md)** - 模块整体介绍
- **[论坛业务设计](forum-business.md)** - 业务流程和规则设计
- **[论坛技术设计](forum-technical.md)** - 系统架构和技术实现
- **[论坛API规范](forum-api.md)** - API接口文档
- **[论坛数据库设计](forum-database.md)** - 数据模型和表结构
- **[论坛用户体验设计](forum-ux.md)** - 界面设计和交互流程

### 开发和部署文档
- **[系统架构设计](../../technical/ARCHITECTURE.md)** - 整体技术架构
- **[开发环境搭建](../../development/SETUP_GUIDE.md)** - 本地开发环境配置
- **[部署指南](../../deployment/DEPLOYMENT.md)** - 生产环境部署流程
- **[运维手册](../../operations/OPERATIONS.md)** - 系统运维和监控

---

*本文档最后更新: 2025-10-17*