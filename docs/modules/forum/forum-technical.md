# QQClub 论坛交流模块 - 技术设计

## 📋 文档说明

**目标读者**: 技术负责人、架构师、后端开发者
**文档内容**: 论坛模块的系统架构、核心算法、技术实现细节
**与其他文档关系**: 本文档详细描述技术架构，业务逻辑请参考 [论坛业务设计](forum-business.md)

---

## 🏗️ 系统架构设计

### 整体架构图
```
┌─────────────────────────────────────────────────────┐
│                  前端展示层                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │
│  │   Web应用   │  │   移动端    │  │   管理后台   │  │
│  │   (React)   │  │ (小程序)    │  │   (Admin)   │  │
│  └─────────────┘  └─────────────┘  └─────────────┘  │
└─────────────────────┬───────────────────────────────┘
                      │ HTTP/WebSocket
┌─────────────────────▼───────────────────────────────┐
│                 API网关层                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │
│  │   认证服务   │  │   限流服务   │  │   监控服务   │  │
│  │   (JWT)     │  │  (Redis)    │  │ (Metrics)   │  │
│  └─────────────┘  └─────────────┘  └─────────────┘  │
└─────────────────────┬───────────────────────────────┘
                      │ 内部API调用
┌─────────────────────▼───────────────────────────────┐
│               Ruby on Rails 8 应用层                  │
│  ┌─────────────────────────────────────────────────┐  │
│  │                控制器层 (Controllers)           │  │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐         │  │
│  │  │ 帖子控制器│  │ 评论控制器│  │ 用户控制器│         │  │
│  │  └─────────┘  └─────────┘  └─────────┘         │  │
│  └─────────────────────────────────────────────────┘  │
│  ┌─────────────────────────────────────────────────┐  │
│  │                服务层 (Services)                 │  │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐         │  │
│  │  │ 内容服务 │  │ 审核服务 │  │ 推荐服务 │         │  │
│  │  └─────────┘  └─────────┘  └─────────┘         │  │
│  └─────────────────────────────────────────────────┘  │
│  ┌─────────────────────────────────────────────────┐  │
│  │                模型层 (Models)                    │  │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐         │  │
│  │  │ 帖子模型 │  │ 评论模型 │  │ 用户模型 │         │  │
│  │  └─────────┘  └─────────┘  └─────────┘         │  │
│  └─────────────────────────────────────────────────┘  │
└─────────────────────┬───────────────────────────────┘
                      │ 数据库连接
┌─────────────────────▼───────────────────────────────┐
│                数据存储层                            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │
│  │ PostgreSQL  │  │    Redis    │  │   文件存储   │  │
│  │   (主数据)  │  │   (缓存)    │  │   (OSS)     │  │
│  └─────────────┘  └─────────────┘  └─────────────┘  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │
│  │Elasticsearch│  │  消息队列   │  │   监控日志   │  │
│  │  (搜索)    │  │  (异步)    │  │ (Logging)   │  │
│  └─────────────┘  └─────────────┘  └─────────────┘  │
└─────────────────────────────────────────────────────┘
```

### 技术栈选择

#### 后端技术栈
- **框架**: Ruby on Rails 8
- **数据库**: PostgreSQL 14+ (主数据库)
- **缓存**: Redis 7+ (缓存 + 会话存储)
- **搜索**: Elasticsearch 8+ (全文搜索)
- **消息队列**: Sidekiq + Redis (异步任务)
- **文件存储**: 阿里云OSS (图片、附件)
- **监控**: Prometheus + Grafana

#### 前端技术栈
- **Web端**: React 18 + TypeScript
- **移动端**: 微信小程序原生开发
- **管理后台**: React Admin + Ant Design

---

## 🔧 核心算法设计

### 1. 内容审核算法

#### 敏感词过滤算法
```ruby
class ContentModerationService
  # 敏感词库（示例）
  SENSITIVE_WORDS = %w[
    # 政治敏感词
    # 暴力词汇
    # 违法内容
  ].freeze

  # 基于AC自动机的敏感词检测
  def self.detect_sensitive_words(content)
    return { score: 0, words: [] } if content.blank?

    ac_machine = build_ac_machine(SENSITIVE_WORDS)
    result = ac_machine.search(content)

    {
      score: calculate_sensitivity_score(result[:words]),
      words: result[:words],
      positions: result[:positions]
    }
  end

  private

  def self.build_ac_machine(words)
    # 构建AC自动机
    # 实现略...
  end

  def self.calculate_sensitivity_score(words)
    # 根据敏感词类型和数量计算风险分数
    words.sum { |word| WORD_WEIGHTS[word] || 1 }
  end
end
```

#### 图像内容识别
```ruby
class ImageModerationService
  def self.analyze_image(image_url)
    # 调用AI图像识别服务
    result = AiService.analyze_content(image_url)

    {
      safe: result[:safe],
      categories: result[:categories],
      confidence: result[:confidence],
      actions: determine_actions(result)
    }
  end

  private

  def self.determine_actions(analysis_result)
    actions = []

    if analysis_result[:categories].include?('adult')
      actions << :adult_content
    end

    if analysis_result[:categories].include?('violence')
      actions << :violent_content
    end

    actions
  end
end
```

### 2. 推荐算法

#### 基于内容的推荐
```ruby
class ContentRecommendationService
  def self.recommend_for_user(user_id, limit: 10)
    user = User.find(user_id)

    # 基于用户兴趣标签推荐
    interest_based_posts = find_posts_by_interests(user.interest_tags, limit / 2)

    # 基于用户行为推荐
    behavior_based_posts = find_posts_by_behavior(user, limit / 2)

    # 基于协同过滤推荐
    collaborative_posts = find_posts_by_collaborative_filtering(user, limit / 2)

    # 合并去重并排序
    merge_and_rank_posts(
      interest_based_posts +
      behavior_based_posts +
      collaborative_posts,
      limit
    )
  end

  private

  def self.find_posts_by_interests(interest_tags, limit)
    return Post.none if interest_tags.blank?

    Post.joins(:tags)
        .where(tags: { name: interest_tags })
        .where('posts.created_at > ?', 1.month.ago)
        .order(interactions_count: :desc)
        .limit(limit)
  end

  def self.find_posts_by_behavior(user, limit)
    # 基于用户历史行为（点赞、评论、浏览）
    interacted_posts = user.interactions.pluck(:post_id)

    # 找到与用户互动过的帖子相似的其他帖子
    Post.where.not(id: interacted_posts)
        .joins(:tags)
        .where(tags: { id: user.preferred_tag_ids })
        .order(hot_score: :desc)
        .limit(limit)
  end

  def self.merge_and_rank_posts(posts, limit)
    posts.uniq.sort_by { |post| -post.calculate_recommendation_score }.first(limit)
  end
end
```

### 3. 热度计算算法

```ruby
class HotScoreCalculator
  # 类似Reddit的热度算法
  def self.calculate_score(post)
    return 0 if post.nil?

    # 基础参数
    upvotes = post.likes_count
    downvotes = post.dislikes_count || 0
    comments = post.comments_count
    time_diff = Time.current - post.created_at

    # 热度计算
    score = calculate_hot_score(upvotes, downvotes, comments, time_diff)

    # 更新帖子热度分数
    post.update_column(:hot_score, score)

    score
  end

  private

  def self.calculate_hot_score(upvotes, downvotes, comments, time_diff)
    # 基础分数
    score = upvotes - downvotes

    # 评论权重
    score += comments * 0.5

    # 时间衰减
    time_factor = 1 / (time_diff.to_f / 3600 + 2) ** 1.5

    # 热度分数
    (score * time_factor).round(2)
  end
end
```

### 4. 内容质量评估算法

```ruby
class ContentQualityService
  def self.assess_post_quality(post)
    factors = {
      length_factor: calculate_length_factor(post),
      engagement_factor: calculate_engagement_factor(post),
      originality_factor: calculate_originality_factor(post),
      format_factor: calculate_format_factor(post)
    }

    quality_score = factors.values.sum / factors.size

    {
      score: quality_score.round(2),
      level: determine_quality_level(quality_score),
      factors: factors
    }
  end

  private

  def self.calculate_length_factor(post)
    content_length = post.content.length

    case content_length
    when 0..50
      0.2
    when 51..200
      0.6
    when 201..800
      1.0
    when 801..2000
      0.9
    else
      0.7
    end
  end

  def self.calculate_engagement_factor(post)
    return 0 if post.views_count == 0

    engagement_rate = (post.likes_count + post.comments_count).to_f / post.views_count

    case engagement_rate
    when 0..0.01
      0.2
    when 0.01..0.05
      0.6
    when 0.05..0.15
      1.0
    else
      0.8
    end
  end

  def self.determine_quality_level(score)
    case score
    when 0..0.3
      :low
    when 0.3..0.7
      :medium
    else
      :high
    end
  end
end
```

---

## 🛡️ 安全设计

### 1. 认证与授权

#### JWT Token 管理
```ruby
class AuthenticationService
  JWT_SECRET = Rails.application.credentials.jwt_secret_key
  TOKEN_EXPIRATION = 7.days

  def self.generate_token(user)
    payload = {
      user_id: user.id,
      role: user.role,
      exp: TOKEN_EXPIRATION.from_now.to_i,
      iat: Time.current.to_i,
      jti: SecureRandom.uuid
    }

    JWT.encode(payload, JWT_SECRET, 'HS256')
  end

  def self.verify_token(token)
    decoded = JWT.decode(token, JWT_SECRET, true, algorithm: 'HS256').first

    # 检查token是否在黑名单中
    return nil if TokenBlacklist.exists?(jti: decoded['jti'])

    decoded
  rescue JWT::DecodeError, JWT::ExpiredSignature
    nil
  end

  def self.blacklist_token(token)
    decoded = JWT.decode(token, JWT_SECRET, true, algorithm: 'HS256').first
    TokenBlacklist.create!(
      jti: decoded['jti'],
      expires_at: Time.at(decoded['exp'])
    )
  end
end
```

#### 权限检查中间件
```ruby
class ForumAuthorizer
  def self.can_create_post?(user)
    return false unless user.present?
    return false unless user.verified?

    # 新用户限制
    return false if user.new_user?

    true
  end

  def self.can_moderate_content?(user, content)
    return false unless user.present?

    # 系统管理员可以管理所有内容
    return true if user.system_admin?

    # 社区管理员可以管理所有内容
    return true if user.community_manager?

    # 版主只能管理自己版块的内容
    return true if user.moderator? &&
                     user.moderated_categories.include?(content.category)

    false
  end

  def self.can_edit_content?(user, content)
    return false unless user.present?

    # 作者可以编辑自己的内容
    return true if content.user_id == user.id

    # 管理员可以编辑所有内容
    return true if user.any_admin?

    false
  end
end
```

### 2. 数据验证与防护

#### 输入验证
```ruby
class Post < ApplicationRecord
  include ActionView::Helpers::SanitizeHelper

  validates :title, presence: true, length: { minimum: 5, maximum: 100 }
  validates :content, presence: true, length: { minimum: 10, maximum: 10000 }
  validates :category_id, presence: true

  # 自定义验证
  validate :validate_content_safety
  validate :validate_rate_limit

  private

  def validate_content_safety
    # XSS防护
    sanitized_content = sanitize(content)

    if sanitized_content != content
      errors.add(:content, "包含不安全的内容")
    end

    # 敏感词检测
    moderation_result = ContentModerationService.detect_sensitive_words(content)
    if moderation_result[:score] > 80
      errors.add(:content, "包含敏感内容，请修改后重试")
    end
  end

  def validate_rate_limit
    # 防刷机制
    recent_posts = user.posts.where('created_at > ?', 5.minutes.ago)
    if recent_posts.count >= 3
      errors.add(:base, "发帖过于频繁，请稍后再试")
    end
  end
end
```

#### SQL注入防护
```ruby
class SearchService
  def self.search_posts(query, options = {})
    return Post.none if query.blank?

    # 使用参数化查询
    posts = Post.joins(:user, :category)
                 .where("posts.title ILIKE :query OR posts.content ILIKE :query",
                        query: "%#{sanitize_sql_like(query)}%")

    # 应用过滤条件
    posts = posts.where(category_id: options[:category_id]) if options[:category_id].present?
    posts = posts.where("posts.created_at > ?", options[:created_after]) if options[:created_after].present?

    # 排序
    posts = case options[:sort]
            when 'hot'
              posts.order(hot_score: :desc)
            when 'new'
              posts.order(created_at: :desc)
            else
              posts.order(interactions_count: :desc)
            end

    posts
  end

  private

  def self.sanitize_sql_like(query)
    # 转义SQL LIKE中的特殊字符
    query.gsub(/[%_\\]/) { |char| "\\#{char}" }
  end
end
```

---

## 📊 性能优化

### 1. 数据库优化

#### 索引策略
```sql
-- 帖子表索引
CREATE INDEX idx_posts_category_id ON posts(category_id);
CREATE INDEX idx_posts_user_id ON posts(user_id);
CREATE INDEX idx_posts_status ON posts(status);
CREATE INDEX idx_posts_created_at ON posts(created_at DESC);
CREATE INDEX idx_posts_hot_score ON posts(hot_score DESC);

-- 复合索引
CREATE INDEX idx_posts_category_status ON posts(category_id, status);
CREATE INDEX idx_posts_user_created ON posts(user_id, created_at DESC);

-- 评论表索引
CREATE INDEX idx_comments_post_id ON comments(post_id);
CREATE INDEX idx_comments_user_id ON comments(user_id);
CREATE INDEX idx_comments_created_at ON comments(created_at DESC);

-- 点赞表索引
CREATE INDEX idx_likes_target ON likes(likeable_type, likeable_id);
CREATE INDEX idx_likes_user ON likes(user_id, created_at DESC);
```

#### 查询优化
```ruby
class Post < ApplicationRecord
  # 预加载关联，避免N+1查询
  scope :with_details, -> { includes(:user, :category, :tags, :rich_content) }

  # 分页优化
  scope :paginated, -> (page, per_page = 20) {
    limit(per_page).offset((page - 1) * per_page)
  }

  # 热门帖子查询优化
  scope :hot_posts, -> {
    where(status: :published)
      .where('posts.created_at > ?', 7.days.ago)
      .order(hot_score: :desc)
      .includes(:user, :category)
  }

  def self.search_with_filters(params)
    posts = all

    # 文本搜索（使用全文搜索索引）
    if params[:q].present?
      posts = posts.where("search_vector @@ websearch(to_tsquery('simple', ?))", params[:q])
    end

    # 分类过滤
    if params[:category_id].present?
      posts = posts.where(category_id: params[:category_id])
    end

    # 时间过滤
    if params[:time_range].present?
      time_range = case params[:time_range]
                  when 'day'
                    1.day.ago
                  when 'week'
                    1.week.ago
                  when 'month'
                    1.month.ago
                  else
                    1.year.ago
                  end
      posts = posts.where('posts.created_at > ?', time_range)
    end

    posts
  end
end
```

### 2. 缓存策略

#### 多层缓存设计
```ruby
class ForumCache
  # L1缓存：应用内存缓存（最热数据）
  def self.get_hot_categories
    @hot_categories ||= Rails.cache.fetch('forum:hot_categories', expires_in: 1.hour) do
      Category.where.not(posts_count: 0)
              .order(posts_count: :desc)
              .limit(10)
              .to_a
    end
  end

  # L2缓存：Redis缓存（热点数据）
  def self.get_post_stats(post_id)
    Rails.cache.fetch("forum:post_stats:#{post_id}", expires_in: 10.minutes) do
      post = Post.find(post_id)

      {
        views_count: post.views_count,
        likes_count: post.likes_count,
        comments_count: post.comments_count,
        shares_count: post.shares_count,
        hot_score: post.hot_score
      }
    end
  end

  # L3缓存：数据库查询结果缓存
  def self.get_user_feed(user_id, page = 1)
    cache_key = "forum:user_feed:#{user_id}:page:#{page}"

    Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
      user = User.find(user_id)

      # 个性化推荐逻辑
      recommended_posts = ContentRecommendationService
                           .recommend_for_user(user_id, limit: 20)

      # 按页分割
      recommended_posts.paginated(page, 10)
    end
  end

  # 缓存失效策略
  def self.invalidate_post_cache(post_id)
    Rails.cache.delete("forum:post_stats:#{post_id}")

    # 使相关用户的Feed缓存失效
    post.interactions.pluck(:user_id).each do |user_id|
      (1..5).each do |page|
        Rails.cache.delete("forum:user_feed:#{user_id}:page:#{page}")
      end
    end
  end
end
```

### 3. 异步处理

#### 队列任务设计
```ruby
# 异步内容审核
class ContentModerationJob < ApplicationJob
  queue_as :moderation

  def perform(content_id, content_type)
    content = content_type.constantize.find(content_id)

    # 自动审核
    auto_result = ContentModerationService.auto_moderate(content)

    if auto_result[:safe]
      content.update!(status: :published)
    else
      # 进入人工审核队列
      content.update!(status: :pending_review)
      ManualReviewJob.perform_later(content_id, content_type)
    end

    # 更新用户统计
    UpdateUserStatsJob.perform_later(content.user_id)
  end
end

# 异步热度计算
class HotScoreCalculationJob < ApplicationJob
  queue_as :scoring

  def perform
    # 计算所有帖子的热度分数
    Post.find_in_batches(batch_size: 100) do |posts|
      posts.each do |post|
        score = HotScoreCalculator.calculate_score(post)

        # 更新热门排行
        if score_changed_significantly?(post, score)
          UpdateHotRankingJob.perform_later(post)
        end
      end
    end
  end

  private

  def self.score_changed_significantly?(post, new_score)
    old_score = post.hot_score || 0
    (new_score - old_score).abs > 10
  end
end

# 推荐计算任务
class RecommendationCalculationJob < ApplicationJob
  queue_as :recommendation

  def perform(user_id)
    # 重新计算用户推荐
    user = User.find(user_id)

    # 预计算推荐结果并缓存
    recommendations = ContentRecommendationService
                       .recommend_for_user(user_id, limit: 50)

    Rails.cache.write(
      "forum:user_recommendations:#{user_id}",
      recommendations,
      expires_in: 1.hour
    )
  end
end
```

---

## 📈 监控与日志

### 1. 应用监控

#### 关键指标监控
```ruby
class ForumMetrics
  # 内容创建监控
  def self.track_content_creation(content)
    Rails.logger.info "Content created: #{content.class.name}##{content.id} by User##{content.user_id}"

    # 发送到监控系统
    StatsD.increment('forum.content.created', tags: [
      "type:#{content.class.name.downcase}",
      "category:#{content.category&.name || 'none'}"
    ])

    # 记录内容质量
    quality = ContentQualityService.assess_post_quality(content)
    StatsD.histogram('forum.content.quality', quality[:score])
  end

  # 用户行为监控
  def self.track_user_interaction(user, action, target)
    Rails.logger.info "User interaction: #{user.id} #{action} #{target.class.name}##{target.id}"

    StatsD.increment('forum.user.interaction', tags: [
      "action:#{action}",
      "target:#{target.class.name.downcase}"
    ])
  end

  # 系统性能监控
  def self.track_request_performance(controller, action, duration)
    StatsD.timing('forum.request.duration', duration, tags: [
      "controller:#{controller}",
      "action:#{action}"
    ])

    if duration > 1.second
      Rails.logger.warn "Slow request: #{controller}##{action} took #{duration}s"
    end
  end
end
```

#### 异常监控
```ruby
class ForumErrorHandler
  def self.handle_error(exception, context = {})
    # 记录详细错误信息
    Rails.logger.error "Forum Error: #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n")
    Rails.logger.error "Context: #{context}"

    # 发送到错误监控服务
    if Rails.env.production?
      Raven.capture_exception(exception, {
        extra: context,
        tags: { component: 'forum' }
      })
    end

    # 根据错误类型进行特殊处理
    case exception
    when ActiveRecord::RecordNotFound
      handle_not_found_error(exception, context)
    when ActionController::ParameterMissing
      handle_parameter_error(exception, context)
    when StandardError
      handle_standard_error(exception, context)
    else
      handle_unknown_error(exception, context)
    end
  end

  private

  def self.handle_not_found_error(exception, context)
    Rails.logger.warn "Not found error in #{context[:controller]}##{context[:action]}"
  end

  def self.handle_parameter_error(exception, context)
    Rails.logger.warn "Parameter error in #{context[:controller]}##{context[:action]}: #{exception.message}"
  end
end
```

### 2. 日志管理

#### 结构化日志
```ruby
class ForumLogger
  def self.log_user_action(action, user, details = {})
    log_entry = {
      timestamp: Time.current.iso8601,
      level: 'info',
      service: 'forum',
      action: action,
      user_id: user&.id,
      details: details,
      request_id: Current.request_id
    }

    Rails.logger.info(log_entry.to_json)
  end

  def self.log_moderation_action(action, moderator, target, reason = nil)
    log_entry = {
      timestamp: Time.current.iso8601,
      level: 'info',
      service: 'forum',
      action: "moderation_#{action}",
      moderator_id: moderator&.id,
      target_type: target&.class&.name,
      target_id: target&.id,
      reason: reason,
      request_id: Current.request_id
    }

    Rails.logger.info(log_entry.to_json)
  end

  def self.log_system_event(event, details = {})
    log_entry = {
      timestamp: Time.current.iso8601,
      level: 'info',
      service: 'forum',
      event: event,
      details: details,
      request_id: Current.request_id
    }

    Rails.logger.info(log_entry.to_json)
  end
end
```

---

## 🔄 API设计原则

### 1. RESTful API设计

#### 资源路由
```ruby
# config/routes.rb
Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :categories, only: [:index, :show]
      resources :posts, except: [:new, :edit] do
        member do
          post :like
          delete :unlike
          post :report
          post :share
        end

        resources :comments, only: [:index, :create, :update, :destroy] do
          member do
            post :like
            delete :unlike
            post :report
          end
        end
      end

      resources :users, only: [:show] do
        member do
          get :posts
          get :comments
          get :followers
          get :following
        end
      end

      # 管理员路由
      namespace :admin do
        resources :posts, only: [:index, :update, :destroy] do
          member do
            post :approve
            post :reject
            post :pin
            post :unpin
          end
        end

        resources :categories, except: [:show] do
          member do
            post :assign_moderator
            delete :remove_moderator
          end
        end

        resources :reports, only: [:index, :show, :update]
      end
    end
  end
end
```

### 2. 统一响应格式

#### 成功响应
```ruby
class Api::V1::BaseController < ActionController::API
  private

  def render_success(data: nil, message: '操作成功', meta: {})
    render json: {
      success: true,
      message: message,
      data: data,
      meta: meta
    }
  end

  def render_error(message: '操作失败', errors: [], status: :unprocessable_entity)
    render json: {
      success: false,
      message: message,
      errors: errors
    }, status: status
  end

  def render_pagination(collection, serializer_options = {})
    render(
      json: {
        success: true,
        data: collection.map { |item| serializer_class.new(item).as_json(serializer_options) },
        pagination: {
          current_page: collection.current_page,
          total_pages: collection.total_pages,
          total_count: collection.total_count,
          per_page: collection.limit_value
        }
      }
    )
  end
end
```

---

## 🚀 部署架构

### Docker容器化
```dockerfile
# Dockerfile.forum
FROM ruby:3.1-alpine

# 安装系统依赖
RUN apk add --no-cache build-base postgresql-dev nodejs npm

# 设置工作目录
WORKDIR /app

# 复制依赖文件
COPY Gemfile Gemfile.lock ./
RUN bundle config set --local deployment 'true' && bundle install --without development test

# 复制应用代码
COPY . .

# 预编译资产
RUN SECRET_KEY_BASE_DUMMY=1 RAILS_ENV=production bundle exec rails assets:precompile

# 设置环境变量
ENV RAILS_ENV=production
ENV RAILS_LOG_TO_STDOUT=true
ENV RAILS_SERVE_STATIC_FILES=true

# 启动应用
EXPOSE 3000
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
```

### 服务编排
```yaml
# docker-compose.forum.yml
version: '3.8'

services:
  forum-app:
    build: .
    ports:
      - "3001:3000"
    environment:
      - RAILS_ENV=production
      - DATABASE_URL=postgresql://postgres:password@db:5432/forum_production
      - REDIS_URL=redis://redis:6379/1
      - ELASTICSEARCH_URL=http://elasticsearch:9200
    depends_on:
      - db
      - redis
      - elasticsearch
    volumes:
      - ./log:/app/log
      - ./public/system:/app/public/system

  db:
    image: postgres:14
    environment:
      POSTGRES_DB: forum_production
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: password
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    volumes:
      - redis_data:/data

  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.5.0
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=false
    volumes:
      - elasticsearch_data:/usr/share/elasticsearch/data

volumes:
  postgres_data:
  redis_data:
  elasticsearch_data:
```

---

## 🔗 相关文档

### 论坛模块内部文档
- **[论坛总览](forum-overview.md)** - 模块整体介绍
- **[论坛业务设计](forum-business.md)** - 业务流程和用户角色
- **[论坛用户体验设计](forum-ux.md)** - 界面和交互设计
- **[论坛API规范](forum-api.md)** - API接口文档
- **[论坛数据库设计](forum-database.md)** - 数据模型设计
- **[论坛实施指南](forum-implementation.md)** - 开发和部署指南

### 其他模块文档
- **[共读活动模块](../reading-event/reading-event-technical.md)** - 共读活动技术设计
- **[系统架构设计](../../technical/ARCHITECTURE.md)** - 整体技术架构

---

*本文档最后更新: 2025-10-17*