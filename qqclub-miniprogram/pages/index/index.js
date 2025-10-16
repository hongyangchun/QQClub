// pages/index/index.js
const app = getApp()
const api = require('../../utils/api')
const util = require('../../utils/util')

Page({
  data: {
    userInfo: null,
    recentEvents: [],
    recentPosts: [],
    loading: false
  },

  onLoad() {
    this.checkLoginStatus()
  },

  onShow() {
    this.loadUserInfo()
    if (this.data.userInfo) {
      this.loadRecentData()
    }
  },

  onPullDownRefresh() {
    this.loadRecentData().then(() => {
      wx.stopPullDownRefresh()
    })
  },

  // 检查登录状态
  checkLoginStatus() {
    const userInfo = wx.getStorageSync('userInfo')
    if (userInfo) {
      this.setData({ userInfo })
    }
  },

  // 加载用户信息
  loadUserInfo() {
    const userInfo = wx.getStorageSync('userInfo')
    if (userInfo) {
      this.setData({ userInfo })
    }
  },

  // 加载最新数据
  async loadRecentData() {
    if (!this.data.userInfo) return

    this.setData({ loading: true })

    try {
      // 并行加载最新活动和动态
      const [eventsRes, postsRes] = await Promise.all([
        api.event.getList({ limit: 3, order: 'created_at DESC' }),
        api.post.getList({ limit: 5, order: 'created_at DESC' })
      ])

      // 处理活动数据
      let recentEvents = []
      if (eventsRes.success && eventsRes.data && eventsRes.data.reading_events) {
        recentEvents = eventsRes.data.reading_events.map(event => ({
          ...event,
          approval_status_text: this.getApprovalStatusText(event.approval_status),
          status_text: this.getStatusText(event.status),
          date_range: util.formatDateRange(event.start_date, event.end_date),
          participants_count: event.enrollments ? event.enrollments.length : 0
        }))
      }

      // 处理动态数据
      let recentPosts = []
      if (postsRes.success && postsRes.data && postsRes.data.posts) {
        recentPosts = postsRes.data.posts.map(post => ({
          ...post,
          created_at_relative: util.formatRelativeTime(post.created_at),
          content_preview: post.content.length > 100
            ? post.content.substring(0, 100) + '...'
            : post.content
        }))
      }

      this.setData({
        recentEvents,
        recentPosts,
        loading: false
      })

    } catch (error) {
      console.error('加载数据失败:', error)
      app.showToast('加载失败，请重试')
      this.setData({ loading: false })
    }
  },

  // 获取审批状态文本
  getApprovalStatusText(status) {
    const statusMap = {
      'pending': '待审批',
      'approved': '已通过',
      'rejected': '已拒绝'
    }
    return statusMap[status] || '未知'
  },

  // 获取状态文本
  getStatusText(status) {
    const statusMap = {
      'draft': '草稿',
      'enrolling': '报名中',
      'in_progress': '进行中',
      'completed': '已完成'
    }
    return statusMap[status] || '未知'
  },

  // 页面导航方法
  goToLogin() {
    wx.navigateTo({
      url: '/pages/auth/auth'
    })
  },

  goToProfile() {
    wx.switchTab({
      url: '/pages/profile/profile'
    })
  },

  goToEvents() {
    wx.switchTab({
      url: '/pages/event/list'
    })
  },

  goToPosts() {
    wx.switchTab({
      url: '/pages/post/list'
    })
  },

  goToCreateEvent() {
    wx.navigateTo({
      url: '/pages/event/create'
    })
  },

  goToCreatePost() {
    wx.navigateTo({
      url: '/pages/post/create'
    })
  },

  goToEventDetail(e) {
    const id = e.currentTarget.dataset.id
    wx.navigateTo({
      url: `/pages/event/detail?id=${id}`
    })
  },

  goToPostDetail(e) {
    const id = e.currentTarget.dataset.id
    wx.navigateTo({
      url: `/pages/post/detail?id=${id}`
    })
  },

  // 分享功能
  onShareAppMessage() {
    return {
      title: 'QQ读书会 - 发现阅读的乐趣',
      path: '/pages/index/index',
      imageUrl: '/images/share-cover.jpg'
    }
  },

  onShareTimeline() {
    return {
      title: 'QQ读书会 - 发现阅读的乐趣',
      imageUrl: '/images/share-cover.jpg'
    }
  }
})