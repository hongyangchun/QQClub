/**
 * 活动状态管理器
 * 用于统一管理用户在活动中的状态、权限和页面导航逻辑
 */

class EventStateManager {
  constructor() {
    this.cache = new Map(); // 缓存活动状态数据
  }

  /**
   * 获取用户在活动中的角色
   * @param {Object} eventData 活动数据
   * @param {Object} userInfo 用户信息
   * @returns {String} 用户角色：guest, observer, participant, organizer
   */
  getUserRole(eventData, userInfo) {
    if (!userInfo) {
      return 'guest';
    }

    const userId = userInfo.id;

    // 检查是否为组织者
    if (eventData.leader && eventData.leader.id === userId) {
      return 'organizer';
    }

    // 检查报名信息
    if (eventData.user_enrollment) {
      return eventData.user_enrollment.enrollment_type === 'participant' ? 'participant' : 'observer';
    }

    return 'guest';
  }

  /**
   * 检查用户权限
   * @param {String} role 用户角色
   * @param {String} action 操作类型
   * @returns {Boolean} 是否有权限
   */
  hasPermission(role, action) {
    const permissions = {
      guest: ['view_basic_info'],
      observer: ['view_basic_info', 'view_content', 'view_stats'],
      participant: ['view_basic_info', 'view_content', 'view_stats', 'submit_checkin', 'give_flowers', 'participate_discussion'],
      organizer: ['view_basic_info', 'view_content', 'view_stats', 'submit_checkin', 'give_flowers', 'participate_discussion', 'manage_event', 'view_participants']
    };

    return permissions[role] && permissions[role].includes(action);
  }

  /**
   * 获取用户可以访问的页面
   * @param {String} role 用户角色
   * @returns {Array} 可访问的页面列表
   */
  getAccessiblePages(role) {
    const pages = {
      guest: ['detail'],
      observer: ['detail', 'observe'],
      participant: ['detail', 'participate', 'observe'],
      organizer: ['detail', 'participate', 'observe', 'manage']
    };

    return pages[role] || ['detail'];
  }

  /**
   * 获取推荐的导航页面
   * @param {String} role 用户角色
   * @param {Object} eventData 活动数据
   * @returns {Object} 推荐导航信息 {page, reason}
   */
  getRecommendedNavigation(role, eventData) {
    switch (role) {
      case 'guest':
        return {
          page: 'detail',
          reason: '请先报名参与活动'
        };

      case 'observer':
        if (eventData.can_enroll) {
          return {
            page: 'observe',
            reason: '您可以升级为参与者获得完整体验'
          };
        }
        return {
          page: 'observe',
          reason: '查看精选内容和活动动态'
        };

      case 'participant':
        return {
          page: 'participate',
          reason: '查看今日任务和提交打卡'
        };

      case 'organizer':
        return {
          page: 'participate',
          reason: '管理活动和查看参与者状态'
        };

      default:
        return {
          page: 'detail',
          reason: '查看活动详情'
        };
    }
  }

  /**
   * 缓存活动状态
   * @param {String} eventId 活动ID
   * @param {Object} state 状态数据
   */
  cacheEventState(eventId, state) {
    this.cache.set(eventId, {
      ...state,
      timestamp: Date.now()
    });
  }

  /**
   * 获取缓存的活动状态
   * @param {String} eventId 活动ID
   * @param {Number} maxAge 最大缓存时间（毫秒）
   * @returns {Object|null} 缓存的状态数据
   */
  getCachedState(eventId, maxAge = 5 * 60 * 1000) { // 默认5分钟缓存
    const cached = this.cache.get(eventId);
    if (!cached) return null;

    if (Date.now() - cached.timestamp > maxAge) {
      this.cache.delete(eventId);
      return null;
    }

    return cached;
  }

  /**
   * 清除过期缓存
   * @param {Number} maxAge 最大缓存时间（毫秒）
   */
  clearExpiredCache(maxAge = 5 * 60 * 1000) {
    const now = Date.now();
    for (const [eventId, state] of this.cache.entries()) {
      if (now - state.timestamp > maxAge) {
        this.cache.delete(eventId);
      }
    }
  }

  /**
   * 处理页面跳转逻辑
   * @param {String} currentRole 当前角色
   * @param {String} targetPage 目标页面
   * @param {String} eventId 活动ID
   * @param {Function} navigate 导航函数
   * @returns {Boolean} 是否需要特殊处理
   */
  handleNavigation(currentRole, targetPage, eventId, navigate) {
    // 检查访问权限
    const accessiblePages = this.getAccessiblePages(currentRole);
    if (!accessiblePages.includes(targetPage)) {
      return false; // 无权限访问
    }

    // 根据角色和目标页面处理特殊逻辑
    switch (currentRole) {
      case 'guest':
        if (targetPage === 'participate' || targetPage === 'observe') {
          // 游客需要先跳转到详情页进行报名
          wx.navigateTo({
            url: `/pages/event/detail?id=${eventId}`
          });
          return true;
        }
        break;

      case 'observer':
        if (targetPage === 'participate') {
          // 围观者需要先升级为参与者
          wx.showModal({
            title: '权限提示',
            content: '您需要升级为参与者才能访问此功能',
            confirmText: '立即升级',
            success: (res) => {
              if (res.confirm) {
                // 这里应该调用升级API
                console.log('升级为参与者');
              }
            }
          });
          return true;
        }
        break;
    }

    // 默认导航逻辑
    navigate();
    return true;
  }

  /**
   * 格式化活动状态信息
   * @param {Object} eventData 活动数据
   * @param {String} role 用户角色
   * @returns {Object} 格式化后的状态信息
   */
  formatEventStatus(eventData, role) {
    const statusConfig = {
      enrolling: {
        text: '报名中',
        color: '#1890ff',
        icon: '📋'
      },
      in_progress: {
        text: '进行中',
        color: '#52c41a',
        icon: '📖'
      },
      completed: {
        text: '已完成',
        color: '#722ed1',
        icon: '✅'
      }
    };

    const status = statusConfig[eventData.status] || statusConfig.enrolling;

    // 根据角色调整状态显示
    let actionText = '查看详情';
    let canAct = true;

    switch (role) {
      case 'guest':
        actionText = eventData.can_enroll ? '立即报名' : '报名已截止';
        canAct = eventData.can_enroll;
        break;
      case 'observer':
        actionText = '升级参与';
        canAct = eventData.can_enroll;
        break;
      case 'participant':
        actionText = '查看任务';
        canAct = eventData.status === 'in_progress';
        break;
      case 'organizer':
        actionText = '管理活动';
        canAct = true;
        break;
    }

    return {
      ...status,
      actionText,
      canAct,
      progress: this.calculateProgress(eventData)
    };
  }

  /**
   * 计算活动进度
   * @param {Object} eventData 活动数据
   * @returns {Object} 进度信息
   */
  calculateProgress(eventData) {
    if (!eventData.start_date || !eventData.end_date) {
      return { currentDay: 1, totalDays: eventData.days_count || 1, percentage: 0 };
    }

    const now = new Date();
    const startDate = new Date(eventData.start_date);
    const endDate = new Date(eventData.end_date);

    const totalDays = eventData.days_count || Math.ceil((endDate - startDate) / (1000 * 60 * 60 * 24)) + 1;
    const currentDay = Math.max(1, Math.min(
      Math.floor((now - startDate) / (1000 * 60 * 60 * 24)) + 1,
      totalDays
    ));

    const percentage = Math.min(100, Math.round((currentDay / totalDays) * 100));

    return { currentDay, totalDays, percentage };
  }
}

// 创建全局单例
const eventStateManager = new EventStateManager();

module.exports = eventStateManager;