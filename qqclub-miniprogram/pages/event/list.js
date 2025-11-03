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
    console.log('活动列表页面 onLoad')
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
      const response = await this.apiCall({
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

  // 真实API调用
  apiCall(params) {
    return new Promise((resolve, reject) => {
      const { page, filter, userId } = params

      // 构建API URL
      let url = `${app.globalData.baseUrl}/api/v1/reading_events?page=${page}&limit=10`

      // 添加筛选条件
      if (filter && filter !== 'all') {
        url += `&status=${filter}`
      }

      // 添加用户ID（如果需要获取用户相关的活动）
      if (userId) {
        url += `&user_id=${userId}`
      }

      wx.request({
        url: url,
        method: 'GET',
        header: {
          'Content-Type': 'application/json',
          'Authorization': app.globalData.token ? `Bearer ${app.globalData.token}` : undefined
        },
        success: (res) => {
          console.log('活动列表API响应:', res)

          if (res.statusCode >= 200 && res.statusCode < 300) {
            if (res.data && (res.data.success || res.data.code === 200)) {
              const events = res.data.data || []
              const transformedEvents = events.map(event => this.transformEventData(event))

              // 计算是否还有更多数据
              const meta = res.data.meta || {}
              const hasMore = meta.next_page !== null || events.length === 10

              resolve({
                events: transformedEvents,
                hasMore: hasMore,
                enrollingCount: events.filter(e => e.status === 'enrolling').length || 0
              })
            } else {
              reject(new Error(res.data?.message || res.data?.error || '获取活动列表失败'))
            }
          } else {
            reject(new Error(`服务器错误: ${res.statusCode}`))
          }
        },
        fail: (err) => {
          console.error('API调用失败:', err)
          reject(new Error('网络错误，请重试'))
        }
      })
    })
  },

  // 转换API响应数据格式
  transformEventData(event) {
    const statusTexts = {
      'draft': '草稿',
      'enrolling': '报名中',
      'in_progress': '进行中',
      'completed': '已结束'
    }

    return {
      id: event.id,
      title: event.title,
      book_name: event.book_name,
      book_cover_url: event.book_cover_url,
      leader_name: event.leader?.nickname || '未知组织者',
      status: event.status,
      status_text: statusTexts[event.status] || event.status,
      start_date: event.start_date,
      end_date: event.end_date,
      date_range: this.formatDateRange(event.start_date, event.end_date),
      participants_count: event.participants_count || 0,
      max_participants: event.max_participants,
      available_spots: event.available_spots,
      can_join: event.status === 'enrolling' && event.available_spots > 0,
      can_observe: true, // 默认允许围观
      is_participant: event.is_participant || false,
      is_observer: event.is_observer || false,
      description: event.description,
      fee_type: event.fee_type,
      fee_amount: parseFloat(event.fee_amount) || 0,
      activity_mode: event.activity_mode,
      approval_status: event.approval_status
    }
  },

  // 格式化日期范围
  formatDateRange(startDate, endDate) {
    if (!startDate || !endDate) return ''

    try {
      const start = new Date(startDate)
      const end = new Date(endDate)

      const startMonth = start.getMonth() + 1
      const startDay = start.getDate()
      const endMonth = end.getMonth() + 1
      const endDay = end.getDate()

      if (startMonth === endMonth) {
        return `${startMonth}月${startDay}日 - ${endDay}日`
      } else {
        return `${startMonth}月${startDay}日 - ${endMonth}月${endDay}日`
      }
    } catch (error) {
      console.error('日期格式化错误:', error)
      return startDate && endDate ? `${startDate} - ${endDate}` : ''
    }
  },

  
  // 跳转到活动详情
  goToEventDetail(e) {
    console.log('goToEventDetail 被调用', e)
    const eventId = e.currentTarget.dataset.id
    console.log('跳转到活动详情，ID:', eventId)

    wx.navigateTo({
      url: `/pages/event/home?id=${eventId}`,
      success: () => {
        console.log('成功跳转到活动主页')
      },
      fail: (err) => {
        console.error('跳转失败:', err)
        wx.showToast({
          title: '跳转失败',
          icon: 'none'
        })
      }
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
  },

  // 阻止事件冒泡
  stopPropagation() {
    // 这个方法只是为了阻止事件冒泡，不做任何实际操作
    return
  }
})