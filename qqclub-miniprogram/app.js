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
    const userInfo = wx.getStorageSync('userInfo')
    if (token && userInfo) {
      // 设置全局数据
      this.globalData.token = token
      this.globalData.userInfo = userInfo

      // 检查token状态，如果过期会自动刷新
      this.checkTokenStatus()
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
      // 使用模拟登录数据
      const mockData = {
        openid: 'test_dhf_001',
        nickname: 'DHH',
        avatar_url: 'https://picsum.photos/100/100?random=dhh'
      }

      this.request({
        url: '/api/auth/mock_login',
        method: 'POST',
        data: mockData
      }).then(response => {
        if (response.access_token && response.user) {
          // 保存access token和refresh token
          wx.setStorageSync('token', response.access_token)
          if (response.refresh_token) {
            wx.setStorageSync('refreshToken', response.refresh_token)
          }
          wx.setStorageSync('userInfo', response.user)
          this.globalData.token = response.access_token
          this.globalData.userInfo = response.user
          resolve(response)
        } else if (response.token && response.user) {
          // 兼容旧的响应格式
          wx.setStorageSync('token', response.token)
          wx.setStorageSync('userInfo', response.user)
          this.globalData.token = response.token
          this.globalData.userInfo = response.user
          resolve(response)
        } else {
          reject(response)
        }
      }).catch(error => {
        reject(error)
      })
    })
  },

  // 验证token有效性
  validateToken(token) {
    this.request({
      url: '/api/auth/me',
      method: 'GET',
      header: {
        'Authorization': `Bearer ${token}`
      }
    }).then(response => {
      if (!response.id) {
        // token失效，清除本地存储
        wx.removeStorageSync('token')
        wx.removeStorageSync('userInfo')
        this.globalData.token = null
        this.globalData.userInfo = null
      }
    }).catch(error => {
      // 静默处理验证失败，不影响用户体验
      console.log('Token验证失败（可能是网络问题或服务器未启动）:', error.message)
      // 在开发环境下，如果服务器未启动，不清除本地存储，让用户可以继续使用小程序
      if (error.statusCode !== 401) {
        // 401是真正的token失效，其他错误（如网络问题）不清除登录状态
        return
      }

      // 只有在真正的认证失败时才清除存储
      wx.removeStorageSync('token')
      wx.removeStorageSync('userInfo')
      this.globalData.token = null
      this.globalData.userInfo = null
    })
  },

  // 刷新token
  async refreshToken() {
    const refreshToken = wx.getStorageSync('refreshToken')
    if (!refreshToken) {
      console.log('没有refresh token，需要重新登录')
      return false
    }

    try {
      console.log('正在刷新token...')
      const response = await this.request({
        url: '/api/auth/refresh_token',
        method: 'POST',
        data: {
          refresh_token: refreshToken
        },
        skipAuth: true  // 刷新token不需要认证
      })

      if (response.access_token) {
        // 保存新的token
        wx.setStorageSync('token', response.access_token)
        this.globalData.token = response.access_token

        // 如果返回了新的refresh token，也保存它
        if (response.refresh_token) {
          wx.setStorageSync('refreshToken', response.refresh_token)
        }

        // 更新用户信息
        if (response.user) {
          wx.setStorageSync('userInfo', response.user)
          this.globalData.userInfo = response.user
        }

        console.log('Token刷新成功')
        return true
      } else {
        console.log('Token刷新失败，响应格式错误')
        return false
      }
    } catch (error) {
      console.log('Token刷新失败:', error.message)
      // 刷新失败，清除所有认证信息
      this.clearAuthData()
      return false
    }
  },

  // 检查token是否需要刷新
  async checkTokenStatus() {
    const token = wx.getStorageSync('token')
    if (!token) return false

    try {
      // 尝试使用当前token获取用户信息
      await this.request({
        url: '/api/auth/me',
        method: 'GET'
      })
      return true
    } catch (error) {
      if (error.message.includes('未授权') || error.message.includes('401')) {
        console.log('Token已过期，尝试刷新...')
        return await this.refreshToken()
      }
      return false
    }
  },

  // 清除认证数据
  clearAuthData() {
    wx.removeStorageSync('token')
    wx.removeStorageSync('refreshToken')
    wx.removeStorageSync('userInfo')
    this.globalData.token = null
    this.globalData.userInfo = null
  },

  // 网络请求封装
  request(options) {
    return new Promise((resolve, reject) => {
      const token = wx.getStorageSync('token') || this.globalData.token

      // 检查是否需要跳过认证（用于refresh token等接口）
      const skipAuth = options.skipAuth || false

      wx.request({
        url: this.globalData.baseUrl + options.url,
        method: options.method || 'GET',
        data: options.data || {},
        header: {
          'Content-Type': 'application/json',
          // 如果不是跳过认证且有token，则添加Authorization头
          ...(skipAuth ? {} : {
            'Authorization': token ? `Bearer ${token}` : ''
          }),
          ...options.header
        },
        success: (res) => {
          if (res.statusCode >= 200 && res.statusCode < 300) {
            // 2xx 状态码都视为成功
            resolve(res.data)
          } else if (res.statusCode === 401) {
            // 只有在需要认证的情况下才处理401错误
            if (!skipAuth) {
              // 尝试刷新token
              this.refreshToken().then(success => {
                if (success) {
                  // token刷新成功，重新发起请求
                  this.request(options).then(resolve).catch(reject)
                } else {
                  // token刷新失败，跳转到登录页
                  this.handleAuthFailure()
                  reject(new Error('未授权，请重新登录'))
                }
              }).catch(() => {
                // 刷新token过程出错，直接跳转登录
                this.handleAuthFailure()
                reject(new Error('未授权，请重新登录'))
              })
            } else {
              reject(new Error(`请求失败: ${res.statusCode}`))
            }
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

  // 处理认证失败
  handleAuthFailure() {
    // 清除本地存储
    this.clearAuthData()

    // 显示友好的提示
    wx.showModal({
      title: '登录已过期',
      content: '您的登录已过期，请重新登录',
      showCancel: false,
      confirmText: '去登录',
      success: () => {
        wx.reLaunch({
          url: '/pages/auth/auth'
        })
      }
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