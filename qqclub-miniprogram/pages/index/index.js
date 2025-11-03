// pages/index/index.js
const app = getApp()
const api = require('../../utils/api')
const util = require('../../utils/util')

Page({
  data: {
    userInfo: null,
    loading: false,
    unreadCount: 0
  },

  onLoad() {
    this.checkLoginStatus()
  },

  onShow() {
    this.loadUserInfo()
    if (this.data.userInfo) {
      this.loadUnreadCount()
    }
  },

  onPullDownRefresh() {
    // 简化刷新逻辑，只刷新未读消息数量
    this.loadUnreadCount()
    wx.stopPullDownRefresh()
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