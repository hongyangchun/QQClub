# QQClub 前端开发指南

## 📋 文档说明

**定位**: QQClub 前端开发完整指南，专注于微信小程序开发和前后端集成
**目标读者**: 前端开发者、全栈开发者、UI/UX设计师
**文档深度**: 详细的前端架构说明、组件设计和API集成指南

---

## 🏗️ 前端架构概览

### 技术栈
- **平台**: 微信小程序原生开发
- **语言**: JavaScript (ES6+)
- **样式**: WXSS + CSS变量
- **架构**: 组件化 + 服务层模式
- **状态管理**: 本地存储 + 全局状态
- **网络请求**: 封装的API服务层

### 目录结构
```
qqclub-miniprogram/
├── app.js                      # 应用入口和全局配置
├── app.json                    # 应用配置和页面路由
├── app.wxss                    # 全局样式和设计系统
├── project.config.json         # 项目配置
├── sitemap.json               # 站点地图配置
├── pages/                     # 页面文件
│   ├── index/                # 首页
│   ├── auth/                 # 登录认证
│   ├── profile/              # 个人中心
│   ├── event/                # 活动管理
│   │   ├── list.js           # 活动列表
│   │   ├── detail.js         # 活动详情
│   │   ├── create.js         # 创建活动
│   │   └── stats.js          # 活动统计
│   └── post/                 # 论坛帖子
│       ├── list.js           # 帖子列表
│       ├── detail.js         # 帖子详情
│       ├── create.js         # 创建帖子
│       └── search.js         # 搜索帖子
├── components/                # 通用组件
│   ├── post-card/            # 帖子卡片
│   ├── user-avatar/          # 用户头像
│   ├── loading/              # 加载组件
│   └── empty-state/          # 空状态组件
├── services/                  # 服务层
│   ├── api.js                # API调用封装
│   ├── auth.js               # 认证服务
│   └── storage.js            # 本地存储
├── utils/                     # 工具函数
│   ├── util.js               # 通用工具函数
│   ├── format.js             # 格式化函数
│   └── constants.js          # 常量定义
└── styles/                    # 样式文件
    ├── variables.wxss        # CSS变量定义
    ├── mixins.wxss           # 样式混入
    └── components.wxss       # 组件样式
```

---

## 🎨 设计系统

### 色彩规范
```css
:root {
  /* 主色调 */
  --primary-color: #7CB342;      /* 主题绿 */
  --primary-light: #9CCC65;       /* 浅绿 */
  --primary-dark: #689F38;        /* 深绿 */

  /* 辅助色 */
  --secondary-color: #8BC34A;     /* 辅助绿 */
  --accent-color: #FFC107;        /* 强调黄 */

  /* 中性色 */
  --text-primary: #212121;        /* 主文本 */
  --text-secondary: #757575;      /* 次要文本 */
  --text-disabled: #BDBDBD;       /* 禁用文本 */

  /* 背景色 */
  --bg-primary: #FFFFFF;          /* 主背景 */
  --bg-secondary: #F5F5F5;        /* 次要背景 */
  --bg-accent: #E8F5E8;           /* 强调背景 */

  /* 状态色 */
  --success-color: #4CAF50;       /* 成功 */
  --warning-color: #FF9800;       /* 警告 */
  --error-color: #F44336;         /* 错误 */
  --info-color: #2196F3;          /* 信息 */
}
```

### 字体规范
```css
/* 字体大小 */
--font-size-xs: 20rpx;    /* 极小 */
--font-size-sm: 24rpx;    /* 小 */
--font-size-base: 28rpx;  /* 基础 */
--font-size-lg: 32rpx;    /* 大 */
--font-size-xl: 36rpx;    /* 极大 */

/* 字体粗细 */
--font-weight-normal: 400;
--font-weight-medium: 500;
--font-weight-bold: 700;
```

### 间距规范
```css
/* 间距系统 */
--spacing-xs: 8rpx;      /* 极小间距 */
--spacing-sm: 16rpx;     /* 小间距 */
--spacing-base: 24rpx;   /* 基础间距 */
--spacing-lg: 32rpx;     /* 大间距 */
--spacing-xl: 48rpx;     /* 极大间距 */
```

### 圆角规范
```css
/* 圆角 */
--border-radius-sm: 8rpx;   /* 小圆角 */
--border-radius-base: 12rpx; /* 基础圆角 */
--border-radius-lg: 16rpx;   /* 大圆角 */
--border-radius-xl: 24rpx;   /* 极大圆角 */
```

---

## 🔌 API集成

### API服务封装
```javascript
// services/api.js
const API_BASE_URL = 'https://api.qqclub.com'

class ApiService {
  constructor() {
    this.baseURL = API_BASE_URL
    this.token = wx.getStorageSync('token') || null
  }

  // 统一请求方法
  request(options) {
    return new Promise((resolve, reject) => {
      const { url, method = 'GET', data = {}, headers = {} } = options

      wx.request({
        url: this.baseURL + url,
        method,
        data,
        header: {
          'Content-Type': 'application/json',
          'Authorization': this.token ? `Bearer ${this.token}` : '',
          ...headers
        },
        success: (res) => {
          if (res.statusCode >= 200 && res.statusCode < 300) {
            resolve(res.data)
          } else {
            this.handleApiError(res)
            reject(res.data)
          }
        },
        fail: (error) => {
          wx.showToast({
            title: '网络请求失败',
            icon: 'error'
          })
          reject(error)
        }
      })
    })
  }

  // 处理API错误
  handleApiError(res) {
    const { statusCode, data } = res

    switch (statusCode) {
      case 401:
        this.handleUnauthorized()
        break
      case 403:
        wx.showToast({ title: '权限不足', icon: 'error' })
        break
      case 404:
        wx.showToast({ title: '资源不存在', icon: 'error' })
        break
      case 422:
        this.handleValidationError(data)
        break
      default:
        wx.showToast({ title: '服务器错误', icon: 'error' })
    }
  }

  // 处理未授权
  handleUnauthorized() {
    wx.removeStorageSync('token')
    wx.removeStorageSync('user')
    wx.reLaunch({
      url: '/pages/auth/auth'
    })
  }

  // 处理验证错误 (v2.0 标准化响应支持)
  handleValidationError(data) {
    if (data.errors && Array.isArray(data.errors)) {
      wx.showToast({
        title: data.errors[0],
        icon: 'error'
      })
    } else if (data.success === false) {
      // v2.0 API标准化响应格式
      wx.showToast({
        title: data.error || '操作失败',
        icon: 'error'
      })
    } else {
      wx.showToast({
        title: data.error || '数据验证失败',
        icon: 'error'
      })
    }
  }
}

export default new ApiService()
```

### 帖子API集成
```javascript
// services/post.js
import api from './api'

export const postService = {
  // 获取帖子列表
  async getPosts(params = {}) {
    const { category, keyword, page = 1, perPage = 10 } = params

    const queryParams = new URLSearchParams({
      page: page.toString(),
      per_page: perPage.toString()
    })

    if (category) queryParams.append('category', category)
    if (keyword) queryParams.append('keyword', keyword)

    return api.request({
      url: `/api/posts?${queryParams.toString()}`,
      method: 'GET'
    })
  },

  // 获取帖子详情
  async getPost(id) {
    return api.request({
      url: `/api/posts/${id}`,
      method: 'GET'
    })
  },

  // 创建帖子
  async createPost(postData) {
    return api.request({
      url: '/api/posts',
      method: 'POST',
      data: { post: postData }
    })
  },

  // 更新帖子
  async updatePost(id, postData) {
    return api.request({
      url: `/api/posts/${id}`,
      method: 'PUT',
      data: { post: postData }
    })
  },

  // 删除帖子
  async deletePost(id) {
    return api.request({
      url: `/api/posts/${id}`,
      method: 'DELETE'
    })
  },

  // 点赞帖子
  async likePost(id) {
    return api.request({
      url: `/api/posts/${id}/like`,
      method: 'POST'
    })
  },

  // 取消点赞
  async unlikePost(id) {
    return api.request({
      url: `/api/posts/${id}/like`,
      method: 'DELETE'
    })
  },

  // 添加评论
  async addComment(postId, content) {
    return api.request({
      url: `/api/posts/${postId}/comments`,
      method: 'POST',
      data: { comment: { content } }
    })
  },

  // 获取评论列表
  async getComments(postId) {
    return api.request({
      url: `/api/posts/${postId}/comments`,
      method: 'GET'
    })
  },

  // 更新评论 (v2.0 新增)
  async updateComment(commentId, content) {
    return api.request({
      url: `/api/comments/${commentId}`,
      method: 'PUT',
      data: { comment: { content } }
    })
  },

  // 删除评论 (v2.0 新增)
  async deleteComment(commentId) {
    return api.request({
      url: `/api/comments/${commentId}`,
      method: 'DELETE'
    })
  }
}

// 打卡评论服务 (v2.0 新增)
export const checkInCommentService = {
  // 获取打卡评论列表
  async getComments(checkInId) {
    return api.request({
      url: `/api/check_ins/${checkInId}/comments`,
      method: 'GET'
    })
  },

  // 添加打卡评论
  async addComment(checkInId, content) {
    return api.request({
      url: `/api/check_ins/${checkInId}/comments`,
      method: 'POST',
      data: { comment: { content } }
    })
  },

  // 更新打卡评论
  async updateComment(commentId, content) {
    return api.request({
      url: `/api/comments/${commentId}`,
      method: 'PUT',
      data: { comment: { content } }
    })
  },

  // 删除打卡评论
  async deleteComment(commentId) {
    return api.request({
      url: `/api/comments/${commentId}`,
      method: 'DELETE'
    })
  }
}
```

---

## 📱 页面开发指南

### 页面生命周期
```javascript
// pages/post/list.js
Page({
  data: {
    posts: [],
    loading: false,
    hasMore: true,
    currentPage: 1,
    selectedCategory: '',
    searchKeyword: ''
  },

  onLoad(options) {
    // 页面加载时执行
    this.loadPosts()
  },

  onShow() {
    // 页面显示时执行
    // 可以刷新数据
  },

  onReachBottom() {
    // 滚动到底部时加载更多
    if (this.data.hasMore && !this.data.loading) {
      this.loadMorePosts()
    }
  },

  onPullDownRefresh() {
    // 下拉刷新
    this.refreshPosts()
  },

  // 加载帖子列表
  async loadPosts() {
    this.setData({ loading: true })

    try {
      const posts = await postService.getPosts({
        category: this.data.selectedCategory,
        keyword: this.data.searchKeyword,
        page: this.data.currentPage
      })

      this.setData({
        posts: this.data.currentPage === 1 ? posts : [...this.data.posts, ...posts],
        hasMore: posts.length === 10,
        loading: false
      })
    } catch (error) {
      this.setData({ loading: false })
      console.error('加载帖子失败:', error)
    }
  },

  // 加载更多帖子
  loadMorePosts() {
    this.setData({
      currentPage: this.data.currentPage + 1
    }, () => {
      this.loadPosts()
    })
  },

  // 刷新帖子
  async refreshPosts() {
    this.setData({
      currentPage: 1,
      posts: []
    })

    await this.loadPosts()
    wx.stopPullDownRefresh()
  },

  // 分类筛选
  onCategoryChange(e) {
    const category = e.currentTarget.dataset.category
    this.setData({
      selectedCategory: category,
      currentPage: 1,
      posts: []
    }, () => {
      this.loadPosts()
    })
  },

  // 搜索帖子
  onSearchInput(e) {
    const keyword = e.detail.value
    this.setData({
      searchKeyword: keyword,
      currentPage: 1,
      posts: []
    }, () => {
      this.loadPosts()
    })
  }
})
```

### 页面模板 (WXML)
```xml
<!-- pages/post/list.wxml -->
<view class="container">
  <!-- 搜索栏 -->
  <view class="search-bar">
    <input
      class="search-input"
      placeholder="搜索帖子..."
      bindinput="onSearchInput"
      value="{{searchKeyword}}"
    />
  </view>

  <!-- 分类筛选 -->
  <scroll-view class="category-tabs" scroll-x="true">
    <view class="tab-list">
      <view
        class="tab-item {{selectedCategory === '' ? 'active' : ''}}"
        bindtap="onCategoryChange"
        data-category=""
      >
        全部
      </view>
      <view
        class="tab-item {{selectedCategory === 'reading' ? 'active' : ''}}"
        bindtap="onCategoryChange"
        data-category="reading"
      >
        读书心得
      </view>
      <view
        class="tab-item {{selectedCategory === 'activity' ? 'active' : ''}}"
        bindtap="onCategoryChange"
        data-category="activity"
      >
        活动讨论
      </view>
      <view
        class="tab-item {{selectedCategory === 'chat' ? 'active' : ''}}"
        bindtap="onCategoryChange"
        data-category="chat"
      >
        闲聊区
      </view>
      <view
        class="tab-item {{selectedCategory === 'help' ? 'active' : ''}}"
        bindtap="onCategoryChange"
        data-category="help"
      >
        求助问答
      </view>
    </view>
  </scroll-view>

  <!-- 帖子列表 -->
  <view class="post-list">
    <block wx:for="{{posts}}" wx:key="id">
      <post-card post="{{item}}" bindtap="onPostTap" />
    </block>
  </view>

  <!-- 加载状态 -->
  <view class="loading-more" wx:if="{{loading}}">
    <text>加载中...</text>
  </view>

  <!-- 没有更多数据 -->
  <view class="no-more" wx:if="{{!hasMore && posts.length > 0}}">
    <text>没有更多内容了</text>
  </view>

  <!-- 空状态 -->
  <empty-state
    wx:if="{{posts.length === 0 && !loading}}"
    icon="post"
    title="暂无帖子"
    description="快来发布第一个帖子吧~"
  />
</view>
```

### 页面样式 (WXSS)
```css
/* pages/post/list.wxss */
.container {
  min-height: 100vh;
  background-color: var(--bg-secondary);
}

.search-bar {
  padding: var(--spacing-base);
  background-color: var(--bg-primary);
  position: sticky;
  top: 0;
  z-index: 10;
}

.search-input {
  width: 100%;
  height: 72rpx;
  padding: 0 var(--spacing-base);
  background-color: var(--bg-secondary);
  border-radius: var(--border-radius-base);
  font-size: var(--font-size-base);
  border: 2rpx solid transparent;
  transition: border-color 0.3s ease;
}

.search-input:focus {
  border-color: var(--primary-color);
}

.category-tabs {
  background-color: var(--bg-primary);
  border-bottom: 1rpx solid #e0e0e0;
}

.tab-list {
  display: flex;
  padding: 0 var(--spacing-base);
  white-space: nowrap;
}

.tab-item {
  padding: var(--spacing-base) var(--spacing-lg);
  font-size: var(--font-size-base);
  color: var(--text-secondary);
  position: relative;
  transition: color 0.3s ease;
}

.tab-item.active {
  color: var(--primary-color);
  font-weight: var(--font-weight-medium);
}

.tab-item.active::after {
  content: '';
  position: absolute;
  bottom: -1rpx;
  left: 50%;
  transform: translateX(-50%);
  width: 40rpx;
  height: 4rpx;
  background-color: var(--primary-color);
  border-radius: 2rpx;
}

.post-list {
  padding: var(--spacing-base);
}

.loading-more,
.no-more {
  text-align: center;
  padding: var(--spacing-lg);
  color: var(--text-secondary);
  font-size: var(--font-size-sm);
}
```

---

## 🧩 组件开发

### 帖子卡片组件
```javascript
// components/post-card/post-card.js
Component({
  properties: {
    post: {
      type: Object,
      value: {}
    }
  },

  methods: {
    onPostTap() {
      this.triggerEvent('tap', {
        post: this.data.post
      })
    },

    onUserTap() {
      // 跳转到用户详情页
      wx.navigateTo({
        url: `/pages/profile/detail?id=${this.data.post.author_info.id}`
      })
    },

    onLikeTap() {
      // 点赞或取消点赞
      this.triggerEvent('like', {
        post: this.data.post,
        liked: !this.data.post.liked_by_current_user
      })
    },

    onCommentTap() {
      // 跳转到评论页
      wx.navigateTo({
        url: `/pages/post/detail?id=${this.data.post.id}&focus=comment`
      })
    },

    formatTimeAgo(timeString) {
      // 格式化相对时间
      const time = new Date(timeString)
      const now = new Date()
      const diff = now - time

      const minutes = Math.floor(diff / 60000)
      const hours = Math.floor(diff / 3600000)
      const days = Math.floor(diff / 86400000)

      if (days > 0) return `${days}天前`
      if (hours > 0) return `${hours}小时前`
      if (minutes > 0) return `${minutes}分钟前`
      return '刚刚'
    },

    onShareTap() {
      // 分享帖子
      this.triggerEvent('share', {
        post: this.data.post
      })
    }
  }
})
```

```xml
<!-- components/post-card/post-card.wxml -->
<view class="post-card" bindtap="onPostTap">
  <!-- 帖子头部 -->
  <view class="post-header">
    <view class="author-info" bindtap="onUserTap">
      <image
        class="author-avatar"
        src="{{post.author_info.avatar_url || '/images/default-avatar.png'}}"
        mode="aspectFill"
      />
      <view class="author-details">
        <view class="author-name">{{post.author_info.nickname}}</view>
        <view class="post-time">{{formatTimeAgo(post.created_at)}}</view>
      </view>
    </view>

    <!-- 分类标签 -->
    <view class="post-category" wx:if="{{post.category}}">
      {{post.category_name}}
    </view>
  </view>

  <!-- 帖子内容 -->
  <view class="post-content">
    <view class="post-title">{{post.title}}</view>
    <view class="post-excerpt">{{post.content}}</view>

    <!-- 图片展示 -->
    <view class="post-images" wx:if="{{post.images && post.images.length > 0}}">
      <image
        wx:for="{{post.images}}"
        wx:key="*this"
        class="post-image"
        src="{{item}}"
        mode="aspectFill"
        bindtap="onImageTap"
        data-src="{{item}}"
      />
    </view>

    <!-- 标签 -->
    <view class="post-tags" wx:if="{{post.tags && post.tags.length > 0}}">
      <view
        class="tag"
        wx:for="{{post.tags}}"
        wx:key="*this"
        wx:if="{{index < 3}}"
      >
        #{{item}}
      </view>
      <view class="tag more" wx:if="{{post.tags.length > 3}}">
        +{{post.tags.length - 3}}
      </view>
    </view>
  </view>

  <!-- 帖子操作栏 -->
  <view class="post-actions">
    <view class="action-item like {{post.liked_by_current_user ? 'liked' : ''}}" bindtap="onLikeTap">
      <text class="icon">{{post.liked_by_current_user ? '❤️' : '🤍'}}</text>
      <text class="count">{{post.likes_count || 0}}</text>
    </view>

    <view class="action-item comment" bindtap="onCommentTap">
      <text class="icon">💬</text>
      <text class="count">{{post.comments_count || 0}}</text>
    </view>

    <view class="action-item share" bindtap="onShareTap">
      <text class="icon">📤</text>
    </view>
  </view>
</view>
```

```css
/* components/post-card/post-card.wxss */
.post-card {
  background-color: var(--bg-primary);
  border-radius: var(--border-radius-base);
  margin-bottom: var(--spacing-base);
  padding: var(--spacing-base);
  box-shadow: 0 2rpx 12rpx rgba(0, 0, 0, 0.08);
  transition: transform 0.2s ease;
}

.post-card:active {
  transform: scale(0.98);
}

.post-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: var(--spacing-base);
}

.author-info {
  display: flex;
  align-items: center;
}

.author-avatar {
  width: 80rpx;
  height: 80rpx;
  border-radius: 50%;
  margin-right: var(--spacing-base);
}

.author-name {
  font-size: var(--font-size-base);
  font-weight: var(--font-weight-medium);
  color: var(--text-primary);
  line-height: 1.4;
}

.post-time {
  font-size: var(--font-size-xs);
  color: var(--text-secondary);
  margin-top: 4rpx;
}

.post-category {
  background-color: var(--primary-color);
  color: white;
  padding: 8rpx 16rpx;
  border-radius: var(--border-radius-sm);
  font-size: var(--font-size-xs);
}

.post-content {
  margin-bottom: var(--spacing-base);
}

.post-title {
  font-size: var(--font-size-lg);
  font-weight: var(--font-weight-medium);
  color: var(--text-primary);
  margin-bottom: var(--spacing-sm);
  line-height: 1.4;
}

.post-excerpt {
  font-size: var(--font-size-base);
  color: var(--text-secondary);
  line-height: 1.6;
  display: -webkit-box;
  -webkit-line-clamp: 3;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.post-images {
  display: flex;
  flex-wrap: wrap;
  gap: var(--spacing-sm);
  margin: var(--spacing-sm) 0;
}

.post-image {
  width: calc(33.33% - 8rpx);
  height: 200rpx;
  border-radius: var(--border-radius-sm);
}

.post-tags {
  display: flex;
  flex-wrap: wrap;
  gap: var(--spacing-sm);
  margin-top: var(--spacing-sm);
}

.tag {
  background-color: var(--bg-accent);
  color: var(--primary-color);
  padding: 4rpx 12rpx;
  border-radius: var(--border-radius-sm);
  font-size: var(--font-size-xs);
}

.tag.more {
  background-color: var(--bg-secondary);
  color: var(--text-secondary);
}

.post-actions {
  display: flex;
  justify-content: space-around;
  padding-top: var(--spacing-base);
  border-top: 1rpx solid #f0f0f0;
}

.action-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: var(--spacing-sm);
  border-radius: var(--border-radius-sm);
  transition: background-color 0.2s ease;
}

.action-item:active {
  background-color: var(--bg-secondary);
}

.action-item.liked .icon {
  color: #ff4757;
}

.action-item .icon {
  font-size: 36rpx;
  margin-bottom: 4rpx;
}

.action-item .count {
  font-size: var(--font-size-xs);
  color: var(--text-secondary);
}
```

---

## 🔧 工具函数

### 通用工具函数
```javascript
// utils/util.js

/**
 * 防抖函数
 * @param {Function} func - 要防抖的函数
 * @param {number} wait - 等待时间（毫秒）
 * @returns {Function} 防抖后的函数
 */
export function debounce(func, wait) {
  let timeout
  return function executedFunction(...args) {
    const later = () => {
      clearTimeout(timeout)
      func(...args)
    }
    clearTimeout(timeout)
    timeout = setTimeout(later, wait)
  }
}

/**
 * 节流函数
 * @param {Function} func - 要节流的函数
 * @param {number} limit - 限制间隔（毫秒）
 * @returns {Function} 节流后的函数
 */
export function throttle(func, limit) {
  let inThrottle
  return function executedFunction(...args) {
    if (!inThrottle) {
      func(...args)
      inThrottle = true
      setTimeout(() => inThrottle = false, limit)
    }
  }
}

/**
 * 格式化日期
 * @param {Date|string} date - 日期
 * @param {string} format - 格式化模式
 * @returns {string} 格式化后的日期字符串
 */
export function formatDate(date, format = 'YYYY-MM-DD') {
  const d = new Date(date)
  const year = d.getFullYear()
  const month = String(d.getMonth() + 1).padStart(2, '0')
  const day = String(d.getDate()).padStart(2, '0')
  const hours = String(d.getHours()).padStart(2, '0')
  const minutes = String(d.getMinutes()).padStart(2, '0')
  const seconds = String(d.getSeconds()).padStart(2, '0')

  return format
    .replace('YYYY', year)
    .replace('MM', month)
    .replace('DD', day)
    .replace('HH', hours)
    .replace('mm', minutes)
    .replace('ss', seconds)
}

/**
 * 获取相对时间
 * @param {Date|string} date - 日期
 * @returns {string} 相对时间字符串
 */
export function getTimeAgo(date) {
  const now = new Date()
  const target = new Date(date)
  const diff = now - target

  const minute = 60 * 1000
  const hour = minute * 60
  const day = hour * 24
  const month = day * 30
  const year = day * 365

  if (diff < minute) {
    return '刚刚'
  } else if (diff < hour) {
    return Math.floor(diff / minute) + '分钟前'
  } else if (diff < day) {
    return Math.floor(diff / hour) + '小时前'
  } else if (diff < month) {
    return Math.floor(diff / day) + '天前'
  } else if (diff < year) {
    return Math.floor(diff / month) + '个月前'
  } else {
    return Math.floor(diff / year) + '年前'
  }
}

/**
 * 截取文本
 * @param {string} text - 原始文本
 * @param {number} length - 最大长度
 * @param {string} suffix - 后缀
 * @returns {string} 截取后的文本
 */
export function truncateText(text, length = 100, suffix = '...') {
  if (text.length <= length) return text
  return text.substring(0, length) + suffix
}

/**
 * 安全的JSON解析
 * @param {string} str - JSON字符串
 * @param {any} defaultValue - 默认值
 * @returns {any} 解析结果或默认值
 */
export function safeJSONParse(str, defaultValue = null) {
  try {
    return JSON.parse(str)
  } catch (e) {
    return defaultValue
  }
}

/**
 * 生成随机ID
 * @param {number} length - ID长度
 * @returns {string} 随机ID
 */
export function generateId(length = 8) {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
  let result = ''
  for (let i = 0; i < length; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length))
  }
  return result
}

/**
 * 检查是否为空值
 * @param {any} value - 要检查的值
 * @returns {boolean} 是否为空
 */
export function isEmpty(value) {
  if (value === null || value === undefined) return true
  if (typeof value === 'string') return value.trim().length === 0
  if (Array.isArray(value)) return value.length === 0
  if (typeof value === 'object') return Object.keys(value).length === 0
  return false
}

/**
 * 深拷贝对象
 * @param {any} obj - 要拷贝的对象
 * @returns {any} 拷贝后的对象
 */
export function deepClone(obj) {
  if (obj === null || typeof obj !== 'object') return obj
  if (obj instanceof Date) return new Date(obj.getTime())
  if (obj instanceof Array) return obj.map(item => deepClone(item))

  const cloned = {}
  for (const key in obj) {
    if (obj.hasOwnProperty(key)) {
      cloned[key] = deepClone(obj[key])
    }
  }
  return cloned
}
```

### 格式化函数
```javascript
// utils/format.js

/**
 * 格式化文件大小
 * @param {number} bytes - 字节数
 * @returns {string} 格式化后的文件大小
 */
export function formatFileSize(bytes) {
  if (bytes === 0) return '0 Bytes'

  const k = 1024
  const sizes = ['Bytes', 'KB', 'MB', 'GB']
  const i = Math.floor(Math.log(bytes) / Math.log(k))

  return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i]
}

/**
 * 格式化数字
 * @param {number} num - 数字
 * @returns {string} 格式化后的数字字符串
 */
export function formatNumber(num) {
  if (num >= 1000000) {
    return (num / 1000000).toFixed(1) + 'M'
  } else if (num >= 1000) {
    return (num / 1000).toFixed(1) + 'K'
  }
  return num.toString()
}

/**
 * 格式化金额
 * @param {number} amount - 金额
 * @param {string} currency - 货币符号
 * @returns {string} 格式化后的金额字符串
 */
export function formatAmount(amount, currency = '¥') {
  return currency + parseFloat(amount).toFixed(2)
}

/**
 * 格式化手机号
 * @param {string} phone - 手机号
 * @returns {string} 格式化后的手机号
 */
export function formatPhone(phone) {
  if (!phone || phone.length !== 11) return phone
  return phone.replace(/(\d{3})(\d{4})(\d{4})/, '$1 $2 $3')
}

/**
 * 格式化百分比
 * @param {number} value - 数值 (0-1)
 * @param {number} decimals - 小数位数
 * @returns {string} 百分比字符串
 */
export function formatPercentage(value, decimals = 1) {
  return (value * 100).toFixed(decimals) + '%'
}
```

---

## 📱 状态管理

### 全局状态管理
```javascript
// app.js
App({
  globalData: {
    user: null,
    token: null,
    systemInfo: null,
    theme: 'light'
  },

  onLaunch() {
    this.initApp()
  },

  onShow() {
    // 更新系统信息
    this.updateSystemInfo()
  },

  // 初始化应用
  initApp() {
    this.loadUserInfo()
    this.updateSystemInfo()
    this.checkUpdate()
  },

  // 加载用户信息
  loadUserInfo() {
    const token = wx.getStorageSync('token')
    const user = wx.getStorageSync('user')

    if (token && user) {
      this.globalData.token = token
      this.globalData.user = user
    }
  },

  // 更新系统信息
  updateSystemInfo() {
    wx.getSystemInfo({
      success: (res) => {
        this.globalData.systemInfo = res

        // 设置状态栏高度
        const { statusBarHeight, platform } = res
        this.globalData.statusBarHeight = statusBarHeight

        // 设置自定义导航栏高度
        if (platform === 'ios') {
          this.globalData.navBarHeight = 44 + statusBarHeight
        } else {
          this.globalData.navBarHeight = 48 + statusBarHeight
        }
      }
    })
  },

  // 检查更新
  checkUpdate() {
    if (wx.canIUse('getUpdateManager')) {
      const updateManager = wx.getUpdateManager()

      updateManager.onCheckForUpdate((res) => {
        if (res.hasUpdate) {
          updateManager.onUpdateReady(() => {
            wx.showModal({
              title: '更新提示',
              content: '新版本已经准备好，是否重启应用？',
              success: (res) => {
                if (res.confirm) {
                  updateManager.applyUpdate()
                }
              }
            })
          })

          updateManager.onUpdateFailed(() => {
            wx.showModal({
              title: '更新失败',
              content: '新版本下载失败，请检查网络后重试',
              showCancel: false
            })
          })
        }
      })
    }
  },

  // 更新用户信息
  updateUserInfo(user) {
    this.globalData.user = user
    wx.setStorageSync('user', user)
  },

  // 更新Token
  updateToken(token) {
    this.globalData.token = token
    wx.setStorageSync('token', token)
  },

  // 清除用户信息
  clearUserInfo() {
    this.globalData.user = null
    this.globalData.token = null
    wx.removeStorageSync('user')
    wx.removeStorageSync('token')
  },

  // 显示错误信息
  showError(message) {
    wx.showToast({
      title: message,
      icon: 'error',
      duration: 3000
    })
  },

  // 显示成功信息
  showSuccess(message) {
    wx.showToast({
      title: message,
      icon: 'success',
      duration: 2000
    })
  },

  // 显示加载信息
  showLoading(message = '加载中...') {
    wx.showLoading({
      title: message,
      mask: true
    })
  },

  // 隐藏加载信息
  hideLoading() {
    wx.hideLoading()
  }
})
```

---

## 💬 评论系统实现 (v2.0 新增)

### 评论组件设计

#### 评论列表组件
```javascript
// components/comment-list/comment-list.js
Component({
  properties: {
    comments: {
      type: Array,
      value: []
    },
    targetId: {
      type: String,
      value: ''
    },
    targetType: {
      type: String,
      value: 'post' // 'post' 或 'check_in'
    },
    readonly: {
      type: Boolean,
      value: false
    }
  },

  data: {
    showEditModal: false,
    editingComment: null,
    editContent: ''
  },

  methods: {
    // 点赞评论
    onLikeComment(e) {
      const { comment } = e.currentTarget.dataset
      this.triggerEvent('like', { comment })
    },

    // 编辑评论
    onEditComment(e) {
      const { comment } = e.currentTarget.dataset
      if (comment.can_edit_current_user) {
        this.setData({
          showEditModal: true,
          editingComment: comment,
          editContent: comment.content
        })
      }
    },

    // 删除评论
    onDeleteComment(e) {
      const { comment } = e.currentTarget.dataset
      wx.showModal({
        title: '确认删除',
        content: '确定要删除这条评论吗？',
        success: (res) => {
          if (res.confirm) {
            this.triggerEvent('delete', { comment })
          }
        }
      })
    },

    // 提交编辑
    onSubmitEdit() {
      const { editingComment, editContent } = this.data
      if (editContent.trim().length < 2) {
        wx.showToast({
          title: '评论内容至少2个字符',
          icon: 'error'
        })
        return
      }

      this.triggerEvent('update', {
        comment: editingComment,
        content: editContent.trim()
      })

      this.setData({
        showEditModal: false,
        editingComment: null,
        editContent: ''
      })
    },

    // 取消编辑
    onCancelEdit() {
      this.setData({
        showEditModal: false,
        editingComment: null,
        editContent: ''
      })
    },

    // 格式化时间
    formatTimeAgo(timeString) {
      const time = new Date(timeString)
      const now = new Date()
      const diff = now - time

      const minutes = Math.floor(diff / 60000)
      const hours = Math.floor(diff / 3600000)
      const days = Math.floor(diff / 86400000)

      if (days > 0) return `${days}天前`
      if (hours > 0) return `${hours}小时前`
      if (minutes > 0) return `${minutes}分钟前`
      return '刚刚'
    }
  }
})
```

#### 评论输入组件
```javascript
// components/comment-input/comment-input.js
Component({
  properties: {
    placeholder: {
      type: String,
      value: '写下你的评论...'
    },
    disabled: {
      type: Boolean,
      value: false
    }
  },

  data: {
    content: '',
    inputFocus: false
  },

  methods: {
    // 输入内容变化
    onInputChange(e) {
      this.setData({
        content: e.detail.value
      })
    },

    // 获得焦点
    onInputFocus() {
      this.setData({
        inputFocus: true
      })
    },

    // 失去焦点
    onInputBlur() {
      this.setData({
        inputFocus: false
      })
    },

    // 提交评论
    onSubmitComment() {
      const content = this.data.content.trim()
      if (content.length < 2) {
        wx.showToast({
          title: '评论内容至少2个字符',
          icon: 'error'
        })
        return
      }

      if (content.length > 1000) {
        wx.showToast({
          title: '评论内容不能超过1000字符',
          icon: 'error'
        })
        return
      }

      this.triggerEvent('submit', { content })

      // 清空输入
      this.setData({
        content: ''
      })
    }
  }
})
```

### 页面集成示例

#### 帖子详情页评论集成
```javascript
// pages/post/detail.js
import { postService } from '../../services/post'

Page({
  data: {
    post: null,
    comments: [],
    loading: false,
    hasMore: true,
    currentPage: 1
  },

  onLoad(options) {
    const { id } = options
    this.postId = id
    this.loadPostDetail()
    this.loadComments()
  },

  // 加载帖子详情
  async loadPostDetail() {
    try {
      const post = await postService.getPost(this.postId)
      this.setData({ post })
    } catch (error) {
      console.error('加载帖子失败:', error)
    }
  },

  // 加载评论列表
  async loadComments() {
    if (this.data.loading || !this.data.hasMore) return

    this.setData({ loading: true })

    try {
      const response = await postService.getComments(this.postId)
      const comments = response.data || response // 兼容v2.0标准化响应

      this.setData({
        comments: this.data.currentPage === 1 ? comments : [...this.data.comments, ...comments],
        hasMore: comments.length === 10,
        loading: false
      })
    } catch (error) {
      this.setData({ loading: false })
      console.error('加载评论失败:', error)
    }
  },

  // 提交评论
  async onSubmitComment(e) {
    const { content } = e.detail

    try {
      const response = await postService.addComment(this.postId, content)
      const newComment = response.data || response.comment // 兼容v2.0响应格式

      // 添加到评论列表开头
      this.setData({
        comments: [newComment, ...this.data.comments]
      })

      wx.showToast({
        title: '评论成功',
        icon: 'success'
      })
    } catch (error) {
      console.error('评论失败:', error)
    }
  },

  // 更新评论
  async onUpdateComment(e) {
    const { comment, content } = e.detail

    try {
      await postService.updateComment(comment.id, content)

      // 更新本地评论
      const comments = this.data.comments.map(c =>
        c.id === comment.id ? { ...c, content } : c
      )
      this.setData({ comments })

      wx.showToast({
        title: '更新成功',
        icon: 'success'
      })
    } catch (error) {
      console.error('更新评论失败:', error)
    }
  },

  // 删除评论
  async onDeleteComment(e) {
    const { comment } = e.detail

    try {
      await postService.deleteComment(comment.id)

      // 从本地列表移除
      const comments = this.data.comments.filter(c => c.id !== comment.id)
      this.setData({ comments })

      wx.showToast({
        title: '删除成功',
        icon: 'success'
      })
    } catch (error) {
      console.error('删除评论失败:', error)
    }
  },

  // 点赞帖子
  async onLikePost() {
    try {
      const response = this.data.post.liked_by_current_user
        ? await postService.unlikePost(this.postId)
        : await postService.likePost(this.postId)

      // 更新帖子状态
      this.setData({
        'post.liked_by_current_user': !this.data.post.liked_by_current_user,
        'post.likes_count': response.likes_count || (this.data.post.likes_count + (this.data.post.liked_by_current_user ? -1 : 1))
      })
    } catch (error) {
      console.error('点赞失败:', error)
    }
  }
})
```

#### 打卡评论集成
```javascript
// pages/event/detail.js (打卡页面)
import { checkInCommentService } from '../../services/post'

Page({
  data: {
    checkIns: [],
    selectedCheckIn: null,
    showCommentModal: false
  },

  // 显示打卡评论
  onShowComments(e) {
    const { checkIn } = e.currentTarget.dataset
    this.setData({
      selectedCheckIn: checkIn,
      showCommentModal: true
    })
    this.loadCheckInComments(checkIn.id)
  },

  // 加载打卡评论
  async loadCheckInComments(checkInId) {
    try {
      const response = await checkInCommentService.getComments(checkInId)
      const comments = response.data || response

      this.setData({
        [`checkIns[${this.findCheckInIndex(checkInId)}].comments`]: comments
      })
    } catch (error) {
      console.error('加载打卡评论失败:', error)
    }
  },

  // 提交打卡评论
  async onSubmitCheckInComment(e) {
    const { content } = e.detail
    const { selectedCheckIn } = this.data

    try {
      const response = await checkInCommentService.addComment(selectedCheckIn.id, content)
      const newComment = response.data || response

      // 添加到评论列表
      const checkInIndex = this.findCheckInIndex(selectedCheckIn.id)
      const checkIns = [...this.data.checkIns]
      const currentComments = checkIns[checkInIndex].comments || []
      checkIns[checkInIndex].comments = [newComment, ...currentComments]

      this.setData({ checkIns })

      wx.showToast({
        title: '评论成功',
        icon: 'success'
      })
    } catch (error) {
      console.error('评论失败:', error)
    }
  },

  // 查找打卡索引
  findCheckInIndex(checkInId) {
    return this.data.checkIns.findIndex(checkIn => checkIn.id === checkInId)
  },

  // 关闭评论模态框
  onCloseCommentModal() {
    this.setData({
      showCommentModal: false,
      selectedCheckIn: null
    })
  }
})
```

### 评论组件模板

#### 评论列表模板
```xml
<!-- components/comment-list/comment-list.wxml -->
<view class="comment-list">
  <view class="comment-item" wx:for="{{comments}}" wx:key="id">
    <!-- 用户头像和信息 -->
    <view class="comment-header">
      <image
        class="user-avatar"
        src="{{item.author_info.avatar_url || '/images/default-avatar.png'}}"
        mode="aspectFill"
      />
      <view class="user-info">
        <view class="user-name">{{item.author_info.nickname}}</view>
        <view class="comment-time">{{formatTimeAgo(item.created_at)}}</view>
      </view>

      <!-- 操作按钮 -->
      <view class="comment-actions" wx:if="{{!readonly && item.can_edit_current_user}}">
        <text class="action-btn edit" bindtap="onEditComment" data-comment="{{item}}">编辑</text>
        <text class="action-btn delete" bindtap="onDeleteComment" data-comment="{{item}}">删除</text>
      </view>
    </view>

    <!-- 评论内容 -->
    <view class="comment-content">{{item.content}}</view>
  </view>

  <!-- 空状态 -->
  <view class="empty-comments" wx:if="{{comments.length === 0}}">
    <text>暂无评论，快来发表第一条评论吧~</text>
  </view>
</view>

<!-- 编辑评论模态框 -->
<view class="modal-mask" wx:if="{{showEditModal}}" bindtap="onCancelEdit">
  <view class="edit-modal" catchtap="">
    <view class="modal-header">
      <text>编辑评论</text>
      <text class="close-btn" bindtap="onCancelEdit">×</text>
    </view>
    <textarea
      class="edit-textarea"
      placeholder="请输入评论内容..."
      value="{{editContent}}"
      bindinput="onEditInputChange"
      maxlength="1000"
      auto-focus
    />
    <view class="modal-footer">
      <button class="cancel-btn" bindtap="onCancelEdit">取消</button>
      <button class="submit-btn" bindtap="onSubmitEdit">确认</button>
    </view>
  </view>
</view>
```

### 评论组件样式
```css
/* components/comment-list/comment-list.wxss */
.comment-list {
  padding: var(--spacing-base);
}

.comment-item {
  margin-bottom: var(--spacing-lg);
  padding-bottom: var(--spacing-base);
  border-bottom: 1rpx solid #f0f0f0;
}

.comment-item:last-child {
  margin-bottom: 0;
  border-bottom: none;
}

.comment-header {
  display: flex;
  align-items: center;
  margin-bottom: var(--spacing-sm);
}

.user-avatar {
  width: 60rpx;
  height: 60rpx;
  border-radius: 50%;
  margin-right: var(--spacing-sm);
}

.user-info {
  flex: 1;
}

.user-name {
  font-size: var(--font-size-base);
  font-weight: var(--font-weight-medium);
  color: var(--text-primary);
}

.comment-time {
  font-size: var(--font-size-xs);
  color: var(--text-secondary);
  margin-top: 4rpx;
}

.comment-actions {
  display: flex;
  gap: var(--spacing-sm);
}

.action-btn {
  font-size: var(--font-size-xs);
  padding: 8rpx 16rpx;
  border-radius: var(--border-radius-sm);
}

.action-btn.edit {
  color: var(--primary-color);
  background-color: var(--bg-accent);
}

.action-btn.delete {
  color: var(--error-color);
  background-color: #ffebee;
}

.comment-content {
  font-size: var(--font-size-base);
  color: var(--text-primary);
  line-height: 1.6;
  margin-left: 80rpx;
}

.empty-comments {
  text-align: center;
  padding: var(--spacing-xl);
  color: var(--text-secondary);
  font-size: var(--font-size-sm);
}

/* 编辑模态框样式 */
.modal-mask {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background-color: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
}

.edit-modal {
  width: 600rpx;
  background-color: var(--bg-primary);
  border-radius: var(--border-radius-lg);
  padding: var(--spacing-lg);
}

.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: var(--spacing-base);
  font-size: var(--font-size-lg);
  font-weight: var(--font-weight-medium);
}

.close-btn {
  font-size: 48rpx;
  color: var(--text-secondary);
  line-height: 1;
}

.edit-textarea {
  width: 100%;
  min-height: 200rpx;
  padding: var(--spacing-base);
  border: 2rpx solid #e0e0e0;
  border-radius: var(--border-radius-base);
  font-size: var(--font-size-base);
  line-height: 1.6;
}

.modal-footer {
  display: flex;
  justify-content: flex-end;
  gap: var(--spacing-base);
  margin-top: var(--spacing-lg);
}

.cancel-btn, .submit-btn {
  padding: var(--spacing-sm) var(--spacing-lg);
  border-radius: var(--border-radius-base);
  font-size: var(--font-size-base);
}

.cancel-btn {
  background-color: var(--bg-secondary);
  color: var(--text-secondary);
}

.submit-btn {
  background-color: var(--primary-color);
  color: white;
}
```

---

## 🧪 测试和调试

### 小程序调试技巧

#### 1. 使用Console调试
```javascript
// 在页面中使用console.log
console.log('调试信息:', this.data)
console.warn('警告信息:', warningData)
console.error('错误信息:', errorData)

// 查看API响应
api.request(options).then(res => {
  console.log('API响应:', res)
})
```

#### 2. 使用微信开发者工具调试
- 打开调试面板查看网络请求
- 使用WXML面板检查DOM结构
- 使用Storage面板查看本地存储
- 使用Performance面板分析性能

#### 3. 真机调试
```javascript
// vConsole插件 - 在真机上调试
import vconsole from 'vconsole'

if (process.env.NODE_ENV === 'development') {
  new vconsole()
}
```

### 性能优化建议

#### 1. 图片优化
```javascript
// 图片懒加载
Component({
  behaviors: ['wx://component-export'],
  properties: {
    src: String,
    lazy: {
      type: Boolean,
      value: true
    }
  },

  observers: {
    'lazy, src'(lazy, src) {
      if (!lazy) {
        this.loadImage(src)
      }
    }
  },

  methods: {
    loadImage(src) {
      // 加载图片逻辑
    }
  }
})
```

#### 2. 数据缓存
```javascript
// utils/cache.js
class Cache {
  set(key, data, expire = 3600000) { // 默认1小时
    try {
      const item = {
        data,
        expire: Date.now() + expire
      }
      wx.setStorageSync(key, item)
    } catch (e) {
      console.error('缓存设置失败:', e)
    }
  }

  get(key) {
    try {
      const item = wx.getStorageSync(key)
      if (!item) return null

      if (Date.now() > item.expire) {
        wx.removeStorageSync(key)
        return null
      }

      return item.data
    } catch (e) {
      console.error('缓存读取失败:', e)
      return null
    }
  }

  remove(key) {
    wx.removeStorageSync(key)
  }

  clear() {
    wx.clearStorageSync()
  }
}

export default new Cache()
```

#### 3. 分包加载
```javascript
// app.json
{
  "subpackages": [
    {
      "root": "packages/activity",
      "pages": [
        "pages/list/list",
        "pages/detail/detail",
        "pages/create/create"
      ]
    },
    {
      "root": "packages/forum",
      "pages": [
        "pages/list/list",
        "pages/detail/detail",
        "pages/create/create"
      ]
    }
  ],
  "preloadRule": {
    "pages/index/index": {
      "network": "all",
      "packages": ["activity"]
    }
  }
}
```

---

## 🚀 部署和发布

### 小程序发布流程

#### 1. 代码检查
```bash
# 运行测试
npm run test

# 代码检查
npm run lint

# 构建优化
npm run build
```

#### 2. 版本管理
```javascript
// project.config.json
{
  "setting": {
    "urlCheck": true,
    "es6": true,
    "postcss": true,
    "minified": true
  },
  "appid": "your-app-id",
  "projectname": "QQClub",
  "libVersion": "2.19.4"
}
```

#### 3. 上传发布
1. 在微信开发者工具中点击"上传"
2. 填写版本号和项目备注
3. 选择代码包大小优化
4. 确认上传并等待审核

### 持续集成配置

#### GitHub Actions配置
```yaml
# .github/workflows/miniprogram.yml
name: MiniProgram Build

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v2

    - name: Setup Node.js
      uses: actions/setup-node@v2
      with:
        node-version: '16'

    - name: Install dependencies
      run: npm install

    - name: Run tests
      run: npm test

    - name: Build
      run: npm run build

    - name: Upload artifacts
      uses: actions/upload-artifact@v2
      with:
        name: build-files
        path: dist/
```

---

## 📚 相关文档

- [微信小程序开发文档](https://developers.weixin.qq.com/miniprogram/dev/framework/)
- [小程序设计规范](https://developers.weixin.qq.com/miniprogram/design/)
- [API接口文档](../technical/API_REFERENCE.md)
- [权限系统指南](../technical/PERMISSIONS_GUIDE.md)
- [测试框架指南](../technical/TESTING_GUIDE.md)

---

## 🆘 获取帮助

### 官方资源
- **微信开放文档**: https://developers.weixin.qq.com/miniprogram/dev/framework/
- **微信开发者工具**: https://developers.weixin.qq.com/miniprogram/dev/devtools/download.html
- **小程序社区**: https://developers.weixin.qq.com/community/

### 开发工具
- **微信开发者工具**: 官方IDE
- **VS Code**: 支持小程序插件
- **WebStorm**: 支持小程序开发

---

*本文档最后更新: 2025-10-16*