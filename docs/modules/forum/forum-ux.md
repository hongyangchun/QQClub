# QQClub 论坛交流模块 - 用户体验设计

## 📋 文档说明

**目标读者**: UI/UX设计师、产品设计师、前端开发者
**文档内容**: 论坛模块的用户界面设计、交互流程、组件规范
**与其他文档关系**: 本文档详细描述界面设计，业务逻辑请参考 [论坛业务设计](forum-business.md)

---

## 🎨 设计原则

### 核心原则
- **简洁明了**: 界面简洁，信息层次清晰
- **易于操作**: 操作流程简单，降低学习成本
- **激励引导**: 通过视觉设计激励用户参与
- **社区氛围**: 营造温馨友好的讨论氛围

### 设计风格
- **色调**: 温暖的社区色调，以蓝色、绿色为主
- **字体**: 清晰易读的无衬线字体
- **图标**: 简洁的线性图标风格
- **动效**: 轻柔的过渡动画，提升体验感

---

## 📱 页面结构设计

### 整体布局
```
┌─────────────────────────────────────────────┐
│              页面头部                    │
│    [←] 论坛首页  [搜索] [发布] [通知]       │
├─────────────────────────────────────┬─────────┤
│                                     │         │
│              内容区域                    │  侧边栏  │
│                                     │         │
│            (动态内容区域)            │  热门话题 │
│                                     │  活跃用户 │
│                                     │  最新动态 │
│                                     │         │
├─────────────────────────────────────┴─────────┤
│              页面底部                    │
│    [首页] [发现] [消息] [我的]           │
└─────────────────────────────────────────────┘
```

### 导航设计
```css
/* 主导航栏样式 */
.forum-header {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  position: sticky;
  top: 0;
  z-index: 1000;
}

.nav-item {
  color: rgba(255, 255, 255, 0.8);
  transition: all 0.3s ease;
  font-weight: 500;
}

.nav-item:hover,
.nav-item.active {
  color: white;
  text-decoration: none;
}

.nav-item.active {
  border-bottom: 2px solid white;
}
```

---

## 📝 核心功能界面设计

### 1. 论坛首页设计

#### 首页布局
```xml
<!-- 论坛首页模板 -->
<view class="forum-home">
  <!-- 搜索栏 -->
  <view class="search-section">
    <view class="search-container">
      <input class="search-input" placeholder="搜索帖子、用户、话题..." />
      <button class="search-btn">🔍</button>
    </view>
  </view>

  <!-- 分类导航 -->
  <view class="category-nav">
    <scroll-view scroll-x="true" class="category-scroll">
      <view class="category-item {{currentCategory === 'all' ? 'active' : ''}}"
            bindtap="selectCategory" data-category="all">
        <text class="category-name">全部</text>
      </view>
      <view class="category-item {{currentCategory === category.id ? 'active' : ''}}"
            wx:for="{{categories}}" wx:key="id"
            bindtap="selectCategory" data-category="{{category.id}}">
        <image class="category-icon" src="{{category.icon}}" />
        <text class="category-name">{{category.name}}</text>
        <view class="category-count">{{category.posts_count}}</view>
      </view>
    </scroll-view>
  </view>

  <!-- 内容区域 -->
  <view class="content-section">
    <!-- 置顶帖子 -->
    <view class="pinned-posts" wx:if="{{pinnedPosts.length > 0}}">
      <view class="section-header">
        <text class="section-title">📌 置顶帖子</text>
      </view>
      <view class="pinned-post-list">
        <view class="pinned-post" wx:for="{{pinnedPosts}}" wx:key="id"
              bindtap="navigateToPost" data-id="{{item.id}}">
          <view class="post-header">
            <image class="author-avatar" src="{{item.author.avatar_url}}" />
            <view class="post-meta">
              <text class="author-name">{{item.author.nickname}}</text>
              <text class="post-time">{{item.created_at}}</text>
            </view>
            <view class="pinned-badge">📌</view>
          </view>
          <view class="post-title">{{item.title}}</view>
          <view class="post-excerpt">{{item.excerpt}}</view>
          <view class="post-stats">
            <text class="stat-item">👍 {{item.likes_count}}</text>
            <text class="stat-item">💬 {{item.comments_count}}</text>
            <text class="stat-item">👁 {{item.views_count}}</text>
          </view>
        </view>
      </view>
    </view>

    <!-- 热门帖子 -->
    <view class="hot-posts">
      <view class="section-header">
        <text class="section-title">🔥 热门帖子</text>
        <text class="sort-btn" bindtap="toggleSortOptions">{{sortText}}</text>
      </view>
      <view class="post-list">
        <view class="post-item" wx:for="{{posts}}" wx:key="id"
              bindtap="navigateToPost" data-id="{{item.id}}">
          <view class="post-header">
            <image class="author-avatar" src="{{item.author.avatar_url}}" />
            <view class="post-meta">
              <text class="author-name">{{item.author.nickname}}</text>
              <text class="post-level">{{item.author.level}}</text>
              <text class="post-time">{{item.created_at}}</text>
            </view>
            <view class="quality-badge" wx:if="{{item.quality_score >= 0.8}}">优质</view>
          </view>
          <view class="post-title">{{item.title}}</view>
          <view class="post-content">
            <text class="post-excerpt">{{item.excerpt}}</text>
          </view>
          <view class="post-tags" wx:if="{{item.tags.length > 0}}">
            <view class="tag" wx:for="{{item.tags}}" wx:key="id"
                  wx:for-item="tag" style="background-color: {{tag.color}};">
              <text class="tag-text">{{tag.name}}</text>
            </view>
          </view>
          <view class="post-stats">
            <view class="stat-item">
              <text class="stat-icon">👍</text>
              <text class="stat-count">{{item.likes_count}}</text>
            </view>
            <view class="stat-item">
              <text class="stat-icon">💬</text>
              <text class="stat-count">{{item.comments_count}}</text>
            </view>
            <view class="stat-item">
              <text class="stat-icon">👁</text>
              <text class="stat-count">{{item.views_count}}</text>
            </view>
            <view class="stat-item">
              <text class="stat-icon">🔥</text>
              <text class="stat-count">{{item.hot_score}}</text>
            </view>
          </view>
        </view>
      </view>
    </view>
  </view>
</view>
```

#### 样式规范
```css
/* 论坛首页样式 */
.forum-home {
  background: #f8f9fa;
  min-height: 100vh;
}

.search-section {
  background: white;
  padding: 16px;
  margin-bottom: 12px;
}

.search-container {
  display: flex;
  align-items: center;
  background: #f1f3f5;
  border-radius: 25px;
  padding: 0 16px;
}

.search-input {
  flex: 1;
  height: 44px;
  border: none;
  background: transparent;
  font-size: 16px;
}

.search-btn {
  width: 44px;
  height: 44px;
  border: none;
  background: transparent;
  font-size: 18px;
  border-radius: 22px;
}

.category-nav {
  background: white;
  padding: 12px 0;
  margin-bottom: 12px;
}

.category-scroll {
  white-space: nowrap;
  padding: 0 16px;
}

.category-item {
  display: inline-flex;
  flex-direction: column;
  align-items: center;
  padding: 8px 16px;
  margin-right: 8px;
  border-radius: 8px;
  transition: all 0.3s ease;
}

.category-item.active {
  background: #e3f2fd;
  border-color: #2196f3;
}

.category-icon {
  width: 24px;
  height: 24px;
  margin-bottom: 4px;
}

.category-name {
  font-size: 12px;
  color: #666;
  margin-bottom: 2px;
}

.category-count {
  font-size: 10px;
  color: #999;
}

.post-item {
  background: white;
  border-radius: 12px;
  padding: 16px;
  margin-bottom: 12px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.05);
  transition: all 0.3s ease;
}

.post-item:active {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
}

.post-header {
  display: flex;
  align-items: center;
  margin-bottom: 12px;
}

.author-avatar {
  width: 40px;
  height: 40px;
  border-radius: 20px;
  margin-right: 12px;
}

.post-meta {
  flex: 1;
}

.author-name {
  font-size: 14px;
  font-weight: 600;
  color: #333;
}

.post-level {
  font-size: 12px;
  color: #667eea;
  background: #e3f2fd;
  padding: 2px 6px;
  border-radius: 4px;
  margin-left: 8px;
}

.post-time {
  font-size: 12px;
  color: #999;
  margin-top: 2px;
}

.quality-badge {
  background: linear-gradient(135deg, #ffd700, #ffb300);
  color: white;
  font-size: 10px;
  padding: 2px 6px;
  border-radius: 4px;
  margin-left: 8px;
  font-weight: 600;
}

.post-title {
  font-size: 16px;
  font-weight: 600;
  color: #333;
  margin-bottom: 8px;
  line-height: 1.4;
}

.post-excerpt {
  font-size: 14px;
  color: #666;
  line-height: 1.5;
  margin-bottom: 12px;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.post-tags {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  margin-bottom: 12px;
}

.tag {
  padding: 4px 8px;
  border-radius: 4px;
  font-size: 12px;
  color: white;
  font-weight: 500;
}

.tag-text {
  color: white;
}

.post-stats {
  display: flex;
  gap: 16px;
  align-items: center;
}

.stat-item {
  display: flex;
  align-items: center;
  gap: 4px;
}

.stat-icon {
  font-size: 14px;
}

.stat-count {
  font-size: 12px;
  color: #666;
}
```

### 2. 发帖界面设计

#### 发帖表单
```xml
<!-- 发帖页面模板 -->
<view class="create-post">
  <view class="form-header">
    <text class="page-title">发布帖子</text>
  </view>

  <view class="form-container">
    <!-- 标题输入 -->
    <view class="form-group">
      <view class="form-label">
        <text class="required">*</text>
        <text>标题</text>
      </view>
      <input class="form-input"
             placeholder="请输入帖子标题，5-100个字符"
             maxlength="100"
             bindinput="onTitleInput"
             value="{{postTitle}}" />
      <view class="char-count">{{postTitle.length}}/100</view>
    </view>

    <!-- 分类选择 -->
    <view class="form-group">
      <view class="form-label">
        <text class="required">*</text>
        <text>分类</text>
      </view>
      <view class="category-selector" bindtap="showCategoryPicker">
        <text class="selected-category">
          {{selectedCategory ? selectedCategory.name : '请选择分类'}}
        </text>
        <text class="dropdown-arrow">▼</text>
      </view>
    </view>

    <!-- 内容编辑器 -->
    <view class="form-group">
      <view class="form-label">
        <text class="required">*</text>
        <text>内容</text>
      </view>
      <view class="content-editor">
        <textarea class="content-textarea"
                  placeholder="分享你的想法，至少10个字符..."
                  maxlength="10000"
                  bindinput="onContentInput"
                  value="{{postContent}}"></textarea>
        <view class="editor-toolbar">
          <button class="toolbar-btn" bindtap="insertEmoji">😊</button>
          <button class="toolbar-btn" bindtap="insertImage">📷</button>
          <button class="toolbar-btn" bindtap="insertLink">🔗</button>
          <button class="toolbar-btn" bindtap="insertCode">💻</button>
        </view>
      </view>
      <view class="char-count">{{postContent.length}}/10000</view>
    </view>

    <!-- 标签选择 -->
    <view class="form-group">
      <view class="form-label">
        <text>标签</text>
      </view>
      <view class="tag-input-container">
        <view class="selected-tags" wx:if="{{selectedTags.length > 0}}">
          <view class="selected-tag" wx:for="{{selectedTags}}" wx:key="id">
            <text class="tag-text">{{tag.name}}</text>
            <text class="remove-tag" bindtap="removeTag" data-id="{{tag.id}}">×</text>
          </view>
        </view>
        <input class="tag-input"
               placeholder="添加标签，按回车确认"
               bindinput="onTagInput"
               value="{{tagInput}}" />
      </view>
      <view class="popular-tags" wx:if="{{popularTags.length > 0}}">
        <text class="tags-title">热门标签：</text>
        <view class="tags-list">
          <view class="popular-tag" wx:for="{{popularTags}}" wx:key="id"
                bindtap="addPopularTag" data-tag="{{tag}}">
            <text class="tag-text">{{tag.name}}</text>
          </view>
        </view>
      </view>
    </view>

    <!-- 附件上传 -->
    <view class="form-group">
      <view class="form-label">
        <text>附件</text>
      </view>
      <view class="attachment-upload">
        <view class="upload-area" bindtap="chooseImage">
          <text class="upload-icon">📷</text>
          <text class="upload-text">点击上传图片</text>
        </view>
        <view class="attachment-list" wx:if="{{attachments.length > 0}}">
          <view class="attachment-item" wx:for="{{attachments}}" wx:key="temp_id">
            <image class="attachment-preview" src="{{item.url}}" mode="aspectFill" />
            <view class="attachment-info">
              <text class="attachment-name">{{item.filename}}</text>
              <text class="attachment-size">{{item.size}}</text>
            </view>
            <view class="attachment-actions">
              <text class="remove-btn" bindtap="removeAttachment" data-id="{{item.temp_id}}">删除</text>
            </view>
          </view>
        </view>
      </view>
    </view>

    <!-- 发帖按钮 -->
    <view class="form-actions">
      <button class="btn-secondary" bindtap="saveDraft">保存草稿</button>
      <button class="btn-primary {{canSubmit ? '' : 'disabled'}}"
              bindtap="submitPost"
              disabled="{{!canSubmit}}">
        {{submitting ? '发布中...' : '发布帖子'}}
      </button>
    </view>
  </view>
</view>
```

#### 样式规范
```css
/* 发帖页面样式 */
.create-post {
  background: #f8f9fa;
  min-height: 100vh;
  padding-bottom: 80px;
}

.form-header {
  background: white;
  padding: 20px;
  border-bottom: 1px solid #e9ecef;
  text-align: center;
}

.page-title {
  font-size: 18px;
  font-weight: 600;
  color: #333;
}

.form-container {
  padding: 20px;
}

.form-group {
  background: white;
  border-radius: 12px;
  padding: 16px;
  margin-bottom: 16px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.05);
}

.form-label {
  display: flex;
  align-items: center;
  margin-bottom: 8px;
  font-size: 14px;
  font-weight: 600;
  color: #333;
}

.required {
  color: #f44336;
  margin-right: 4px;
}

.form-input {
  width: 100%;
  height: 44px;
  border: 1px solid #ddd;
  border-radius: 6px;
  padding: 0 12px;
  font-size: 16px;
  transition: border-color 0.3s ease;
}

.form-input:focus {
  border-color: #667eea;
  outline: none;
  box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
}

.char-count {
  text-align: right;
  font-size: 12px;
  color: #999;
  margin-top: 4px;
}

.category-selector {
  display: flex;
  justify-content: space-between;
  align-items: center;
  height: 44px;
  border: 1px solid #ddd;
  border-radius: 6px;
  padding: 0 12px;
  background: white;
}

.selected-category {
  flex: 1;
  color: #333;
}

.dropdown-arrow {
  color: #666;
  transition: transform 0.3s ease;
}

.content-editor {
  border: 1px solid #ddd;
  border-radius: 6px;
  overflow: hidden;
}

.content-textarea {
  width: 100%;
  min-height: 200px;
  border: none;
  padding: 12px;
  font-size: 16px;
  line-height: 1.5;
  resize: vertical;
}

.editor-toolbar {
  display: flex;
  border-top: 1px solid #eee;
  background: #f8f9fa;
  padding: 8px;
  gap: 8px;
}

.toolbar-btn {
  padding: 6px 12px;
  border: 1px solid #ddd;
  border-radius: 4px;
  background: white;
  font-size: 14px;
  transition: all 0.3s ease;
}

.toolbar-btn:active {
  background: #e3f2fd;
  border-color: #2196f3;
}

.selected-tags {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-bottom: 8px;
}

.selected-tag {
  display: flex;
  align-items: center;
  background: #e3f2fd;
  border: 1px solid #2196f3;
  border-radius: 16px;
  padding: 4px 8px 4px 4px;
}

.tag-text {
  color: #1976d2;
  font-size: 12px;
  margin-right: 4px;
}

.remove-tag {
  color: #f44336;
  font-size: 14px;
  padding-left: 4px;
}

.tag-input {
  flex: 1;
  min-height: 32px;
  border: 1px solid #ddd;
  border-radius: 6px;
  padding: 6px 12px;
  font-size: 14px;
}

.popular-tags {
  margin-top: 12px;
}

.tags-title {
  font-size: 12px;
  color: #666;
  margin-bottom: 8px;
}

.tags-list {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}

.popular-tag {
  background: #f1f3f5;
  border: 1px solid #ddd;
  border-radius: 16px;
  padding: 4px 8px;
  transition: all 0.3s ease;
}

.popular-tag:active {
  background: #e3f2fd;
  border-color: #2196f3;
}

.upload-area {
  border: 2px dashed #ddd;
  border-radius: 8px;
  padding: 40px 20px;
  text-align: center;
  transition: all 0.3s ease;
}

.upload-area:active {
  border-color: #667eea;
  background: #f8f9ff;
}

.upload-icon {
  font-size: 32px;
  margin-bottom: 8px;
}

.upload-text {
  color: #666;
  font-size: 14px;
}

.btn-primary {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  border: none;
  border-radius: 25px;
  padding: 12px 24px;
  font-size: 16px;
  font-weight: 600;
  transition: all 0.3s ease;
}

.btn-primary:active {
  transform: scale(0.98);
  box-shadow: 0 2px 8px rgba(102, 126, 234, 0.4);
}

.btn-primary.disabled {
  background: #ccc;
  transform: none;
  box-shadow: none;
}

.btn-secondary {
  background: white;
  color: #667eea;
  border: 2px solid #667eea;
  border-radius: 25px;
  padding: 12px 24px;
  font-size: 16px;
  font-weight: 600;
  transition: all 0px ease;
}

.btn-secondary:active {
  background: #f0f4ff;
}
```

### 3. 帖子详情页设计

#### 详情页布局
```xml
<!-- 帖子详情页模板 -->
<view class="post-detail">
  <!-- 帖子头部 -->
  <view class="post-header">
    <view class="post-category">
      <image class="category-icon" src="{{post.category.icon}}" />
      <text class="category-name">{{post.category.name}}</text>
    </view>
    <view class="post-actions">
      <button class="action-btn" bindtap="toggleLike"
              class="{{post.is_liked ? 'liked' : ''}}">
        <text class="action-icon">{{post.is_liked ? '❤️' : '👍'}}</text>
        <text class="action-text">{{post.likes_count}}</text>
      </button>
      <button class="action-btn" bindtap="sharePost">
        <text class="action-icon">🔗</text>
        <text class="action-text">分享</text>
      </button>
      <button class="action-btn" bindtap="showMoreActions">
        <text class="action-icon">⋯</text>
      </button>
    </view>
  </view>

  <!-- 帖子内容 -->
  <view class="post-content">
    <view class="post-title-section">
      <text class="post-title">{{post.title}}</text>
      <view class="post-meta">
        <image class="author-avatar" src="{{post.author.avatar_url}}" />
        <view class="author-info">
          <text class="author-name">{{post.author.nickname}}</text>
          <view class="post-meta-details">
            <text class="meta-item">{{post.author.level}}</text>
            <text class="meta-item">{{post.created_at}}</text>
            <view class="quality-indicator">
              <text class="quality-score">{{post.quality_score}}</text>
              <text class="quality-label">质量评分</text>
            </view>
          </view>
        </view>
      </view>
    </view>

    <view class="post-body">
      <rich-text nodes="{{post.content_nodes}}"></rich-text>
    </view>

    <!-- 附件展示 -->
    <view class="post-attachments" wx:if="{{post.attachments.length > 0}}">
      <view class="attachments-grid">
        <view class="attachment-item" wx:for="{{post.attachments}}" wx:key="id"
              bindtap="previewAttachment" data-id="{{item.id}}">
          <image class="attachment-image"
                 src="{{item.url}}"
                 mode="aspectFit"
                 binderror="onAttachmentError" />
          <view class="attachment-info">
            <text class="attachment-name">{{item.filename}}</text>
            <text class="attachment-size">{{item.size}}</text>
          </view>
        </view>
      </view>
    </view>

    <!-- 标签 -->
    <view class="post-tags" wx:if="{{post.tags.length > 0}}">
      <view class="tags-list">
        <view class="tag" wx:for="{{post.tags}}" wx:key="id"
              style="background-color: {{tag.color}};">
          <text class="tag-text">{{tag.name}}</text>
        </view>
      </view>
    </view>
  </view>

  <!-- 统计信息 -->
  <view class="post-stats">
    <view class="stat-item">
      <text class="stat-icon">👁</text>
      <text class="stat-label">浏览</text>
      <text class="stat-value">{{post.views_count}}</text>
    </view>
    <view class="stat-item">
      <text class="stat-icon">👍</text>
      <text class="stat-label">点赞</text>
      <text class="stat-value">{{post.likes_count}}</text>
    </view>
    <view class="stat-item">
      <text class="stat-icon">💬</text>
      <text class="stat-label">评论</text>
      <text class="stat-value">{{post.comments_count}}</text>
    </view>
    <view class="stat-item">
      <text class="stat-icon">🔥</text>
      <text class="stat-label">热度</text>
      <text class="stat-value">{{post.hot_score}}</text>
    </view>
  </view>

  <!-- 评论区 -->
  <view class="comments-section">
    <view class="section-header">
      <text class="section-title">评论 ({{post.comments_count}})</text>
      <button class="write-comment-btn" bindtap="scrollToCommentInput">
        <text>写评论</text>
      </button>
    </view>

    <view class="comments-list">
      <!-- 评论项目 -->
      <view class="comment-item" wx:for="{{comments}}" wx:key="id">
        <view class="comment-header">
          <image class="commenter-avatar" src="{{comment.author.avatar_url}}" />
          <view class="commenter-info">
            <text class="commenter-name">{{comment.author.nickname}}</text>
            <text class="comment-time">{{comment.created_at}}</text>
          </view>
          <view class="comment-actions">
            <button class="like-btn" bindtap="likeComment" data-id="{{comment.id}}"
                    class="{{comment.is_liked ? 'liked' : ''}}">
              <text class="like-icon">{{comment.is_liked ? '❤️' : '👍'}}</text>
              <text class="like-count">{{comment.likes_count}}</text>
            </button>
            <button class="reply-btn" bindtap="replyComment" data-id="{{comment.id}}">
              <text>回复</text>
            </button>
            <button class="more-btn" bindtap="showCommentActions">
              <text>⋯</text>
            </button>
          </view>
        </view>
        <view class="comment-content">
          <text class="comment-text">{{comment.content}}</text>
        </view>

        <!-- 回复列表 -->
        <view class="replies-list" wx:if="{{comment.replies.length > 0}}">
          <view class="reply-item" wx:for="{{comment.replies}}" wx:key="id">
            <image class="replier-avatar" src="{{reply.author.avatar_url}}" />
            <view class="reply-content">
              <text class="replier-name">{{reply.author.nickname}}：</text>
              <text class="reply-text">{{reply.content}}</text>
            </view>
          </view>
        </view>
      </view>
    </view>

    <!-- 评论输入框 -->
    <view class="comment-input-section" wx:if="{{showCommentInput}}">
      <view class="comment-input-container">
        <image class="user-avatar" src="{{currentUser.avatar_url}}" />
        <textarea class="comment-input"
                  placeholder="写下你的评论..."
                  bindinput="onCommentInput"
                  value="{{commentContent}}"
                  bindfocus="onCommentFocus"
                  bindblur="onCommentBlur"></textarea>
        <button class="send-btn {{canSendComment ? '' : 'disabled'}}"
                bindtap="submitComment"
                disabled="{{!canSendComment}}">
          <text>{{sendingComment ? '发送中...' : '发送'}}</text>
        </button>
      </view>
    </view>
  </view>
</view>
```

---

## 🎨 组件设计规范

### 1. 按钮组件

#### 主要按钮
```css
.btn-primary {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  border-radius: 25rpx;
  padding: 24rpx 48rpx;
  font-size: 28rpx;
  font-weight: 600;
  box-shadow: 0 4rpx 15rpx rgba(102, 126, 234, 0.4);
  transition: all 0.3s ease;
}

.btn-primary:active {
  transform: scale(0.98);
  box-shadow: 0 2rpx 8rpx rgba(102, 126, 234, 0.4);
}
```

#### 次要按钮
```css
.btn-secondary {
  background: white;
  color: #667eea;
  border: 2rpx solid #667eea;
  border-radius: 25rpx;
  padding: 24rpx 48rpx;
  font-size: 28rpx;
  font-weight: 600;
  transition: all 0.3s ease;
}

.btn-secondary:active {
  background: #f0f4ff;
}
```

### 2. 卡片组件

```css
.post-card {
  background: white;
  border-radius: 20rpx;
  padding: 32rpx;
  margin-bottom: 24rpx;
  box-shadow: 0 4rpx 20rpx rgba(0, 0, 0, 0.08);
  transition: all 0.3s ease;
}

.post-card:active {
  transform: translateY(-2rpx);
  box-shadow: 0 6rpx 25rpx rgba(0, 0, 0, 0.12);
}
```

### 3. 表单组件

```css
.form-input {
  background: #f8f9fa;
  border: 2rpx solid #e9ecef;
  border-radius: 12rpx;
  padding: 24rpx;
  font-size: 28rpx;
  transition: all 0.3s ease;
}

.form-input:focus {
  border-color: #667eea;
  background: white;
  box-shadow: 0 0 20rpx rgba(102, 126, 234, 0.1);
}
```

---

## 🌈 视觉设计系统

### 色彩规范

#### 主色调
```css
:root {
  --primary-color: #667eea;
  --primary-light: #8b9dff;
  --primary-dark: #4c63d2;
  --secondary-color: #48bb78;
  --accent-color: #ffd93d;
}
```

#### 中性色
```css
:root {
  --text-primary: #2d3748;
  --text-secondary: #718096;
  --text-hint: #a0aec0;
  --background-primary: #ffffff;
  --background-secondary: #f7fafc;
  --border-color: #e2e8f0;
}
```

#### 功能色
```css
:root {
  --success-color: #48bb78;
  --warning-color: #ed8936;
  --error-color: #f56565;
  --info-color: #4299e1;
}
```

### 字体规范

#### 字体大小
```css
:root {
  --font-size-xs: 20rpx;
  --font-size-sm: 24rpx;
  --font-size-base: 28rpx;
  --font-size-lg: 32rpx;
  --font-size-xl: 36rpx;
  --font-size-2xl: 42rpx;
}
```

#### 字体权重
```css
:root {
  --font-weight-normal: 400;
  --font-weight-medium: 500;
  --font-weight-semibold: 600;
  --font-weight-bold: 700;
}
```

### 间距规范
```css
:root {
  --spacing-xs: 8rpx;
  --spacing-sm: 16rpx;
  --spacing-md: 24rpx;
  --spacing-lg: 32rpx;
  --spacing-xl: 48rpx;
  --spacing-2xl: 64rpx;
}
```

---

## 📱 响应式设计

### 断点设置
```css
/* 小屏幕手机 */
@media (max-width: 750rpx) {
  .post-item {
    padding: 24rpx;
    margin-bottom: 16rpx;
  }

  .post-stats {
    flex-wrap: wrap;
    gap: 12rpx;
  }
}

/* 大屏幕手机/小平板 */
@media (min-width: 751rpx) {
  .content-section {
    display: flex;
    gap: 24rpx;
  }

  .main-content {
    flex: 2;
  }

  .sidebar {
    flex: 1;
  }
}
```

### 安全区域适配
```css
.safe-area-bottom {
  height: env(safe-area-inset-bottom);
  background: white;
}

.safe-area-top {
  height: env(safe-area-inset-top);
  background: white;
}
```

---

## 🎯 交互设计

### 状态反馈
- **加载状态**: 骨架屏或加载指示器
- **成功状态**: 绿色提示 + 成功动画
- **错误状态**: 红色提示 + 错误说明
- **空状态**: 友好的空状态插画和引导

### 微交互
- **按钮点击**: 轻微缩放效果
- **卡片悬停**: 阴影变化和上移
- **表单聚焦**: 边框颜色变化和阴影
- **页面切换**: 淡入淡出效果

### 手势操作
- **下拉刷新**: 列表页面
- **左右滑动**: 卡片操作（如删除）
- **长按**: 显示更多操作选项
- **双击**: 点赞或收藏

---

## ♿ 无障碍设计

### 可访问性
- **色彩对比**: 确保文字与背景对比度 ≥ 4.5:1
- **字体大小**: 最小字体不小于 20rpx
- **触摸区域**: 按钮最小触摸区域 88rpx × 88rpx
- **焦点指示**: 清晰的焦点状态指示

### 语义化
- **标题层级**: 正确的标题层级结构
- **表单标签**: 所有输入框都有对应标签
- **替代文本**: 图片都有有意义的替代文本
- **状态通知**: 重要状态变化有通知提示

---

## 📱️ 移动端优化

### 小程序适配
```javascript
// 微信小程序适配策略
const forumApp = {
  // 分页加载
  onReachBottom: function() {
    if (this.currentPage < this.totalPages && !this.loading) {
      this.loadMorePosts();
    }
  },

  // 分享功能
  onShareAppMessage: function() {
    return {
      title: this.post.title,
      path: `/pages/forum/detail?id=${this.post.id}`,
      imageUrl: this.post.attachments[0]?.url
    };
  },

  // 页面分享
  onShareTimeline: function() {
    return {
      title: this.post.title,
      query: `id=${this.post.id}`
    };
  }
};
```

### 性能优化
```javascript
// 图片懒加载
const imageLoader = {
  lazy: true,
  fadein: true,
  placeholder: '/images/placeholder.png'
};

// 列表虚拟滚动
const virtualList = {
  height: 600,
  itemHeight: 200,
  bufferSize: 10
};

// 预加载关键数据
const preloader = {
  cache: true,
  preloadNextPage: true
};
```

---

## 🔗 相关文档

### 论坛模块内部文档
- **[论坛总览](forum-overview.md)** - 模块整体介绍
- **[论坛业务设计](forum-business.md)** - 业务流程和用户角色
- **[论坛技术设计](forum-technical.md)** - 技术架构和实现
- **[论坛API规范](forum-api.md)** - API接口文档
- **[论坛数据库设计](forum-database.md)** - 数据模型设计
- **[论坛实施指南](forum-implementation.md)** - 开发和部署指南

### 其他模块文档
- **[共读活动模块](../reading-event/reading-event-ux.md)** - 共读活动界面设计
- **[系统架构设计](../../technical/ARCHITECTURE.md)** - 整体技术架构
- **[开发环境搭建](../../development/SETUP_GUIDE.md)** - 开发环境配置

---

*本文档最后更新: 2025-10-17*