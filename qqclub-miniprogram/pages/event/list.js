// pages/event/list.js
const app = getApp()

Page({
  data: {
    userInfo: null,
    events: [],
    currentFilter: 'all',
    loading: false,
    hasMore: true,
    page: 1,
    enrollingCount: 0,
    participatingEvents: [],
    observingEvents: []
  },

  onLoad(options) {
    this.getUserInfo()
    this.loadEvents(true)
  },

  onShow() {
    this.getUserInfo()
    // 如果从其他页面返回，刷新列表
    if (this.data.events.length > 0) {
      this.loadEvents(true)
    }
  },

  onPullDownRefresh() {
    this.loadEvents(true).then(() => {
      wx.stopPullDownRefresh()
    })
  },

  onReachBottom() {
    if (this.data.hasMore && !this.data.loading) {
      this.loadMore()
    }
  },

  // 获取用户信息
  getUserInfo() {
    const userInfo = wx.getStorageSync('userInfo')
    if (userInfo) {
      this.setData({ userInfo })
    }
  },

  // 切换筛选条件
  changeFilter(e) {
    const filter = e.currentTarget.dataset.filter
    if (filter !== this.data.currentFilter) {
      this.setData({
        currentFilter: filter,
        page: 1,
        events: []
      })
      this.loadEvents(true)
    }
  },

  // 加载活动列表
  async loadEvents(refresh = false) {
    if (this.data.loading) return

    this.setData({ loading: true })

    try {
      const page = refresh ? 1 : this.data.page
      const response = await this.mockApiCall({
        page,
        filter: this.data.currentFilter,
        userId: this.data.userInfo?.id
      })

      const newEvents = refresh ? response.events : [...this.data.events, ...response.events]

      this.setData({
        events: newEvents,
        hasMore: response.hasMore,
        page: page + 1,
        enrollingCount: response.enrollingCount || 0
      })
    } catch (error) {
      console.error('加载活动失败:', error)
      wx.showToast({
        title: '加载失败',
        icon: 'none'
      })
    } finally {
      this.setData({ loading: false })
    }
  },

  // 加载更多
  loadMore() {
    this.loadEvents(false)
  },

  // 模拟API调用
  mockApiCall(params) {
    return new Promise((resolve) => {
      setTimeout(() => {
        const mockEvents = this.generateMockEvents(params.page, params.filter)
        resolve({
          events: mockEvents,
          hasMore: params.page < 3,
          enrollingCount: 5
        })
      }, 800)
    })
  },

  // 生成模拟活动数据
  generateMockEvents(page, filter) {
    const events = []
    const startIndex = (page - 1) * 10
    const allBooks = [
      '百年孤独', '1984', '小王子', '活着', '三体',
      '围城', '红楼梦', '人类简史', '思考快与慢', '原则'
    ]
    const allLeaders = [
      '读书达人小王', '文学爱好者小李', '资深书虫小张', '阅读推广员小陈',
      '书香门第小刘', '书籍收藏家小赵'
    ]

    const statuses = ['enrolling', 'in_progress', 'completed']
    const statusTexts = {
      'enrolling': '报名中',
      'in_progress': '进行中',
      'completed': '已结束'
    }

    for (let i = 0; i < 10; i++) {
      const status = statuses[Math.floor(Math.random() * statuses.length)]

      // 根据筛选条件过滤
      if (filter !== 'all' && status !== filter) {
        continue
      }

      const bookIndex = Math.floor(Math.random() * allBooks.length)
      const leaderIndex = Math.floor(Math.random() * allLeaders.length)
      const participantCount = Math.floor(Math.random() * 30) + 5
      const isParticipant = Math.random() > 0.8
      const isObserver = Math.random() > 0.9

      events.push({
        id: startIndex + i + 1,
        title: `共读《${allBooks[bookIndex]}》第${startIndex + i + 1}期`,
        book_name: allBooks[bookIndex],
        leader_name: allLeaders[leaderIndex],
        status: status,
        status_text: statusTexts[status],
        start_date: '2025-01-15',
        end_date: '2025-02-15',
        date_range: '1月15日 - 2月15日',
        participants_count: participantCount,
        max_participants: 50,
        can_join: status === 'enrolling' && !isParticipant && !isObserver,
        can_observe: !isParticipant && !isObserver,
        is_participant: isParticipant,
        is_observer: isObserver,
        description: '这是一个关于深度阅读和思考分享的活动，我们通过每日打卡和作业提交来共同进步。'
      })
    }

    return events
  },

  // 加入共读活动
  joinEvent(e) {
    const eventId = e.currentTarget.dataset.id
    const userInfo = this.data.userInfo

    if (!userInfo) {
      wx.showModal({
        title: '提示',
        content: '请先登录后再加入活动',
        confirmText: '去登录',
        success: (res) => {
          if (res.confirm) {
            wx.navigateTo({
              url: '/pages/auth/auth'
            })
          }
        }
      })
      return
    }

    wx.showModal({
      title: '确认加入',
      content: '确定要加入这个共读活动吗？',
      success: (res) => {
        if (res.confirm) {
          // 更新本地状态
          const events = this.data.events.map(event => {
            if (event.id === eventId) {
              return {
                ...event,
                is_participant: true,
                can_join: false,
                can_observe: false,
                participants_count: event.participants_count + 1
              }
            }
            return event
          })

          this.setData({ events })

          // 更新参与的活动列表
          this.setData({
            participatingEvents: [...this.data.participatingEvents, eventId]
          })

          wx.showToast({
            title: '加入成功',
            icon: 'success'
          })
        }
      }
    })
  },

  // 围观共读活动
  observeEvent(e) {
    const eventId = e.currentTarget.dataset.id
    const userInfo = this.data.userInfo

    if (!userInfo) {
      wx.showModal({
        title: '提示',
        content: '请先登录后再围观活动',
        confirmText: '去登录',
        success: (res) => {
          if (res.confirm) {
            wx.navigateTo({
              url: '/pages/auth/auth'
            })
          }
        }
      })
      return
    }

    wx.showModal({
      title: '确认围观',
      content: '围观后可以查看活动内容，但无法提交作业',
      success: (res) => {
        if (res.confirm) {
          // 更新本地状态
          const events = this.data.events.map(event => {
            if (event.id === eventId) {
              return {
                ...event,
                is_observer: true,
                can_join: false,
                can_observe: false
              }
            }
            return event
          })

          this.setData({ events })

          // 更新围观的活动列表
          this.setData({
            observingEvents: [...this.data.observingEvents, eventId]
          })

          wx.showToast({
            title: '围观成功',
            icon: 'success'
          })
        }
      }
    })
  },

  // 跳转到活动详情
  goToEventDetail(e) {
    const eventId = e.currentTarget.dataset.id
    wx.navigateTo({
      url: `/pages/event/detail?id=${eventId}`
    })
  },

  // 跳转到创建活动页面
  goToCreateEvent() {
    const userInfo = this.data.userInfo

    if (!userInfo) {
      wx.showModal({
        title: '提示',
        content: '请先登录后再创建活动',
        confirmText: '去登录',
        success: (res) => {
          if (res.confirm) {
            wx.navigateTo({
              url: '/pages/auth/auth'
            })
          }
        }
      })
      return
    }

    wx.navigateTo({
      url: '/pages/event/create'
    })
  },

  // 分享功能
  onShareAppMessage() {
    return {
      title: '恰恰读书会 - 共读区',
      path: '/pages/event/list',
      imageUrl: '/images/share-cover.jpg'
    }
  },

  onShareTimeline() {
    return {
      title: '恰恰读书会 - 共读区',
      imageUrl: '/images/share-cover.jpg'
    }
  }
})