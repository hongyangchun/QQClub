# QQClub 共读活动模块 - 用户体验设计

## 📋 文档说明

**目标读者**: UI/UX设计师、产品设计师、前端开发者
**文档内容**: 用户界面设计、交互流程、组件规范

---

## 🎨 设计原则

### 核心原则
- **简洁明了**: 界面简洁，信息层次清晰
- **易于操作**: 操作流程简单，降低学习成本
- **激励引导**: 通过视觉设计激励用户参与
- **情感化设计**: 营造温馨的读书氛围

### 设计风格
- **色调**: 温暖的书香色调，以深蓝、米白为主
- **字体**: 清晰易读的无衬线字体
- **图标**: 简洁的线性图标风格
- **动效**: 轻柔的过渡动画，提升体验感

---

## 📱 页面结构设计

### 整体布局
```
┌─────────────────────────────────────┐
│              页面头部                │
│    [←] 页面标题  [功能按钮]           │
├─────────────────────────────────────┤
│                                     │
│              内容区域                │
│                                     │
│            (动态内容区域)            │
│                                     │
├─────────────────────────────────────┤
│          底部操作栏                 │
│    [辅助按钮]        [主要操作]      │
└─────────────────────────────────────┘
```

### 步骤指示器设计
```css
.step-indicator {
  display: flex;
  justify-content: center;
  align-items: center;
  gap: 20rpx;
}

.step-item {
  width: 60rpx;
  height: 8rpx;
  border-radius: 4rpx;
  background: rgba(255,255,255,0.3);
  transition: all 0.3s ease;
}

.step-item.active {
  width: 120rpx;
  background: white;
}
```

---

## 📝 活动创建流程设计

### 步骤1: 基础信息

**页面标题**: "创建共读 - 基础信息"

**必填字段**:
- **活动标题** (最大50字符)
  - 占位符: "请输入活动标题，如：《三体》读书会"
  - 验证: 必填，5-50字符

- **书籍名称** (最大50字符)
  - 占位符: "请输入书籍名称"
  - 验证: 必填，2-50字符

- **书籍封面** (可选)
  - 功能: 图片上传，支持相册选择和拍照
  - 限制: 1张，最大5MB
  - 默认: 提供默认书籍封面

- **活动简介** (最大500字符)
  - 占位符: "简要介绍活动内容、适合人群等"
  - 验证: 必填，20-500字符
  - UI: 多行文本框，支持字数统计

**可选字段**:
- **活动人数限制**
  - 类型: 数字选择器
  - 范围: 2-50人
  - 默认: 25人

- **费用设置**
  - 类型: 单选 + 输入框
  - 选项: 免费、押金制、收费制
  - 费用范围: 1-500元
  - 说明: 押金制下20%作为小组长报酬，80%作为押金池

### 步骤2: 活动规则

**页面标题**: "创建共读 - 活动规则"

**活动模式选择**:
```
□ 笔记打卡方式 (推荐)
  说明: 参与者每天提交阅读笔记，领读人点评
  子选项:
    □ 周末休息 (默认关闭)
    □ 完成率标准: 80% (默认，可调节60%-100%)

□ 自由讨论方式
  说明: 开放式讨论，不强制每日打卡
  说明文字: "更适合经验丰富的读者群体"

□ 视频会议方式
  说明: 定期视频会议讨论，具体时间另行安排
  说明文字: "适合深度交流和互动"

□ 线下交流方式
  说明: 定期线下聚会讨论，具体时间另行安排
  说明文字: "适合面对面深度交流"
```

**领读方式设置**:
```
领读方式:
○ 自由领读 (默认)
  说明: 参与者自愿报名担任领读人

○ 随机领读
  说明: 系统自动分配每日领读人

○ 无领读
  说明: 不设置领读人，参与者自行管理
```

### 步骤3: 阅读计划

**页面标题**: "创建共读 - 阅读计划"

**时间设置**:
- **开始日期**: 日期选择器，最早为明天
- **结束日期**: 日期选择器，至少比开始日期晚7天
- **持续时间显示**: 自动计算并显示 "共X天"

**每日计划设置**:
```
Day 1: 日期  |  阅读进度  |  领读人: 待分配
Day 2: 日期  |  阅读进度  |  领读人: 待分配
...
[+ 添加一天]
```

---

## 🎯 核心功能界面设计

### 费用设置组件

```xml
<view class="fee-setting-section">
  <view class="section-title">
    <text class="title-text">报名费用</text>
  </view>

  <view class="fee-options">
    <view class="fee-option {{feeType === 'free' ? 'selected' : ''}}"
          bindtap="selectFeeType"
          data-type="free">
      <view class="option-radio">
        <view class="radio-dot {{feeType === 'free' ? 'active' : ''}}"></view>
      </view>
      <view class="option-content">
        <text class="option-name">免费</text>
        <text class="option-desc">无费用参与</text>
      </view>
    </view>

    <view class="fee-option {{feeType === 'deposit' ? 'selected' : ''}}"
          bindtap="selectFeeType"
          data-type="deposit">
      <view class="option-radio">
        <view class="radio-dot {{feeType === 'deposit' ? 'active' : ''}}"></view>
      </view>
      <view class="option-content">
        <text class="option-name">押金制</text>
        <text class="option-desc">20%小组长报酬，80%押金池达标退还</text>
      </view>
    </view>

    <view class="fee-option {{feeType === 'paid' ? 'selected' : ''}}"
          bindtap="selectFeeType"
          data-type="paid">
      <view class="option-radio">
        <view class="radio-dot {{feeType === 'paid' ? 'active' : ''}}"></view>
      </view>
      <view class="option-content">
        <text class="option-name">收费制</text>
        <text class="option-desc">收费不退，全部作为小组长报酬</text>
      </view>
    </view>
  </view>
</view>
```

### 活动卡片设计

```xml
<view class="event-card">
  <view class="card-header">
    <image class="book-cover" src="{{item.book_cover_url}}" mode="aspectFill" />
    <view class="event-info">
      <text class="event-title">{{item.title}}</text>
      <text class="book-name">{{item.book_name}}</text>
      <view class="event-meta">
        <text class="participants-count">{{item.participants_count}}/{{item.max_participants}}人</text>
        <text class="event-status">{{item.status_text}}</text>
      </view>
    </view>
  </view>

  <view class="card-content">
    <text class="event-description">{{item.description}}</text>

    <view class="event-details">
      <view class="detail-item">
        <text class="detail-label">活动时间:</text>
        <text class="detail-value">{{item.date_range}}</text>
      </view>
      <view class="detail-item">
        <text class="detail-label">活动模式:</text>
        <text class="detail-value">{{item.activity_mode_name}}</text>
      </view>
      <view class="detail-item">
        <text class="detail-label">费用设置:</text>
        <text class="detail-value">{{item.fee_description}}</text>
      </view>
    </view>
  </view>

  <view class="card-footer">
    <view class="leader-info">
      <image class="leader-avatar" src="{{item.leader.avatar_url}}" />
      <text class="leader-name">小组长: {{item.leader.nickname}}</text>
    </view>
    <view class="action-buttons">
      <button class="btn-observe" wx:if="{{!item.is_participating}}"
              bindtap="observeEvent" data-id="{{item.id}}">
        围观
      </button>
      <button class="btn-join {{item.can_enroll ? '' : 'disabled'}}"
              bindtap="joinEvent" data-id="{{item.id}}">
        {{item.is_participating ? '已报名' : '立即报名'}}
      </button>
    </view>
  </view>
</view>
```

### 打卡界面设计

```xml
<view class="check-in-container">
  <view class="today-header">
    <text class="day-label">Day {{current_day}}</text>
    <text class="date-label">{{current_date}}</text>
    <view class="reading-progress">
      <text class="progress-text">今日进度: {{today_reading_progress}}</text>
    </view>
  </view>

  <view class="leader-content" wx:if="{{daily_leading}}">
    <view class="leader-header">
      <image class="leader-avatar" src="{{daily_leading.leader.avatar_url}}" />
      <text class="leader-name">今日领读: {{daily_leading.leader.nickname}}</text>
    </view>

    <view class="leading-content">
      <view class="section-title">📖 今日阅读重点</view>
      <text class="content-text">{{daily_leading.reading_suggestion}}</text>

      <view class="section-title">💡 思考问题</view>
      <view class="questions-list">
        <text class="question-item" wx:for="{{daily_leading.questions}}" wx:key="index">
          {{index + 1}}. {{item}}
        </text>
      </view>
    </view>
  </view>

  <view class="check-in-form">
    <view class="form-title">✍️ 今日打卡</view>
    <textarea class="check-in-input"
              placeholder="分享今天的阅读感想，至少100字..."
              bindinput="onInputChange"
              value="{{check_in_content}}"
              maxlength="1000" />
    <view class="char-count">{{check_in_content.length}}/1000</view>

    <button class="submit-btn {{can_submit ? '' : 'disabled'}}"
            bindtap="submitCheckIn">
      {{has_submitted ? '已打卡' : '提交打卡'}}
    </button>
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
.event-card {
  background: white;
  border-radius: 20rpx;
  padding: 32rpx;
  margin-bottom: 24rpx;
  box-shadow: 0 4rpx 20rpx rgba(0, 0, 0, 0.08);
  transition: all 0.3s ease;
}

.event-card:active {
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
  --secondary-color: #ff6b6b;
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
  .event-card {
    padding: 24rpx;
    margin-bottom: 16rpx;
  }
}

/* 大屏幕手机/小平板 */
@media (min-width: 751rpx) {
  .event-grid {
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: 24rpx;
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

*本文档最后更新: 2025-10-17*