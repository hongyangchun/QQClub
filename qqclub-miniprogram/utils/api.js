// api.js - API请求封装
const app = getApp()

class API {
  constructor() {
    this.baseUrl = app.globalData.baseUrl
  }

  // 通用请求方法
  request(options) {
    return app.request(options)
  }

  // 认证相关API
  auth = {
    // 模拟登录
    mockLogin: (data) => {
      return this.request({
        url: '/api/auth/mock_login',
        method: 'POST',
        data: data
      })
    },

    // 微信登录
    wechatLogin: (loginData) => {
      return this.request({
        url: '/api/auth/wechat_login',
        method: 'POST',
        data: loginData
      })
    },

    // 刷新token
    refreshToken: (refreshToken) => {
      return this.request({
        url: '/api/auth/refresh_token',
        method: 'POST',
        data: {
          refresh_token: refreshToken
        },
        skipAuth: true  // 刷新token不需要认证
      })
    },

    // 获取当前用户信息
    me: () => {
      return this.request({
        url: '/api/auth/me',
        method: 'GET'
      })
    }
  }

  // 用户相关API
  user = {
    // 获取用户信息
    getProfile: () => {
      return this.request({
        url: '/api/profile',
        method: 'GET'
      })
    },

    // 更新用户信息
    updateProfile: (data) => {
      return this.request({
        url: '/api/profile',
        method: 'PUT',
        data: data
      })
    }
  }

  // 活动相关API
  event = {
    // 获取活动列表
    getList: (params = {}) => {
      return this.request({
        url: '/api/events',
        method: 'GET',
        data: params
      })
    },

    // 获取活动详情
    getDetail: (id) => {
      return this.request({
        url: `/api/events/${id}`,
        method: 'GET'
      })
    },

    // 创建活动
    create: (data) => {
      return this.request({
        url: '/api/events',
        method: 'POST',
        data: data
      })
    },

    // 更新活动
    update: (id, data) => {
      return this.request({
        url: `/api/events/${id}`,
        method: 'PUT',
        data: data
      })
    },

    // 删除活动
    delete: (id) => {
      return this.request({
        url: `/api/events/${id}`,
        method: 'DELETE'
      })
    },

    // 报名参加活动
    enroll: (id, data = {}) => {
      return this.request({
        url: `/api/events/${id}/enroll`,
        method: 'POST',
        data: data
      })
    },

    // 取消报名
    cancelEnrollment: (id) => {
      return this.request({
        url: `/api/events/${id}/cancel_enrollment`,
        method: 'DELETE'
      })
    },

    // 获取活动参与者列表
    getParticipants: (id) => {
      return this.request({
        url: `/api/events/${id}/participants`,
        method: 'GET'
      })
    },

    // 获取活动日程安排
    getSchedules: (id) => {
      return this.request({
        url: `/api/events/${id}/schedules`,
        method: 'GET'
      })
    },

    // 审批活动（管理员）
    approve: (id) => {
      return this.request({
        url: `/api/events/${id}/approve`,
        method: 'POST'
      })
    },

    // 拒绝活动（管理员）
    reject: (id, reason) => {
      return this.request({
        url: `/api/events/${id}/reject`,
        method: 'POST',
        data: { reason }
      })
    },

    // 完成活动
    complete: (id) => {
      return this.request({
        url: `/api/events/${id}/complete`,
        method: 'POST'
      })
    }
  }

  // 帖子相关API
  post = {
    // 获取帖子列表
    getList: (params = {}) => {
      return this.request({
        url: '/api/posts',
        method: 'GET',
        data: params
      })
    },

    // 获取帖子详情
    getDetail: (id) => {
      return this.request({
        url: `/api/posts/${id}`,
        method: 'GET'
      })
    },

    // 创建帖子
    create: (data) => {
      return this.request({
        url: '/api/posts',
        method: 'POST',
        data: data
      })
    },

    // 更新帖子
    update: (id, data) => {
      return this.request({
        url: `/api/posts/${id}`,
        method: 'PUT',
        data: data
      })
    },

    // 删除帖子
    delete: (id) => {
      return this.request({
        url: `/api/posts/${id}`,
        method: 'DELETE'
      })
    },

    // 点赞帖子
    like: (id) => {
      return this.request({
        url: `/api/posts/${id}/like`,
        method: 'POST'
      })
    },

    // 取消点赞
    unlike: (id) => {
      return this.request({
        url: `/api/posts/${id}/unlike`,
        method: 'DELETE'
      })
    },

    // 获取帖子评论
    getComments: (id, params = {}) => {
      return this.request({
        url: `/api/posts/${id}/comments`,
        method: 'GET',
        data: params
      })
    },

    // 添加评论
    addComment: (id, data) => {
      return this.request({
        url: `/api/posts/${id}/comments`,
        method: 'POST',
        data: data
      })
    },

    // 更新评论
    updateComment: (id, data) => {
      return this.request({
        url: `/api/comments/${id}`,
        method: 'PUT',
        data: data
      })
    },

    // 删除评论
    deleteComment: (id) => {
      return this.request({
        url: `/api/comments/${id}`,
        method: 'DELETE'
      })
    }
  }

  // 评论相关API
  comment = {
    // 更新评论
    update: (id, data) => {
      return this.request({
        url: `/api/comments/${id}`,
        method: 'PUT',
        data: data
      })
    },

    // 删除评论
    delete: (id) => {
      return this.request({
        url: `/api/comments/${id}`,
        method: 'DELETE'
      })
    }
  }

  // 图片上传API
  upload = {
    // 上传图片
    image: (filePath) => {
      return new Promise((resolve, reject) => {
        const token = wx.getStorageSync('token')
        wx.uploadFile({
          url: `${this.baseUrl}/api/upload/image`,
          filePath: filePath,
          name: 'file',
          header: {
            'Authorization': `Bearer ${token}`
          },
          success: (res) => {
            try {
              const data = JSON.parse(res.data)
              if (res.statusCode === 200) {
                resolve(data)
              } else {
                reject(new Error(data.error || '上传失败'))
              }
            } catch (e) {
              reject(new Error('响应格式错误'))
            }
          },
          fail: reject
        })
      })
    }
  }

  // 领读相关API
  leading = {
    // 获取领读内容
    getContent: (eventId, scheduleId) => {
      return this.request({
        url: `/api/reading_events/${eventId}/schedules/${scheduleId}/daily_leading`,
        method: 'GET'
      })
    },

    // 创建领读内容
    createContent: (eventId, scheduleId, data) => {
      return this.request({
        url: `/api/reading_events/${eventId}/schedules/${scheduleId}/daily_leading`,
        method: 'POST',
        data: data
      })
    },

    // 更新领读内容
    updateContent: (eventId, scheduleId, data) => {
      return this.request({
        url: `/api/reading_events/${eventId}/schedules/${scheduleId}/daily_leading`,
        method: 'PUT',
        data: data
      })
    }
  }

  // 打卡相关API
  checkIn = {
    // 获取打卡列表
    getList: (eventId, scheduleId) => {
      return this.request({
        url: `/api/reading_events/${eventId}/schedules/${scheduleId}/check_ins`,
        method: 'GET'
      })
    },

    // 创建打卡
    create: (eventId, scheduleId, data) => {
      return this.request({
        url: `/api/reading_events/${eventId}/schedules/${scheduleId}/check_ins`,
        method: 'POST',
        data: data
      })
    },

    // 获取打卡评论
    getComments: (checkInId) => {
      return this.request({
        url: `/api/check_ins/${checkInId}/comments`,
        method: 'GET'
      })
    },

    // 添加打卡评论
    addComment: (checkInId, data) => {
      return this.request({
        url: `/api/check_ins/${checkInId}/comments`,
        method: 'POST',
        data: data
      })
    }
  }

  // 小红花相关API
  flower = {
    // 获取小红花列表
    getList: (eventId, scheduleId) => {
      return this.request({
        url: `/api/reading_events/${eventId}/schedules/${scheduleId}/flowers`,
        method: 'GET'
      })
    },

    // 发放小红花
    give: (eventId, scheduleId, data) => {
      return this.request({
        url: `/api/reading_events/${eventId}/schedules/${scheduleId}/flowers`,
        method: 'POST',
        data: data
      })
    }
  }
}

// 导出API实例
module.exports = new API()