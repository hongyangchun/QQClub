// app.js
App({
  onLaunch() {
    // 展示本地存储能力
    const logs = wx.getStorageSync('logs') || []
    logs.unshift(Date.now())
    wx.setStorageSync('logs', logs)

    // 登录
    wx.login({
      success: res => {
        // 发送 res.code 到后台换取 openId, sessionKey, unionId
        console.log('登录成功，code:', res.code)
        this.globalData.code = res.code
        this.checkSession()
      }
    })
  },

  onShow() {
    // 检查用户登录状态
    this.checkLoginStatus()
  },

  checkLoginStatus() {
    const token = wx.getStorageSync('token')
    if (token) {
      // 验证token有效性
      this.validateToken(token)
    }
  },

  checkSession() {
    wx.checkSession({
      success: () => {
        // session_key 未过期，并且在本生命周期一直有效
        console.log('session_key有效')
      },
      fail: () => {
        // session_key 已经失效，需要重新执行登录流程
        console.log('session_key失效，重新登录')
        this.login()
      }
    })
  },

  // 登录方法
  login() {
    return new Promise((resolve, reject) => {
      wx.login({
        success: res => {
          if (res.code) {
            // 调用后端登录接口
            this.request({
              url: '/api/auth/mock_login',
              method: 'POST',
              data: {
                code: res.code
              }
            }).then(response => {
              if (response.success) {
                // 保存token和用户信息
                wx.setStorageSync('token', response.data.token)
                wx.setStorageSync('userInfo', response.data.user)
                this.globalData.token = response.data.token
                this.globalData.userInfo = response.data.user
                resolve(response.data)
              } else {
                reject(response)
              }
            }).catch(error => {
              reject(error)
            })
          } else {
            reject(new Error('获取微信登录凭证失败'))
          }
        },
        fail: error => {
          reject(error)
        }
      })
    })
  },

  // 验证token有效性
  validateToken(token) {
    this.request({
      url: '/api/auth/validate',
      method: 'GET',
      header: {
        'Authorization': `Bearer ${token}`
      }
    }).then(response => {
      if (!response.success) {
        // token失效，清除本地存储
        wx.removeStorageSync('token')
        wx.removeStorageSync('userInfo')
        this.globalData.token = null
        this.globalData.userInfo = null
      }
    }).catch(error => {
      console.error('验证token失败:', error)
    })
  },

  // 网络请求封装
  request(options) {
    return new Promise((resolve, reject) => {
      const token = wx.getStorageSync('token') || this.globalData.token

      wx.request({
        url: this.globalData.baseUrl + options.url,
        method: options.method || 'GET',
        data: options.data || {},
        header: {
          'Content-Type': 'application/json',
          'Authorization': token ? `Bearer ${token}` : '',
          ...options.header
        },
        success: (res) => {
          if (res.statusCode === 200) {
            resolve(res.data)
          } else if (res.statusCode === 401) {
            // 未授权，跳转到登录页
            wx.removeStorageSync('token')
            wx.removeStorageSync('userInfo')
            this.globalData.token = null
            this.globalData.userInfo = null
            wx.navigateTo({
              url: '/pages/auth/auth'
            })
            reject(new Error('未授权，请重新登录'))
          } else {
            reject(new Error(`请求失败: ${res.statusCode}`))
          }
        },
        fail: (error) => {
          reject(error)
        }
      })
    })
  },

  // 显示加载中
  showLoading(title = '加载中...') {
    wx.showLoading({
      title: title,
      mask: true
    })
  },

  // 隐藏加载中
  hideLoading() {
    wx.hideLoading()
  },

  // 显示消息提示框
  showToast(title, icon = 'none') {
    wx.showToast({
      title: title,
      icon: icon,
      duration: 2000
    })
  },

  globalData: {
    userInfo: null,
    token: null,
    code: null,
    baseUrl: 'http://localhost:3000' // 开发环境API地址
  }
})