// pages/event/statistics.js
const app = getApp()

Page({
  data: {
    eventId: null,
    eventInfo: null,
    userRole: null,
    myProgress: null,
    overviewStats: null,
    rankings: [],
    checkinTrend: [],
    participationStats: null,
    interactionStats: null,
    trendPeriod: '7',
    loading: true
  },

  onLoad(options) {
    if (options.id) {
      this.setData({ eventId: options.id })
      this.loadAllStatistics()
    } else {
      wx.showToast({
        title: '参数错误',
        icon: 'error'
      })
      setTimeout(() => {
        wx.navigateBack()
      }, 1500)
    }
  },

  // 加载所有统计数据
  async loadAllStatistics() {
    try {
      this.setData({ loading: true })

      // 并行加载所有数据
      const [eventRes, statsRes, progressRes] = await Promise.all([
        this.loadEventInfo(),
        this.loadStatistics(),
        this.loadMyProgress()
      ])

      this.setData({ loading: false })
    } catch (error) {
      console.error('加载统计数据失败:', error)
      this.setData({ loading: false })
      wx.showToast({
        title: '加载失败',
        icon: 'error'
      })
    }
  },

  // 加载活动基本信息
  async loadEventInfo() {
    try {
      const response = await app.request({
        url: `/api/v1/reading_events/${this.data.eventId}`,
        method: 'GET'
      })

      if (response.success && response.data) {
        const eventData = response.data
        this.setData({
          eventInfo: this.formatEventData(eventData)
        })
      }
    } catch (error) {
      console.error('加载活动信息失败:', error)
    }
  },

  // 加载统计数据
  async loadStatistics() {
    try {
      console.log('📊 尝试加载统计数据，活动ID:', this.data.eventId);
      const response = await app.request({
        url: `/api/v1/reading_events/${this.data.eventId}/statistics`,
        method: 'GET'
      })

      console.log('📊 统计数据响应:', response);

      if (response.success && response.data) {
        const stats = response.data
        console.log('✅ 统计数据加载成功:', stats);
        this.setData({
          overviewStats: this.formatOverviewStats(stats.overview),
          rankings: stats.rankings || [],
          checkinTrend: this.formatCheckinTrend(stats.checkin_trend),
          participationStats: this.formatParticipationStats(stats.participation),
          interactionStats: this.formatInteractionStats(stats.interaction)
        })
      } else {
        console.log('⚠️ 统计数据响应失败，使用模拟数据');
        this.generateMockStatistics()
      }
    } catch (error) {
      console.error('❌ 加载统计数据失败:', error);
      console.log('📊 回退到模拟数据');
      // 使用模拟数据
      this.generateMockStatistics()
    }
  },

  // 加载个人进度
  async loadMyProgress() {
    try {
      const userInfo = wx.getStorageSync('userInfo')
      if (!userInfo) return

      const response = await app.request({
        url: `/api/v1/event_enrollments/my_progress`,
        method: 'GET',
        data: { reading_event_id: this.data.eventId }
      })

      if (response.success && response.data) {
        this.setData({
          userRole: response.data.role,
          myProgress: response.data
        })
      }
    } catch (error) {
      console.error('加载个人进度失败:', error)
    }
  },

  // 生成模拟统计数据
  generateMockStatistics() {
    const mockStats = {
      overviewStats: {
        total_checkins: 156,
        checkins_trend: 12.5,
        checkins_trend_abs: 12.5,
        active_participants: 23,
        active_rate: 88,
        avg_completion: 76,
        total_flowers: 89
      },
      rankings: [
        { id: 1, nickname: '小明', avatar_url: '/images/avatar1.jpg', checkins_count: 28, activity_score: 95, is_organizer: true },
        { id: 2, nickname: '小红', avatar_url: '/images/avatar2.jpg', checkins_count: 25, activity_score: 88, completion_rate: 92 },
        { id: 3, nickname: '小张', avatar_url: '/images/avatar3.jpg', checkins_count: 22, activity_score: 82, completion_rate: 85 }
      ],
      participationStats: {
        participants_count: 23,
        observers_count: 8,
        participants_ratio: 74,
        observers_ratio: 26,
        completed_count: 5,
        in_progress_count: 15,
        started_count: 3
      },
      interactionStats: {
        total_flowers: 89,
        total_comments: 156,
        total_likes: 234,
        avg_interaction: 12.5
      }
    }

    this.setData(mockStats)
    // 生成默认的打卡趋势数据
    this.generateMockTrendData('7')
  },

  // 格式化活动数据
  formatEventData(data) {
    const statusMap = {
      'enrolling': { text: '报名中', icon: '📋' },
      'in_progress': { text: '进行中', icon: '📖' },
      'completed': { text: '已完成', icon: '✅' }
    }

    const startDate = new Date(data.start_date)
    const endDate = new Date(data.end_date)
    const daysCount = Math.ceil((endDate - startDate) / (1000 * 60 * 60 * 24)) + 1

    return {
      ...data,
      days_count: daysCount,
      status_text: statusMap[data.status]?.text || '未知',
      status_icon: statusMap[data.status]?.icon || '❓'
    }
  },

  // 格式化概览统计
  formatOverviewStats(data) {
    const stats = data || {
      total_checkins: 0,
      checkins_trend: 0,
      active_participants: 0,
      active_rate: 0,
      avg_completion: 0,
      total_flowers: 0
    }

    // 添加绝对值趋势，供 WXML 使用
    return {
      ...stats,
      checkins_trend_abs: Math.abs(stats.checkins_trend)
    }
  },

  // 格式化打卡趋势
  formatCheckinTrend(data) {
    if (!data || !Array.isArray(data)) return []

    return data.map(item => {
      const date = new Date(item.date)
      const label = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'][date.getDay()]

      return {
        ...item,
        label,
        percentage: Math.min(100, (item.count / 25) * 100) // 假设最大值为25
      }
    })
  },

  // 格式化参与统计
  formatParticipationStats(data) {
    if (!data) return null

    const total = data.participants_count + data.observers_count
    return {
      ...data,
      participants_ratio: total > 0 ? Math.round((data.participants_count / total) * 100) : 0,
      observers_ratio: total > 0 ? Math.round((data.observers_count / total) * 100) : 0
    }
  },

  // 格式化互动统计
  formatInteractionStats(data) {
    return data || {
      total_flowers: 0,
      total_comments: 0,
      total_likes: 0,
      avg_interaction: 0
    }
  },

  // 切换趋势周期（暂时禁用）
  changeTrendPeriod(e) {
    const period = e.currentTarget.dataset.period
    this.setData({ trendPeriod: period })
    // 暂时使用模拟数据，后续可以连接真实 API
    this.generateMockTrendData(period)
  },

  // 生成模拟趋势数据
  generateMockTrendData(period) {
    const mockData = {
      '7': [
        { date: '2025-01-11', count: 12, label: '周一', percentage: 80 },
        { date: '2025-01-12', count: 18, label: '周二', percentage: 100 },
        { date: '2025-01-13', count: 15, label: '周三', percentage: 85 },
        { date: '2025-01-14', count: 20, label: '周四', percentage: 95 },
        { date: '2025-01-15', count: 16, label: '周五', percentage: 88 },
        { date: '2025-01-16', count: 22, label: '周六', percentage: 100 },
        { date: '2025-01-17', count: 19, label: '周日', percentage: 92 }
      ],
      '30': [
        { date: '2025-01-01', count: 15, label: '1日', percentage: 75 },
        { date: '2025-01-05', count: 20, label: '5日', percentage: 100 },
        { date: '2025-01-10', count: 18, label: '10日', percentage: 90 },
        { date: '2025-01-15', count: 16, label: '15日', percentage: 80 },
        { date: '2025-01-20', count: 22, label: '20日', percentage: 100 },
        { date: '2025-01-25', count: 19, label: '25日', percentage: 95 }
      ],
      'all': [
        { date: '2024-12-01', count: 8, label: '12/1', percentage: 60 },
        { date: '2024-12-15', count: 15, label: '12/15', percentage: 85 },
        { date: '2025-01-01', count: 15, label: '1/1', percentage: 75 },
        { date: '2025-01-15', count: 16, label: '1/15', percentage: 80 },
        { date: '2025-01-17', count: 19, label: '1/17', percentage: 92 }
      ]
    }

    this.setData({
      checkinTrend: mockData[period] || mockData['7']
    })
  },

  // 查看完整排行
  viewFullRanking() {
    wx.showToast({
      title: '功能开发中',
      icon: 'none'
    })
  },

  // 导出数据
  exportData() {
    wx.showActionSheet({
      itemList: ['导出Excel', '导出图片', '分享报告'],
      success: (res) => {
        if (res.tapIndex === 0) {
          this.exportToExcel()
        } else if (res.tapIndex === 1) {
          this.exportToImage()
        } else if (res.tapIndex === 2) {
          this.shareReport()
        }
      }
    })
  },

  // 导出Excel
  exportToExcel() {
    wx.showToast({
      title: '功能开发中',
      icon: 'none'
    })
  },

  // 导出图片
  exportToImage() {
    wx.showToast({
      title: '功能开发中',
      icon: 'none'
    })
  },

  // 分享报告
  shareReport() {
    wx.showShareMenu({
      withShareTicket: true
    })
  },

  // 返回详情页
  goBack() {
    wx.navigateBack()
  },

  // 分享功能
  onShareAppMessage() {
    if (!this.data.eventInfo) return {}

    return {
      title: `${this.data.eventInfo.title} - 数据统计`,
      path: `/pages/event/statistics?id=${this.data.eventId}`,
      imageUrl: '/images/share-statistics.jpg'
    }
  },

  onShareTimeline() {
    if (!this.data.eventInfo) return {}

    return {
      title: `${this.data.eventInfo.title} - 活动数据统计`,
      imageUrl: '/images/share-statistics.jpg'
    }
  }
})