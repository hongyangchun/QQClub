// pages/event/activity-info.js
const app = getApp()

Page({
  data: {
    eventId: null,
    eventInfo: null,
    loading: true
  },

  onLoad(options) {
    if (options.id) {
      this.setData({ eventId: options.id })
      this.loadEventInfo()
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

  // 加载活动信息
  async loadEventInfo() {
    try {
      this.setData({ loading: true })

      const response = await app.request({
        url: `/api/v1/reading_events/${this.data.eventId}`,
        method: 'GET'
      })

      if (response.success && response.data) {
        const eventData = response.data
        this.setData({
          eventInfo: this.formatEventData(eventData),
          loading: false
        })
      } else {
        throw new Error('获取活动信息失败')
      }
    } catch (error) {
      console.error('加载活动信息失败:', error)
      this.setData({ loading: false })
      wx.showToast({
        title: '加载失败',
        icon: 'error'
      })
    }
  },

  // 格式化活动数据
  formatEventData(data) {
    const now = new Date()
    const startDate = new Date(data.start_date)
    const endDate = new Date(data.end_date)

    // 计算剩余名额
    const remainingSlots = Math.max(0, data.max_participants - data.participants_count)

    // 格式化日期范围
    const formatDate = (date) => {
      return `${date.getMonth() + 1}月${date.getDate()}日`
    }

    const dateRange = `${formatDate(startDate)} - ${formatDate(endDate)}`
    const daysCount = Math.ceil((endDate - startDate) / (1000 * 60 * 60 * 24)) + 1

    // 状态映射
    const statusMap = {
      'enrolling': { text: '报名中', icon: '📋' },
      'in_progress': { text: '进行中', icon: '📖' },
      'completed': { text: '已完成', icon: '✅' }
    }

    const approvalStatusMap = {
      'pending': { text: '审批中', icon: '⏳' },
      'approved': { text: '已通过', icon: '✅' },
      'rejected': { text: '已拒绝', icon: '❌' }
    }

    const activityModeMap = {
      'note_checkin': '笔记打卡',
      'reading_summary': '阅读总结',
      'discussion': '话题讨论'
    }

    const leaderAssignmentMap = {
      'voluntary': '自愿报名',
      'rotation': '轮流制',
      'election': '选举制'
    }

    return {
      ...data,
      date_range: dateRange,
      days_count: daysCount,
      remaining_slots: remainingSlots,
      status_text: statusMap[data.status]?.text || '未知',
      status_icon: statusMap[data.status]?.icon || '❓',
      approval_status_text: approvalStatusMap[data.approval_status]?.text || '未知',
      activity_mode_text: activityModeMap[data.activity_mode] || '笔记打卡',
      leader_assignment_type_text: leaderAssignmentMap[data.leader_assignment_type] || '自愿报名'
    }
  },

  // 联系组织者
  contactOrganizer() {
    if (!this.data.eventInfo?.leader) {
      wx.showToast({
        title: '组织者信息不存在',
        icon: 'error'
      })
      return
    }

    wx.showActionSheet({
      itemList: ['发送消息', '查看主页'],
      success: (res) => {
        if (res.tapIndex === 0) {
          // 发送消息功能
          this.sendMessageToOrganizer()
        } else if (res.tapIndex === 1) {
          // 查看组织者主页
          this.viewOrganizerProfile()
        }
      }
    })
  },

  // 发送消息给组织者
  sendMessageToOrganizer() {
    // 这里可以实现发送消息的功能
    wx.showToast({
      title: '功能开发中',
      icon: 'none'
    })
  },

  // 查看组织者主页
  viewOrganizerProfile() {
    wx.showToast({
      title: '功能开发中',
      icon: 'none'
    })
  },

  // 分享活动
  shareEvent() {
    return new Promise((resolve) => {
      wx.showShareMenu({
        withShareTicket: true,
        success: () => {
          resolve()
        },
        fail: () => {
          // 手动分享
          wx.showActionSheet({
            itemList: ['分享给好友', '生成海报'],
            success: (res) => {
              if (res.tapIndex === 0) {
                this.shareToFriend()
              } else if (res.tapIndex === 1) {
                this.generatePoster()
              }
              resolve()
            },
            fail: () => {
              resolve()
            }
          })
        }
      })
    })
  },

  // 分享给好友
  shareToFriend() {
    wx.showToast({
      title: '请使用右上角分享',
      icon: 'none'
    })
  },

  // 生成海报
  generatePoster() {
    wx.showToast({
      title: '海报功能开发中',
      icon: 'none'
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
      title: `${this.data.eventInfo.title} - ${this.data.eventInfo.book_name}`,
      path: `/pages/event/home?id=${this.data.eventId}`,
      imageUrl: '/images/share-event.jpg'
    }
  },

  onShareTimeline() {
    if (!this.data.eventInfo) return {}

    return {
      title: `${this.data.eventInfo.title} - ${this.data.eventInfo.book_name}`,
      imageUrl: '/images/share-event.jpg'
    }
  }
})