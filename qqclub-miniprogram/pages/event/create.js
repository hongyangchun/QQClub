// pages/event/create.js
const app = getApp()

Page({
  data: {
    // 当前步骤
    currentStep: 1,

    // 步骤1：基本信息
    title: '',
    bookName: '',
    bookCoverUrl: '',
    description: '',

    // 步骤2：活动设置
    startDate: '',
    endDate: '',
    enrollmentDeadline: '',
    maxParticipants: 25,
    minParticipants: 10,
    activityMode: 'note_checkin',
    activityModeDesc: '',
    activityModeLabel: '笔记打卡',

    // 步骤3：高级设置
    feeType: 'free',
    feeTypeDesc: '',
    feeTypeLabel: '免费',
    feeAmount: 0,
    leaderRewardPercentage: 20,
    weekendRest: false,
    completionStandard: '80',
    leaderAssignmentType: 'voluntary',
    leaderAssignmentDesc: '',
    leaderAssignmentLabel: '自愿报名',

    // 选项数据
    activityModes: [
      { value: 'note_checkin', label: '笔记打卡', desc: '通过写笔记的方式进行每日打卡' },
      { value: 'free_discussion', label: '自由讨论', desc: '开放式话题讨论，自由交流读书心得' },
      { value: 'video_conference', label: '视频会议', desc: '定期组织视频会议进行线下交流' },
      { value: 'offline_meeting', label: '线下交流', desc: '面对面读书分享和交流活动' }
    ],

    feeTypes: [
      { value: 'free', label: '免费', desc: '无费用参与' },
      { value: 'deposit', label: '押金制', desc: '收取押金，完成活动后退还' },
      { value: 'paid', label: '收费制', desc: '付费参与活动' }
    ],

    leaderAssignmentTypes: [
      { value: 'voluntary', label: '自愿报名', desc: '参与者自愿报名领读' },
      { value: 'random', label: '随机领读', desc: '系统随机分配领读人' },
      { value: 'disabled', label: '无领读', desc: '不设置领读人环节' }
    ],

    // UI状态
    submitting: false,
    showActivityModePicker: false,
    showFeeTypePicker: false,
    showLeaderAssignmentPicker: false
  },

  onLoad(options) {
    // 设置默认日期
    const today = new Date()
    const tomorrow = new Date(today.getTime() + 24 * 60 * 60 * 1000)
    const nextWeek = new Date(today.getTime() + 7 * 24 * 60 * 60 * 1000)

    // 设置报名截止时间为活动开始前的几个小时，确保在活动开始之前
    const enrollmentDeadline = new Date(tomorrow.getTime() - 2 * 60 * 60 * 1000) // 活动开始前2小时

    this.setData({
      startDate: this.formatDate(tomorrow),  // 活动从明天开始
      endDate: this.formatDate(nextWeek),
      enrollmentDeadline: this.formatDateTime(enrollmentDeadline)  // 报名截止在活动开始前
    })

    // 初始化描述信息
    this.updateDescriptions()
  },

  // 步骤控制
  nextStep() {
    if (this.validateCurrentStep()) {
      if (this.data.currentStep < 3) {
        this.setData({
          currentStep: this.data.currentStep + 1
        })
      }
    }
  },

  prevStep() {
    if (this.data.currentStep > 1) {
      this.setData({
        currentStep: this.data.currentStep - 1
      })
    }
  },

  // 验证当前步骤
  validateCurrentStep() {
    switch (this.data.currentStep) {
      case 1:
        return this.validateStep1()
      case 2:
        return this.validateStep2()
      case 3:
        return this.validateStep3()
      default:
        return true
    }
  },

  validateStep1() {
    const { title, bookName } = this.data
    const errors = []

    if (!title.trim()) {
      errors.push('请输入活动标题')
    } else if (title.length < 5) {
      errors.push('活动标题至少需要5个字符')
    }

    if (!bookName.trim()) {
      errors.push('请输入书籍名称')
    }

    if (errors.length > 0) {
      wx.showToast({
        title: errors[0],
        icon: 'none',
        duration: 3000
      })
      return false
    }
    return true
  },

  validateStep2() {
    const { startDate, endDate, maxParticipants, minParticipants } = this.data
    const errors = []

    if (!startDate || !endDate) {
      errors.push('请选择活动开始和结束日期')
    } else if (new Date(endDate) < new Date(startDate)) {
      errors.push('结束日期不能早于开始日期')
    }

    const maxNum = parseInt(maxParticipants) || 0
    const minNum = parseInt(minParticipants) || 0

    if (maxNum <= 0) {
      errors.push('最大参与人数必须大于0')
    }

    if (minNum <= 0) {
      errors.push('最小参与人数必须大于0')
    }

    if (minNum > maxNum) {
      errors.push('最小参与人数不能大于最大参与人数')
    }

    if (errors.length > 0) {
      wx.showToast({
        title: errors[0],
        icon: 'none',
        duration: 3000
      })
      return false
    }
    return true
  },

  validateStep3() {
    const { feeAmount, leaderRewardPercentage, completionStandard } = this.data
    const errors = []

    const feeNum = parseFloat(feeAmount) || 0
    const rewardNum = parseFloat(leaderRewardPercentage) || 0
    const standardNum = parseInt(completionStandard) || 0

    if (this.data.feeType !== 'free' && feeNum <= 0) {
      errors.push('收费活动必须设置费用金额')
    }

    if (rewardNum < 0 || rewardNum > 100) {
      errors.push('领读人奖励比例必须在0-100之间')
    }

    if (standardNum < 60 || standardNum > 100) {
      errors.push('完成标准必须在60-100之间')
    }

    if (errors.length > 0) {
      wx.showToast({
        title: errors[0],
        icon: 'none',
        duration: 3000
      })
      return false
    }
    return true
  },

  // 表单输入处理
  onTitleInput(e) {
    this.setData({ title: e.detail.value })
  },

  onBookNameInput(e) {
    this.setData({ bookName: e.detail.value })
  },

  onDescriptionInput(e) {
    this.setData({ description: e.detail.value })
  },

  onMaxParticipantsInput(e) {
    let value = e.detail.value
    if (value === '') {
      // 如果输入为空，先保存空字符串
      this.setData({ maxParticipants: '' })
      return
    }

    value = parseInt(value) || 25
    if (value > 0) {
      this.setData({
        maxParticipants: value,
        minParticipants: Math.min(this.data.minParticipants, value)
      })
    }
  },

  onMinParticipantsInput(e) {
    let value = e.detail.value
    if (value === '') {
      // 如果输入为空，先保存空字符串
      this.setData({ minParticipants: '' })
      return
    }

    value = parseInt(value) || 10
    if (value > 0) {
      this.setData({
        minParticipants: Math.min(value, this.data.maxParticipants)
      })
    }
  },

  onFeeAmountInput(e) {
    let value = e.detail.value
    if (value === '') {
      this.setData({ feeAmount: '' })
      return
    }
    value = parseFloat(value) || 0
    this.setData({ feeAmount: value })
  },

  onLeaderRewardInput(e) {
    let value = e.detail.value
    if (value === '') {
      this.setData({ leaderRewardPercentage: '' })
      return
    }
    value = parseFloat(value) || 20
    this.setData({ leaderRewardPercentage: Math.min(Math.max(value, 0), 100) })
  },

  onCompletionStandardInput(e) {
    let value = e.detail.value
    console.log('完成标准输入:', value, '类型:', typeof value)

    // 允许空值
    if (value === '' || value === undefined) {
      console.log('设置为空字符串')
      this.setData({ completionStandard: '' })
      return
    }

    // 转换为数字并验证范围
    const parsedValue = parseInt(value)
    console.log('解析后的值:', parsedValue, '是否NaN:', isNaN(parsedValue))

    // 如果是NaN或无效值，使用默认值80
    const finalValue = isNaN(parsedValue) ? 80 : parsedValue
    console.log('最终值:', finalValue)

    // 限制在60-100范围内
    const constrainedValue = Math.min(Math.max(finalValue, 60), 100)
    console.log('约束后的值:', constrainedValue)

    // 保存为字符串以避免input显示问题
    this.setData({ completionStandard: constrainedValue.toString() })
  },

  // 日期选择处理
  onStartDateChange(e) {
    const { value } = e.detail
    this.setData({
      startDate: value
    })
    // 确保结束日期不早于开始日期
    if (this.data.endDate < value) {
      this.setData({ endDate: value })
    }
    // 确保报名截止时间不晚于活动开始时间
    if (this.data.enrollmentDeadline && this.data.enrollmentDeadline >= value + ' 00:00') {
      // 如果报名截止时间晚于或等于活动开始时间，设置为活动开始前1小时
      const startTime = new Date(value + ' 00:00')
      const newDeadline = new Date(startTime.getTime() - 60 * 60 * 1000) // 1小时前
      this.setData({ enrollmentDeadline: this.formatDateTime(newDeadline) })
    }
  },

  onEndDateChange(e) {
    const { value } = e.detail
    this.setData({
      endDate: value
    })
  },

  onEnrollmentDeadlineChange(e) {
    const { value } = e.detail
    // 验证报名截止时间不能晚于活动开始时间
    if (this.data.startDate && value >= this.data.startDate + ' 00:00') {
      wx.showToast({
        title: '报名截止时间必须在活动开始之前',
        icon: 'none',
        duration: 3000
      })
      return // 不更新数据
    }
    this.setData({
      enrollmentDeadline: value
    })
  },

  // 选择器处理
  showActivityModePicker() {
    this.setData({ showActivityModePicker: true })
  },

  hideActivityModePicker() {
    this.setData({ showActivityModePicker: false })
  },

  onActivityModeSelect(e) {
    const { value } = e.currentTarget.dataset
    const selectedMode = this.data.activityModes.find(m => m.value === value)
    this.setData({
      activityMode: value,
      activityModeLabel: selectedMode ? selectedMode.label : value,
      showActivityModePicker: false
    })
    this.updateDescriptions()
  },

  showFeeTypePicker() {
    this.setData({ showFeeTypePicker: true })
  },

  hideFeeTypePicker() {
    this.setData({ showFeeTypePicker: false })
  },

  onFeeTypeSelect(e) {
    const { value } = e.currentTarget.dataset
    const selectedType = this.data.feeTypes.find(t => t.value === value)
    this.setData({
      feeType: value,
      feeTypeLabel: selectedType ? selectedType.label : value,
      showFeeTypePicker: false
    })
    this.updateDescriptions()
  },

  showLeaderAssignmentPicker() {
    this.setData({ showLeaderAssignmentPicker: true })
  },

  hideLeaderAssignmentPicker() {
    this.setData({ showLeaderAssignmentPicker: false })
  },

  onLeaderAssignmentSelect(e) {
    const { value } = e.currentTarget.dataset
    const selectedType = this.data.leaderAssignmentTypes.find(t => t.value === value)
    this.setData({
      leaderAssignmentType: value,
      leaderAssignmentLabel: selectedType ? selectedType.label : value,
      showLeaderAssignmentPicker: false
    })
    this.updateDescriptions()
  },

  // 开关处理
  onWeekendRestChange(e) {
    this.setData({ weekendRest: e.detail.value })
  },

  // 书籍封面搜索
  searchBookCover(bookName) {
    if (!bookName || bookName.trim().length < 2) {
      return
    }

    // 防抖处理，避免频繁搜索
    if (this.searchTimer) {
      clearTimeout(this.searchTimer)
    }

    this.searchTimer = setTimeout(() => {
      this.performBookSearch(bookName.trim())
    }, 800)
  },

  // 执行书籍搜索 - 简化版本
  performBookSearch(bookName) {
    wx.showLoading({ title: '搜索书籍封面中...' })

    // 优先尝试OpenLibrary（更稳定）
    this.searchOpenLibrary(bookName).then(results => {
      if (results.length > 0) {
        const bookWithCover = results.find(book => book.coverUrl) || results[0]
        if (bookWithCover.coverUrl) {
          this.setData({ bookCoverUrl: bookWithCover.coverUrl })
          wx.showToast({
            title: '已找到书籍封面',
            icon: 'success',
            duration: 1500
          })
        } else {
          wx.showToast({
            title: '未找到封面，建议手动上传',
            icon: 'none',
            duration: 2000
          })
        }
      } else {
        // 尝试Google Books（可能无法访问）
        this.searchGoogleBooks(bookName).then(googleResults => {
          if (googleResults.length > 0) {
            const bookWithCover = googleResults.find(book => book.coverUrl) || googleResults[0]
            if (bookWithCover.coverUrl) {
              this.setData({ bookCoverUrl: bookWithCover.coverUrl })
              wx.showToast({
                title: '已找到书籍封面',
                icon: 'success',
                duration: 1500
              })
            } else {
              wx.showToast({
                title: '未找到封面，建议手动上传',
                icon: 'none',
                duration: 2000
              })
            }
          } else {
            wx.showToast({
              title: '未找到相关书籍，请手动上传封面',
              icon: 'none',
              duration: 2000
            })
          }
        }).catch(() => {
          // Google Books访问失败时
          wx.showToast({
            title: '搜索服务暂不可用，请手动上传',
            icon: 'none',
            duration: 2000
          })
        })
      }
    }).catch(() => {
      // 所有搜索都失败时
      wx.showToast({
        title: '搜索服务暂不可用，请手动上传封面',
        icon: 'none',
        duration: 2000
      })
    }).finally(() => {
      wx.hideLoading()
    })
  },

  // 清理书名，去除多余空格和特殊字符
  cleanBookName(bookName) {
    if (!bookName) return ''

    return bookName
      .trim()                           // 去除首尾空格
      .replace(/\s+/g, ' ')            // 多个空格合并为一个
      .replace(/[《》【】""''\(\)\[\]]/g, '') // 去除常见的书名符号
      .replace(/[:：:]/g, '')          // 去除冒号
  },

  // 生成搜索策略
  generateSearchStrategies(bookName) {
    const strategies = []

    // 1. 精确匹配（完全相同）
    strategies.push(bookName)

    // 2. 去除可能的副标题
    const mainTitle = bookName.split(/[：:——]/)[0].trim()
    if (mainTitle !== bookName && mainTitle.length > 0) {
      strategies.push(mainTitle)
    }

    // 3. 关键词匹配（取前几个关键词）
    const keywords = bookName.split(/\s+/).filter(word => word.length > 0)
    if (keywords.length > 1) {
      strategies.push(keywords.slice(0, 2).join(' '))
      if (keywords.length > 2) {
        strategies.push(keywords.slice(0, 3).join(' '))
      }
    }

    // 4. 英文翻译映射（针对经典中文书籍）
    const translations = {
      '系统之美': 'Systems Thinking',
      '系统思维': 'Systems Thinking',
      '深度工作': 'Deep Work',
      '原子习惯': 'Atomic Habits',
      '福格行为模型': 'Tiny Habits',
      '思考快与慢': 'Thinking Fast and Slow',
      '原则': 'Principles',
      '人性的弱点': 'How to Win Friends and Influence People',
      '穷查理宝典': 'The Poor Charlie Almanack',
      '刻意练习': 'Deliberate Practice'
    }

    if (translations[bookName]) {
      strategies.push(translations[bookName])
    }

    // 去重
    return [...new Set(strategies)].filter(s => s.length > 0)
  },

  // 搜索结果排序算法
  rankSearchResults(searchQuery, results) {
    return results
      .map(result => {
        let score = 0

        // 完全匹配得分最高
        if (result.title === searchQuery) {
          score += 100
        }

        // 包含完整查询
        if (result.title.includes(searchQuery)) {
          score += 50
        }

        // 包含主要关键词
        const searchWords = searchQuery.split(/\s+/)
        searchWords.forEach(word => {
          if (result.title.includes(word)) {
            score += 20
          }
        })

        // 标题长度匹配度（避免过长的无关结果）
        const titleLengthDiff = Math.abs(result.title.length - searchQuery.length)
        if (titleLengthDiff < 5) {
          score += 10
        } else if (titleLengthDiff < 10) {
          score += 5
        }

        // Google Books优先（中文支持更好）
        if (result.source === 'google') {
          score += 5
        }

        return { ...result, score }
      })
      .filter(result => result.score > 0)  // 过滤掉得分太低的
      .sort((a, b) => b.score - a.score)      // 按得分排序
  },

  // Google Books API 搜索
  searchGoogleBooks(bookName) {
    return new Promise((resolve) => {
      const apiUrl = `https://www.googleapis.com/books/v1/volumes?q=${encodeURIComponent(bookName)}&maxResults=5&fields=items(id,volumeInfo(title,authors,imageLinks,industryIdentifiers))`

      wx.request({
        url: apiUrl,
        method: 'GET',
        header: {
          'Content-Type': 'application/json'
        },
        success: (res) => {
          console.log('Google Books搜索响应:', res)

          if (res.statusCode === 200 && res.data && res.data.items) {
            const results = res.data.items.map(item => ({
              source: 'google',
              title: item.volumeInfo.title,
              authors: item.volumeInfo.authors || [],
              coverUrl: item.volumeInfo.imageLinks?.thumbnail || item.volumeInfo.imageLinks?.smallThumbnail,
              isbn: item.volumeInfo.industryIdentifiers?.find(id => id.type === 'ISBN_13')?.identifier
            })).filter(book => book.coverUrl) // 只要带封面的

            console.log('Google Books有效结果:', results.length)
            resolve(results)
          } else {
            resolve([])
          }
        },
        fail: (err) => {
          console.error('Google Books搜索失败:', err)
          resolve([])
        }
      })
    })
  },

  // OpenLibrary API 搜索
  searchOpenLibrary(bookName) {
    return new Promise((resolve) => {
      const apiUrl = `https://openlibrary.org/search.json?q=${encodeURIComponent(bookName)}&limit=5&fields=cover_i,title,author_name,key,isbn,first_publish_year,language`

      wx.request({
        url: apiUrl,
        method: 'GET',
        header: {
          'Content-Type': 'application/json'
        },
        success: (res) => {
          console.log('OpenLibrary搜索响应:', res)

          if (res.statusCode === 200 && res.data && res.data.docs && res.data.docs.length > 0) {
            const results = res.data.docs.map(doc => ({
              source: 'openlibrary',
              title: doc.title,
              authors: doc.author_name || [],
              coverUrl: doc.cover_i ? `https://covers.openlibrary.org/b/id/${doc.cover_i}-L.jpg` : null,
              isbn: doc.isbn?.find(isbn => isbn.length === 13)
            })).filter(book => book.coverUrl) // 只要带封面的

            console.log('OpenLibrary有效结果:', results.length)
            resolve(results)
          } else {
            resolve([])
          }
        },
        fail: (err) => {
          console.error('OpenLibrary搜索失败:', err)
          resolve([])
        }
      })
    })
  },

  // WorldCat API 搜索 (世界最大的图书馆目录)
  searchWorldCat(bookName) {
    return new Promise((resolve) => {
      // WorldCat的开放搜索API
      const apiUrl = `https://www.worldcat.org/webservices/catalog/search/worldcat/opensearch?q=${encodeURIComponent(bookName)}&format=json&wskey=YOUR_API_KEY`

      // 由于WorldCat需要API密钥，这里作为占位符
      // 在实际使用中需要申请API密钥
      console.log('WorldCat搜索暂未配置API密钥')
      resolve([])
    })
  },

  // 添加更多中文搜索源的占位符
  searchChineseBookSources(bookName) {
    return new Promise((resolve) => {
      // 这里可以添加其他中文书籍API
      // 例如：孔夫子旧书网、当当网开放API等
      resolve([])
    })
  },

  // 备用书籍搜索（使用OpenLibrary）
  performBackupBookSearch(bookName) {
    wx.showLoading({ title: '使用备用搜索...' })

    // 使用OpenLibrary作为备用
    const apiUrl = `https://openlibrary.org/search.json?q=${encodeURIComponent(bookName)}&limit=3&fields=cover_i,title,author_name,key`

    wx.request({
      url: apiUrl,
      method: 'GET',
      success: (res) => {
        if (res.data && res.data.docs && res.data.docs.length > 0) {
          const firstBook = res.data.docs[0]
          if (firstBook.cover_i) {
            const coverUrl = `https://covers.openlibrary.org/b/id/${firstBook.cover_i}-L.jpg`
            this.setData({ bookCoverUrl: coverUrl })
            wx.showToast({
              title: '已找到书籍封面',
              icon: 'success',
              duration: 1500
            })
          } else {
            this.setData({ bookCoverUrl: '' })
            wx.showToast({
              title: '未找到封面',
              icon: 'none',
              duration: 1500
            })
          }
        } else {
          this.setData({ bookCoverUrl: '' })
          wx.showToast({
            title: '未找到相关书籍',
            icon: 'none',
            duration: 1500
          })
        }
      },
      fail: (err) => {
        console.error('备用搜索失败:', err)
        wx.showToast({
          title: '搜索失败，请手动上传',
          icon: 'none',
          duration: 2000
        })
      },
      complete: () => {
        wx.hideLoading()
      }
    })
  },

  // 手动搜索书籍封面
  searchBookCover() {
    const { bookName } = this.data
    if (!bookName || bookName.trim().length < 2) {
      wx.showToast({
        title: '请输入至少2个字符的书名',
        icon: 'none',
        duration: 2000
      })
      return
    }

    this.performBookSearch(bookName.trim())
  },

  // 选择书籍封面（支持手动上传和手动搜索）
  chooseBookCover() {
    wx.showActionSheet({
      itemList: ['拍照', '从相册选择'],
      success: (res) => {
        switch (res.tapIndex) {
          case 0: // 拍照
            this.chooseImage('camera')
            break
          case 1: // 从相册选择
            this.chooseImage('album')
            break
        }
      },
      fail: (err) => {
        console.error('显示选择菜单失败:', err)
      }
    })
  },

  // 选择图片
  chooseImage(sourceType) {
    wx.chooseImage({
      count: 1,
      sizeType: ['compressed'],
      sourceType: [sourceType],
      success: (res) => {
        const tempFilePath = res.tempFilePaths[0]
        this.uploadBookCover(tempFilePath)
      },
      fail: (err) => {
        console.error('选择图片失败:', err)
        wx.showToast({
          title: '选择图片失败',
          icon: 'none',
          duration: 2000
        })
      }
    })
  },

  // 上传书籍封面
  uploadBookCover(filePath) {
    wx.showLoading({ title: '上传中...' })

    wx.uploadFile({
      url: `${app.globalData.baseUrl}/api/upload/image`,
      filePath: filePath,
      name: 'image',
      header: {
        'Authorization': `Bearer ${app.globalData.token}`
      },
      success: (res) => {
        try {
          const data = JSON.parse(res.data)
          if (data.success || data.code === 200) {
            this.setData({ bookCoverUrl: data.data.url })
            wx.showToast({
              title: '封面上传成功',
              icon: 'success',
              duration: 1500
            })
          } else {
            wx.showToast({
              title: data.message || '上传失败',
              icon: 'none',
              duration: 2000
            })
          }
        } catch (e) {
          console.error('解析上传响应失败:', e)
          wx.showToast({
            title: '上传响应格式错误',
            icon: 'none',
            duration: 2000
          })
        }
      },
      fail: (err) => {
        console.error('上传封面上传失败:', err)
        wx.showToast({
          title: '上传失败，请重试',
          icon: 'none',
          duration: 2000
        })
      },
      complete: () => {
        wx.hideLoading()
      }
    })
  },

  // 提交表单
  submitForm() {
    if (!this.validateCurrentStep()) {
      return
    }

    if (this.data.submitting) {
      return
    }

    this.setData({ submitting: true })
    wx.showLoading({ title: '创建中...' })

    const formData = {
      reading_event: {
        title: this.data.title.trim(),
        book_name: this.data.bookName.trim(),
        book_cover_url: this.data.bookCoverUrl,
        description: this.data.description.trim(),
        start_date: this.data.startDate,
        end_date: this.data.endDate,
        enrollment_deadline: this.data.enrollmentDeadline,
        max_participants: parseInt(this.data.maxParticipants) || 25,
        min_participants: parseInt(this.data.minParticipants) || 10,
        activity_mode: this.data.activityMode,
        fee_type: this.data.feeType,
        fee_amount: parseFloat(this.data.feeAmount) || 0,
        leader_reward_percentage: parseFloat(this.data.leaderRewardPercentage) || 20,
        weekend_rest: this.data.weekendRest,
        completion_standard: parseInt(this.data.completionStandard) || 80,
        leader_assignment_type: this.data.leaderAssignmentType
      }
    }

    wx.request({
      url: `${app.globalData.baseUrl}/api/v1/reading_events`,
      method: 'POST',
      header: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${app.globalData.token}`
      },
      data: formData,
      success: (res) => {
        console.log('API响应:', res)

        // 检查响应数据是否存在
        if (!res.data) {
          wx.showToast({
            title: '服务器响应异常',
            icon: 'none',
            duration: 3000
          })
          return
        }

        // 检查HTTP状态码
        if (res.statusCode >= 200 && res.statusCode < 300) {
          // 检查业务状态码
          if (res.data.success || res.data.code === 200) {
            wx.showToast({ title: '创建成功', icon: 'success' })
            setTimeout(() => {
              wx.navigateBack()
            }, 1500)
          } else {
            wx.showToast({
              title: res.data.message || res.data.error || '创建失败',
              icon: 'none',
              duration: 3000
            })
          }
        } else {
          // HTTP错误
          wx.showToast({
            title: `服务器错误: ${res.statusCode}`,
            icon: 'none',
            duration: 3000
          })
        }
      },
      fail: (err) => {
        console.error('创建活动失败:', err)
        wx.showToast({
          title: '网络错误，请重试',
          icon: 'none',
          duration: 3000
        })
      },
      complete: () => {
        this.setData({ submitting: false })
        wx.hideLoading()
      }
    })
  },

  // 更新描述信息
  updateDescriptions() {
    const activityMode = this.data.activityModes.find(m => m.value === this.data.activityMode)
    const feeType = this.data.feeTypes.find(t => t.value === this.data.feeType)
    const leaderAssignmentType = this.data.leaderAssignmentTypes.find(t => t.value === this.data.leaderAssignmentType)

    this.setData({
      activityModeDesc: activityMode ? activityMode.desc : '',
      feeTypeDesc: feeType ? feeType.desc : '',
      leaderAssignmentDesc: leaderAssignmentType ? leaderAssignmentType.desc : ''
    })
  },

  // 工具方法
  formatDate(date) {
    const year = date.getFullYear()
    const month = String(date.getMonth() + 1).padStart(2, '0')
    const day = String(date.getDate()).padStart(2, '0')
    return `${year}-${month}-${day}`
  },

  formatDateTime(date) {
    const year = date.getFullYear()
    const month = String(date.getMonth() + 1).padStart(2, '0')
    const day = String(date.getDate()).padStart(2, '0')
    const hours = String(date.getHours()).padStart(2, '0')
    const minutes = String(date.getMinutes()).padStart(2, '0')
    return `${year}-${month}-${day} ${hours}:${minutes}`
  },

  // 显示预览
  showPreview() {
    if (this.validateStep3()) {
      this.setData({
        currentStep: 4
      })
    }
  }

  })