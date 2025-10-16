// util.js - 工具函数库

/**
 * 格式化时间
 * @param {Date|string} date 日期对象或时间字符串
 * @param {string} format 格式模板，默认 'YYYY-MM-DD HH:mm:ss'
 * @returns {string} 格式化后的时间字符串
 */
function formatTime(date, format = 'YYYY-MM-DD HH:mm:ss') {
  if (!date) return ''

  const d = new Date(date)
  if (isNaN(d.getTime())) return ''

  const year = d.getFullYear()
  const month = String(d.getMonth() + 1).padStart(2, '0')
  const day = String(d.getDate()).padStart(2, '0')
  const hour = String(d.getHours()).padStart(2, '0')
  const minute = String(d.getMinutes()).padStart(2, '0')
  const second = String(d.getSeconds()).padStart(2, '0')

  return format
    .replace('YYYY', year)
    .replace('MM', month)
    .replace('DD', day)
    .replace('HH', hour)
    .replace('mm', minute)
    .replace('ss', second)
}

/**
 * 相对时间格式化
 * @param {Date|string} date 日期对象或时间字符串
 * @returns {string} 相对时间字符串
 */
function formatRelativeTime(date) {
  if (!date) return ''

  const now = new Date()
  const target = new Date(date)
  if (isNaN(target.getTime())) return ''

  const diff = now.getTime() - target.getTime()
  const seconds = Math.floor(diff / 1000)
  const minutes = Math.floor(seconds / 60)
  const hours = Math.floor(minutes / 60)
  const days = Math.floor(hours / 24)

  if (days > 30) {
    return formatTime(date, 'YYYY-MM-DD')
  } else if (days > 0) {
    return `${days}天前`
  } else if (hours > 0) {
    return `${hours}小时前`
  } else if (minutes > 0) {
    return `${minutes}分钟前`
  } else {
    return '刚刚'
  }
}

/**
 * 格式化日期范围
 * @param {Date|string} startDate 开始日期
 * @param {Date|string} endDate 结束日期
 * @returns {string} 格式化后的日期范围字符串
 */
function formatDateRange(startDate, endDate) {
  if (!startDate || !endDate) return ''

  const start = new Date(startDate)
  const end = new Date(endDate)

  if (isNaN(start.getTime()) || isNaN(end.getTime())) return ''

  const startStr = formatTime(start, 'MM-DD')
  const endStr = formatTime(end, 'MM-DD')

  if (startStr === endStr) {
    return startStr
  } else {
    return `${startStr} 至 ${endStr}`
  }
}

/**
 * 计算天数差
 * @param {Date|string} startDate 开始日期
 * @param {Date|string} endDate 结束日期
 * @returns {number} 天数
 */
function daysBetween(startDate, endDate) {
  if (!startDate || !endDate) return 0

  const start = new Date(startDate)
  const end = new Date(endDate)

  if (isNaN(start.getTime()) || isNaN(end.getTime())) return 0

  const diff = end.getTime() - start.getTime()
  return Math.ceil(diff / (1000 * 60 * 60 * 24))
}

/**
 * 防抖函数
 * @param {Function} func 要防抖的函数
 * @param {number} wait 等待时间（毫秒）
 * @returns {Function} 防抖后的函数
 */
function debounce(func, wait) {
  let timeout
  return function executedFunction(...args) {
    const later = () => {
      clearTimeout(timeout)
      func(...args)
    }
    clearTimeout(timeout)
    timeout = setTimeout(later, wait)
  }
}

/**
 * 节流函数
 * @param {Function} func 要节流的函数
 * @param {number} limit 时间限制（毫秒）
 * @returns {Function} 节流后的函数
 */
function throttle(func, limit) {
  let inThrottle
  return function(...args) {
    if (!inThrottle) {
      func.apply(this, args)
      inThrottle = true
      setTimeout(() => inThrottle = false, limit)
    }
  }
}

/**
 * 深拷贝
 * @param {any} obj 要拷贝的对象
 * @returns {any} 拷贝后的对象
 */
function deepClone(obj) {
  if (obj === null || typeof obj !== 'object') return obj
  if (obj instanceof Date) return new Date(obj.getTime())
  if (obj instanceof Array) return obj.map(item => deepClone(item))
  if (typeof obj === 'object') {
    const clonedObj = {}
    for (const key in obj) {
      if (obj.hasOwnProperty(key)) {
        clonedObj[key] = deepClone(obj[key])
      }
    }
    return clonedObj
  }
}

/**
 * 检查是否为空值
 * @param {any} value 要检查的值
 * @returns {boolean} 是否为空
 */
function isEmpty(value) {
  return value === null || value === undefined || value === '' ||
    (Array.isArray(value) && value.length === 0) ||
    (typeof value === 'object' && Object.keys(value).length === 0)
}

/**
 * 生成随机字符串
 * @param {number} length 字符串长度
 * @returns {string} 随机字符串
 */
function randomString(length = 8) {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
  let result = ''
  for (let i = 0; i < length; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length))
  }
  return result
}

/**
 * 获取文件扩展名
 * @param {string} filename 文件名
 * @returns {string} 扩展名
 */
function getFileExtension(filename) {
  return filename.slice((filename.lastIndexOf('.') - 1 >>> 0) + 2)
}

/**
 * 格式化文件大小
 * @param {number} bytes 字节数
 * @returns {string} 格式化后的文件大小
 */
function formatFileSize(bytes) {
  if (bytes === 0) return '0 Bytes'

  const k = 1024
  const sizes = ['Bytes', 'KB', 'MB', 'GB']
  const i = Math.floor(Math.log(bytes) / Math.log(k))

  return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i]
}


/**
 * 邮箱验证
 * @param {string} email 邮箱
 * @returns {boolean} 是否有效
 */
function isValidEmail(email) {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
  return emailRegex.test(email)
}

/**
 * URL参数解析
 * @param {string} url URL字符串
 * @returns {Object} 参数对象
 */
function parseUrlParams(url) {
  const params = {}
  const queryString = url.split('?')[1]

  if (queryString) {
    queryString.split('&').forEach(param => {
      const [key, value] = param.split('=')
      params[decodeURIComponent(key)] = decodeURIComponent(value || '')
    })
  }

  return params
}

/**
 * 对象转URL参数
 * @param {Object} obj 参数对象
 * @returns {string} URL参数字符串
 */
function objectToUrlParams(obj) {
  return Object.keys(obj)
    .map(key => `${encodeURIComponent(key)}=${encodeURIComponent(obj[key])}`)
    .join('&')
}

/**
 * 获取小程序码
 * @param {string} scene 场景值
 * @param {Object} options 其他选项
 * @returns {Promise} 小程序码
 */
function getQRCode(scene, options = {}) {
  return new Promise((resolve, reject) => {
    wx.request({
      url: '/api/wxacode/get',
      method: 'POST',
      data: {
        scene,
        page: options.page || 'pages/index/index',
        width: options.width || 430
      },
      success: (res) => {
        if (res.statusCode === 200) {
          resolve(res.data)
        } else {
          reject(new Error('获取小程序码失败'))
        }
      },
      fail: reject
    })
  })
}

/**
 * 保存图片到相册
 * @param {string} filePath 图片路径
 * @returns {Promise} 保存结果
 */
function saveImageToPhotosAlbum(filePath) {
  return new Promise((resolve, reject) => {
    wx.saveImageToPhotosAlbum({
      filePath,
      success: resolve,
      fail: (error) => {
        if (error.errMsg.includes('auth deny')) {
          wx.showModal({
            title: '授权提示',
            content: '需要您授权保存图片到相册',
            success: (res) => {
              if (res.confirm) {
                wx.openSetting({
                  success: (settingRes) => {
                    if (settingRes.authSetting['scope.writePhotosAlbum']) {
                      wx.saveImageToPhotosAlbum({
                        filePath,
                        success: resolve,
                        fail: reject
                      })
                    } else {
                      reject(new Error('授权失败'))
                    }
                  }
                })
              } else {
                reject(new Error('用户拒绝授权'))
              }
            }
          })
        } else {
          reject(error)
        }
      }
    })
  })
}

/**
 * 显示确认对话框
 * @param {string} content 内容
 * @param {string} title 标题
 * @returns {Promise} 用户选择结果
 */
function showConfirm(content, title = '提示') {
  return new Promise((resolve) => {
    wx.showModal({
      title,
      content,
      success: (res) => {
        resolve(res.confirm)
      }
    })
  })
}

/**
 * 显示操作菜单
 * @param {Array} itemList 菜单项列表
 * @returns {Promise} 用户选择结果
 */
function showActionSheet(itemList) {
  return new Promise((resolve, reject) => {
    wx.showActionSheet({
      itemList,
      success: (res) => {
        resolve(res.tapIndex)
      },
      fail: reject
    })
  })
}

module.exports = {
  formatTime,
  formatRelativeTime,
  formatDateRange,
  daysBetween,
  debounce,
  throttle,
  deepClone,
  isEmpty,
  randomString,
  getFileExtension,
  formatFileSize,
  isValidEmail,
  parseUrlParams,
  objectToUrlParams,
  getQRCode,
  saveImageToPhotosAlbum,
  showConfirm,
  showActionSheet
}