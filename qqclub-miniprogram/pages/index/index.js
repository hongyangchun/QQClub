// pages/index/index.js
const app = getApp()
const api = require('../../utils/api')
const util = require('../../utils/util')

Page({
  data: {
    userInfo: null,
    recentEvents: [],
    recentPosts: [],
    loading: false,
    unreadCount: 0
  },

  onLoad() {
    this.checkLoginStatus()
  },

  onShow() {
    this.loadUserInfo()
    if (this.data.userInfo) {
      this.loadRecentData()
      this.loadUnreadCount()
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
      // 使用模拟数据，避免API认证问题
      const mockData = await this.loadMockData()

      this.setData({
        recentEvents: mockData.events,
        recentPosts: mockData.posts,
        loading: false
      })

    } catch (error) {
      console.error('加载数据失败:', error)
      // 即使加载失败也显示空状态，不影响用户体验
      this.setData({
        recentEvents: [],
        recentPosts: [],
        loading: false
      })
    }
  },

  // 加载模拟数据
  async loadMockData() {
    return new Promise((resolve) => {
      setTimeout(() => {
        const mockEvents = this.generateMockEvents()
        const mockPosts = this.generateMockPosts()

        resolve({
          events: mockEvents,
          posts: mockPosts
        })
      }, 800) // 模拟网络延迟
    })
  },

  // 生成模拟活动数据
  generateMockEvents() {
    const events = []
    const statuses = ['enrolling', 'in_progress', 'completed']
    const approvalStatuses = ['pending', 'approved']

    for (let i = 0; i < 3; i++) {
      const status = statuses[Math.floor(Math.random() * statuses.length)]
      const approvalStatus = approvalStatuses[Math.floor(Math.random() * approvalStatuses.length)]

      events.push({
        id: i + 1,
        title: `共读活动《经典文学选读》第${i + 1}期`,
        book_name: '经典文学选读',
        approval_status: approvalStatus,
        approval_status_text: this.getApprovalStatusText(approvalStatus),
        status: status,
        status_text: this.getStatusText(status),
        start_date: '2025-01-15',
        end_date: '2025-02-15',
        date_range: '1月15日 - 2月15日',
        participants_count: Math.floor(Math.random() * 30) + 10,
        max_participants: 50
      })
    }

    return events
  },

  // 生成模拟帖子数据
  generateMockPosts() {
    const posts = []
    const categories = ['读书心得', '活动讨论', '闲聊区', '求助问答']

    for (let i = 0; i < 5; i++) {
      const category = categories[Math.floor(Math.random() * categories.length)]

      posts.push({
        id: i + 1,
        title: `【${category}】分享今天的阅读感悟`,
        content: '今天读到了一个非常有趣的段落，让我对人生有了新的思考。文字的力量真的很伟大，能够穿越时空触动我们的内心...',
        content_preview: '今天读到了一个非常有趣的段落，让我对人生有了新的思考...',
        author_info: {
          id: Math.floor(Math.random() * 100) + 1,
          nickname: `读书爱好者${i + 1}`,
          avatar_url: `https://picsum.photos/100/100?random=${i + 1}`
        },
        likes_count: Math.floor(Math.random() * 50) + 5,
        comments_count: Math.floor(Math.random() * 20) + 2,
        created_at: new Date(Date.now() - Math.random() * 7 * 24 * 60 * 60 * 1000).toISOString(),
        created_at_relative: this.getRelativeTime(new Date(Date.now() - Math.random() * 7 * 24 * 60 * 60 * 1000))
      })
    }

    return posts
  },

  // 获取相对时间
  getRelativeTime(date) {
    const now = new Date()
    const diff = now - date
    const minutes = Math.floor(diff / 60000)
    const hours = Math.floor(diff / 3600000)
    const days = Math.floor(diff / 86400000)

    if (minutes < 1) return '刚刚'
    if (minutes < 60) return `${minutes}分钟前`
    if (hours < 24) return `${hours}小时前`
    if (days < 7) return `${days}天前`

    return date.toLocaleDateString()
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
    console.log('点击自由交流按钮')
    try {
      wx.switchTab({
        url: '/pages/forum/list',
        success: function() {
          console.log('成功跳转到交流区')
        },
        fail: function(err) {
          console.error('跳转到交流区失败:', err)
          // 如果 switchTab 失败，尝试使用 navigateTo
          wx.navigateTo({
            url: '/pages/forum/list'
          })
        }
      })
    } catch (error) {
      console.error('调用 switchTab 出错:', error)
    }
  },

  goToCreateEvent() {
    wx.navigateTo({
      url: '/pages/event/create'
    })
  },

  goToCreatePost() {
    wx.navigateTo({
      url: '/pages/forum/create'
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
      url: `/pages/forum/detail?id=${id}`
    })
  },

  
  goToStats() {
    wx.navigateTo({
      url: '/pages/event/stats'
    })
  },

  // 加载未读消息数量
  loadUnreadCount() {
    // 模拟未读消息数量
    const mockUnreadCount = Math.floor(Math.random() * 8);
    this.setData({ unreadCount: mockUnreadCount });
  },

  // 跳转到我的活动
  goToMyActivities() {
    wx.navigateTo({
      url: '/pages/event/my-activities'
    });
  },

  // 跳转到消息动态
  goToMessages() {
    wx.navigateTo({
      url: '/pages/messages/list'
    });
  },

  // 分享功能
  onShareAppMessage() {
    return {
      title: '恰恰读书会 - 发现阅读的乐趣',
      path: '/pages/index/index',
      imageUrl: '/images/share-cover.jpg'
    }
  },

  onShareTimeline() {
    return {
      title: '恰恰读书会 - 发现阅读的乐趣',
      imageUrl: '/images/share-cover.jpg'
    }
  }
})