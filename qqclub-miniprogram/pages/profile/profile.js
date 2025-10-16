// pages/profile/profile.js
const app = getApp()
const api = require('../../utils/api')
const util = require('../../utils/util')

Page({
  data: {
    userInfo: null,
    stats: {
      events_count: 0,
      posts_count: 0,
      likes_count: 0,
      flowers_count: 0
    },
    loading: false
  },

  onLoad() {
    this.loadUserInfo()
  },

  onShow() {
    this.loadUserInfo()
    if (this.data.userInfo) {
      this.loadUserStats()
    }
  },

  onPullDownRefresh() {
    Promise.all([
      this.loadUserInfo(),
      this.data.userInfo ? this.loadUserStats() : Promise.resolve()
    ]).then(() => {
      wx.stopPullDownRefresh()
    })
  },

  // 加载用户信息
  async loadUserInfo() {
    const userInfo = wx.getStorageSync('userInfo')
    if (userInfo) {
      this.setData({ userInfo })

      // 格式化用户信息
      if (userInfo.created_at) {
        userInfo.created_at = util.formatTime(userInfo.created_at, 'YYYY-MM-DD')
      }

      this.setData({ userInfo })
    } else {
      this.setData({
        userInfo: null,
        stats: {
          events_count: 0,
          posts_count: 0,
          likes_count: 0,
          flowers_count: 0
        }
      })
    }
  },

  // 加载用户统计数据
  async loadUserStats() {
    if (!this.data.userInfo) return

    this.setData({ loading: true })

    try {
      // 这里应该调用获取用户统计数据的API
      // const response = await api.user.getStats()

      // 模拟统计数据
      const mockStats = {
        events_count: 5,
        posts_count: 23,
        likes_count: 156,
        flowers_count: 12
      }

      this.setData({
        stats: mockStats,
        loading: false
      })

    } catch (error) {
      console.error('加载统计数据失败:', error)
      this.setData({ loading: false })
    }
  },

  // 更换头像
  changeAvatar() {
    wx.chooseImage({
      count: 1,
      sizeType: ['compressed'],
      sourceType: ['album', 'camera'],
      success: (res) => {
        const tempFilePath = res.tempFilePaths[0]
        this.uploadAvatar(tempFilePath)
      }
    })
  },

  // 上传头像
  async uploadAvatar(filePath) {
    wx.showLoading({
      title: '上传中...'
    })

    try {
      // 这里应该调用上传头像API
      // const response = await api.user.uploadAvatar(filePath)

      // 模拟上传成功
      await new Promise(resolve => setTimeout(resolve, 1500))

      // 更新本地头像
      const userInfo = this.data.userInfo
      userInfo.avatar_url = filePath

      wx.setStorageSync('userInfo', userInfo)
      app.globalData.userInfo = userInfo

      this.setData({ userInfo })
      app.showToast('头像更新成功', 'success')

    } catch (error) {
      console.error('上传头像失败:', error)
      app.showToast('上传失败，请重试')
    } finally {
      wx.hideLoading()
    }
  },

  // 编辑资料
  editProfile() {
    wx.navigateTo({
      url: '/pages/profile/edit'
    })
  },

  // 页面导航方法
  goToMyEvents() {
    if (!this.checkLogin()) return

    wx.navigateTo({
      url: '/pages/profile/events'
    })
  },

  goToMyPosts() {
    if (!this.checkLogin()) return

    wx.navigateTo({
      url: '/pages/profile/posts'
    })
  },

  goToMyLikes() {
    if (!this.checkLogin()) return

    wx.navigateTo({
      url: '/pages/profile/likes'
    })
  },

  goToMyFlowers() {
    if (!this.checkLogin()) return

    wx.navigateTo({
      url: '/pages/profile/flowers'
    })
  },

  goToSettings() {
    wx.navigateTo({
      url: '/pages/profile/settings'
    })
  },

  goToNoteExport() {
    if (!this.checkLogin()) return

    wx.navigateTo({
      url: '/pages/profile/note-export'
    })
  },

  goToNotifications() {
    if (!this.checkLogin()) return

    wx.navigateTo({
      url: '/pages/profile/notifications'
    })
  },

  goToPrivacy() {
    if (!this.checkLogin()) return

    wx.navigateTo({
      url: '/pages/profile/privacy'
    })
  },

  goToFeedback() {
    if (!this.checkLogin()) return

    wx.navigateTo({
      url: '/pages/profile/feedback'
    })
  },

  goToHelp() {
    wx.navigateTo({
      url: '/pages/profile/help'
    })
  },

  goToAbout() {
    wx.navigateTo({
      url: '/pages/profile/about'
    })
  },

  goToLogin() {
    wx.navigateTo({
      url: '/pages/auth/auth'
    })
  },

  // 退出登录
  async logout() {
    const confirmed = await util.showConfirm('确定要退出登录吗？')
    if (!confirmed) return

    try {
      // 清除本地存储
      wx.removeStorageSync('token')
      wx.removeStorageSync('userInfo')

      // 清除全局数据
      app.globalData.token = null
      app.globalData.userInfo = null

      // 重置页面数据
      this.setData({
        userInfo: null,
        stats: {
          events_count: 0,
          posts_count: 0,
          likes_count: 0,
          flowers_count: 0
        }
      })

      app.showToast('已退出登录', 'success')

    } catch (error) {
      console.error('退出登录失败:', error)
      app.showToast('操作失败，请重试')
    }
  },

  // 检查登录状态
  checkLogin() {
    if (!this.data.userInfo) {
      app.showToast('请先登录')
      this.goToLogin()
      return false
    }
    return true
  },

  // 分享功能
  onShareAppMessage() {
    const userInfo = this.data.userInfo
    return {
      title: userInfo ? `${userInfo.nickname}邀请你加入恰恰读书会` : '发现阅读的乐趣，加入恰恰读书会',
      path: '/pages/index/index',
      imageUrl: '/images/share-profile.jpg'
    }
  },

  onShareTimeline() {
    return {
      title: '恰恰读书会 - 发现阅读的乐趣',
      imageUrl: '/images/share-profile.jpg'
    }
  }
})