// pages/auth/auth.js
const app = getApp()
const api = require('../../utils/api')
const util = require('../../utils/util')

Page({
  data: {
    // 表单数据
    agreed: false,

    // 加载状态
    wechatLoading: false,

    // 协议弹窗
    showAgreementModal: false,
    agreementTitle: '',
    agreementContent: ''
  },

  onLoad() {
    // 检查是否已经登录
    const userInfo = wx.getStorageSync('userInfo')
    if (userInfo) {
      this.redirectToHome()
    }
  },

  // 模拟登录
  async mockLogin() {
    if (!this.checkAgreement()) return

    this.setData({ wechatLoading: true })

    try {
      // 直接模拟登录成功，用于开发测试
      const mockResponse = {
        token: 'mock_token_' + Date.now(),
        user: {
          id: 1,
          openid: 'test_dhh_001',
          nickname: 'DHH',
          avatar_url: 'https://picsum.photos/100/100?random=dhh',
          role: 'user',
          created_at: new Date().toISOString()
        }
      }

      await this.handleLoginSuccess(mockResponse)
    } catch (error) {
      console.error('模拟登录失败:', error)
      app.showToast('登录失败，请重试')
    } finally {
      this.setData({ wechatLoading: false })
    }
  },

  // 微信登录
  async wechatLogin(e) {
    if (!this.checkAgreement()) return

    const userInfo = e.detail.userInfo
    if (!userInfo) {
      app.showToast('需要授权用户信息')
      return
    }

    this.setData({ wechatLoading: true })

    try {
      // 先获取微信登录凭证
      const loginRes = await new Promise((resolve, reject) => {
        wx.login({
          success: resolve,
          fail: reject
        })
      })

      if (!loginRes.code) {
        throw new Error('获取微信登录凭证失败')
      }

      // 调用后端微信登录接口
      const response = await api.auth.wechatLogin(loginRes.code)

      // 后端直接返回数据，不需要检查 success 字段
      if (response.token && response.user) {
        await this.handleLoginSuccess(response)
      } else {
        app.showToast('微信登录失败，请重试')
      }
    } catch (error) {
      console.error('微信登录失败:', error)
      app.showToast('网络错误，请重试')
    } finally {
      this.setData({ wechatLoading: false })
    }
  },

  
  // 处理登录成功
  async handleLoginSuccess(data) {
    const { token, user } = data

    // 保存到本地存储
    wx.setStorageSync('token', token)
    wx.setStorageSync('userInfo', user)

    // 更新全局数据
    app.globalData.token = token
    app.globalData.userInfo = user

    app.showToast('登录成功', 'success')

    // 延迟跳转，让用户看到成功提示
    setTimeout(() => {
      this.redirectToHome()
    }, 1500)
  },

  // 跳转到首页
  redirectToHome() {
    wx.reLaunch({
      url: '/pages/index/index'
    })
  },

  // 检查协议同意
  checkAgreement() {
    if (!this.data.agreed) {
      app.showToast('请先同意用户协议和隐私政策')
      return false
    }
    return true
  },

  // 切换协议同意状态
  toggleAgreement() {
    this.setData({
      agreed: !this.data.agreed
    })
  },

  // 显示用户协议
  showUserAgreement() {
    this.setData({
      showAgreementModal: true,
      agreementTitle: '用户协议',
      agreementContent: `恰恰读书会用户协议

1. 服务条款的接受
欢迎使用恰恰读书会服务。本协议是您与恰恰读书会之间关于使用本服务的法律协议。

2. 服务内容
恰恰读书会是一个基于微信的读书社群平台，为用户提供读书活动组织、打卡分享、社群交流等功能。

3. 用户义务
用户在使用本服务时必须遵守相关法律法规，不得发布违法信息，不得侵犯他人权益。

4. 隐私保护
我们重视用户隐私保护，将按照相关法律法规和本协议约定收集、使用、存储您的个人信息。

5. 知识产权
平台上的内容受知识产权法保护，未经授权不得复制、传播。

6. 免责声明
本服务按"现状"提供，不保证服务一定能满足用户的要求。

7. 协议修改
我们有权根据需要修改本协议条款，修改后的协议将在平台上公布。

8. 争议解决
因本协议引起的争议，双方应友好协商解决。

更新日期：2024年1月1日`
    })
  },

  // 显示隐私政策
  showPrivacyPolicy() {
    this.setData({
      showAgreementModal: true,
      agreementTitle: '隐私政策',
      agreementContent: `恰恰读书会隐私政策

我们重视您的隐私保护。本政策说明了我们如何收集、使用、存储和保护您的个人信息。

1. 信息收集
我们可能收集的信息包括：
- 微信基本信息（昵称、头像等）
- 设备信息（用于优化服务体验）
- 使用行为数据（用于改进服务）

2. 信息使用
收集的信息将用于：
- 提供和改进服务
- 用户身份验证
- 客户服务支持
- 安全防护和风险监控

3. 信息保护
我们采用行业标准的安全措施保护您的个人信息：
- 数据加密传输和存储
- 访问权限控制
- 定期安全审计

4. 信息共享
除以下情况外，我们不会向第三方共享您的个人信息：
- 获得您的明确同意
- 法律法规要求
- 保护用户或公众安全

5. 用户权利
您有权：
- 访问和更新个人信息
- 删除个人账号
- 撤销授权同意
- 投诉举报

6. Cookie使用
我们使用Cookie和类似技术来改善用户体验，您可以通过浏览器设置控制Cookie。

7. 政策更新
我们可能会更新本隐私政策，重大变更将通知用户。

8. 联系我们
如有隐私相关问题，请通过客服渠道联系我们。

更新日期：2024年1月1日`
    })
  },

  // 隐藏协议弹窗
  hideAgreementModal() {
    this.setData({
      showAgreementModal: false
    })
  },

  })