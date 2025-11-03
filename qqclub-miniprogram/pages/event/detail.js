// pages/event/detail.js
const eventStateManager = require('../../utils/eventStateManager');

Page({
  data: {
    eventId: null,
    eventInfo: null,
    userInfo: null,
    userRole: 'guest', // guest, observer, participant, organizer
    myEnrollment: null, // 我的报名信息
    loading: true,
    currentTab: 'info',

    // 数据统计
    checkinsCount: 0,

    // 打卡相关
    checkins: [],
    checkinFilter: 'all', // all, today, liked, calendar

    // 筛选相关
    currentFilter: 'all',
    selectedDate: null,
    showCalendar: false,

    // 日历相关
    showCalendarPicker: false,
    selectedDate: '',
    selectedDateText: '',
    currentYear: new Date().getFullYear(),
    currentMonth: new Date().getMonth() + 1,
    calendarDays: [],
    calendarEmptyDays: 0,

    // 参与成员
    participants: [],


    // 评论相关
    showCommentModal: false,
    showEditCommentModal: false,
    currentCheckinId: null,
    currentCommentId: null,
    currentCommentIndex: null,
    commentContent: '',
    editCommentContent: '',
  },

  onLoad(options) {
    const eventId = options.id;
    if (!eventId) {
      wx.showToast({
        title: '参数错误',
        icon: 'none'
      });
      wx.navigateBack();
      return;
    }

    this.setData({ eventId });
    this.getUserInfo();
    this.loadEventDetail();
  },

  onShow() {
    // 刷新数据
    if (this.data.eventId) {
      this.loadEventDetail();
    }
  },

  onPullDownRefresh() {
    this.loadEventDetail().then(() => {
      wx.stopPullDownRefresh();
    });
  },

  // 获取用户信息
  getUserInfo() {
    const userInfo = wx.getStorageSync('userInfo');
    if (userInfo) {
      this.setData({ userInfo });
    }
  },

  // 加载活动详情
  async loadEventDetail() {
    this.setData({ loading: true });

    try {
      // 调用真实的API获取活动详情
      const app = getApp();
      const response = await app.request({
        url: `/api/v1/reading_events/${this.data.eventId}`,
        method: 'GET'
      });

      if (response.success) {
        const eventData = response.data;

        // 确定用户角色
        const userRole = this.determineUserRoleFromData(eventData);

        // 设置报名信息
        const myEnrollment = eventData.user_enrollment || null;

        this.setData({
          eventInfo: eventData,
          userRole,
          myEnrollment,
          loading: false
        });

        // 加载其他数据
        this.loadTabData();
      } else {
        throw new Error(response.message || '加载失败');
      }

    } catch (error) {
      console.error('加载活动详情失败:', error);

      // 如果API调用失败，使用模拟数据作为后备
      this.loadMockEventDetail();
    }
  },

  // 加载模拟活动详情（后备方案）
  loadMockEventDetail() {
    try {
      const mockEvent = {
        id: this.data.eventId,
        title: '《百年孤独》深度阅读共读活动',
        book_name: '百年孤独',
        description: '这是一场关于《百年孤独》的深度阅读活动。我们将用30天的时间，一起探索马尔克斯创造的魔幻现实主义世界，深入理解布恩迪亚家族的百年兴衰史。每天安排阅读任务，定期进行线上讨论，分享阅读心得和感悟。',
        rules: '1. 每天完成指定章节的阅读\n2. 提交每日阅读感悟和思考\n3. 积极参与小组讨论\n4. 尊重他人观点，文明交流\n5. 按时完成所有任务可获得完成证书',
        leader: {
          id: 1,
          nickname: '读书达人',
          avatar_url: 'https://picsum.photos/100/100?random=1',
          bio: '资深阅读推广人'
        },
        approval_status: 'approved',
        approval_status_text: '已通过',
        status: 'in_progress',
        status_text: '进行中',
        status_icon: '📖',
        date_range: '2024-01-15 至 2024-02-14',
        start_date: '2025-01-15',
        end_date: '2025-02-14',
        days_count: 30,
        participants_count: 15,
        max_participants: 20,
        enrollment_fee: 0,
        can_enroll: true,
        completed_today: 8,
        user_enrollment: null // 模拟无报名信息
      };

      // 模拟用户角色判断
      const userRole = this.determineUserRole(mockEvent);

      this.setData({
        eventInfo: mockEvent,
        userRole,
        myEnrollment: mockEvent.user_enrollment,
        loading: false
      });

      // 加载其他数据
      this.loadTabData();

    } catch (error) {
      console.error('加载模拟数据失败:', error);
      this.setData({ loading: false });
      wx.showToast({
        title: '加载失败',
        icon: 'none'
      });
    }
  },

  
  // 加载标签页数据
  async loadTabData() {
    switch (this.data.currentTab) {
      case 'checkins':
        await this.loadCheckins();
        break;
      case 'participants':
        await this.loadParticipants();
        break;
    }
  },

  // 切换标签页
  switchTab(e) {
    const tab = e.currentTarget.dataset.tab;
    if (tab !== this.data.currentTab) {
      this.setData({
        currentTab: tab
      });
      this.loadTabData();
    }
  },

  // 加载打卡数据
  async loadCheckins() {
    try {
      // const response = await api.getCheckins(this.data.eventId, this.data.checkinFilter);

      // 模拟数据
      const mockCheckins = this.generateMockCheckins();

      this.setData({
        checkins: mockCheckins,
        checkinsCount: mockCheckins.length
      });
    } catch (error) {
      console.error('加载打卡数据失败:', error);
    }
  },

  // 生成模拟打卡数据
  generateMockCheckins() {
    const checkins = [];
    const baseTime = new Date();

    for (let i = 0; i < 15; i++) {
      const dayNumber = Math.floor(Math.random() * 15) + 1;
      const checkinTime = new Date(baseTime.getTime() - (dayNumber - 1) * 24 * 60 * 60 * 1000);

      checkins.push({
        id: i + 1,
        day_number: dayNumber,
        content: `第${dayNumber}天的阅读感悟：今天读到了关于马孔多的预言部分，感觉很有意思。马尔克斯通过预言的方式，展现了时间的循环和命运的必然性。布恩迪亚家族似乎无法逃脱这个魔咒，每一个重要事件都有对应的预言，这种宿命感让人感到既神奇又无奈。`,
        images: Math.random() > 0.6 ? [`https://picsum.photos/300/200?random=${i + 100}`] : [],
        author: {
          id: Math.floor(Math.random() * 10) + 1,
          nickname: `读书人${Math.floor(Math.random() * 100) + 1}`,
          avatar_url: `https://picsum.photos/50/50?random=${i + 200}`
        },
        created_at: checkinTime.toISOString(),
        created_at_relative: this.getRelativeTime(checkinTime),
        likes_count: Math.floor(Math.random() * 20) + 5,
        comments_count: Math.floor(Math.random() * 10) + 2,
        is_liked: Math.random() > 0.7,
        comments: this.generateMockComments()
      });
    }

    return checkins.sort((a, b) => new Date(b.created_at) - new Date(a.created_at));
  },

  // 生成模拟评论
  generateMockComments() {
    const comments = [];
    const commentCount = Math.floor(Math.random() * 5);

    for (let i = 0; i < commentCount; i++) {
      comments.push({
        id: i + 1,
        content: `很有深度的感悟！我也觉得这个部分很精彩。`,
        author: {
          id: Math.floor(Math.random() * 10) + 1,
          nickname: `评论者${Math.floor(Math.random() * 100) + 1}`,
          avatar_url: `https://picsum.photos/40/40?random=${i + 300}`
        },
        created_at_relative: this.getRelativeTime(new Date(Date.now() - Math.random() * 2 * 60 * 60 * 1000))
      });
    }

    return comments;
  },

  // 加载参与成员
  async loadParticipants() {
    try {
      // const response = await api.getParticipants(this.data.eventId);

      // 模拟数据
      const mockParticipants = [
        {
          id: 1,
          nickname: '读书达人',
          avatar_url: 'https://picsum.photos/100/100?random=1',
          role_text: '组织者',
          checkins_count: 25,
          activity_score: 95,
          is_organizer: true
        },
        {
          id: 2,
          nickname: '书虫小明',
          avatar_url: 'https://picsum.photos/100/100?random=2',
          role_text: '参与者',
          checkins_count: 18,
          activity_score: 85,
          is_organizer: false
        }
      ];

      // 生成更多参与者
      for (let i = 3; i <= this.data.eventInfo.participants_count; i++) {
        mockParticipants.push({
          id: i,
          nickname: `阅读爱好者${i}`,
          avatar_url: `https://picsum.photos/100/100?random=${i + 10}`,
          role_text: '参与者',
          checkins_count: Math.floor(Math.random() * 20) + 5,
          activity_score: Math.floor(Math.random() * 40) + 60,
          is_organizer: false
        });
      }

      this.setData({
        participants: mockParticipants
      });
    } catch (error) {
      console.error('加载参与成员失败:', error);
    }
  },

  
  // 过滤打卡
  filterCheckins(e) {
    const filter = e.currentTarget.dataset.filter;
    this.setData({
      checkinFilter: filter
    });
    this.loadCheckins();
  },

  // 提交打卡
  submitCheckIn() {
    if (this.data.userRole !== 'participant') {
      wx.showToast({
        title: '只有参与者才能提交打卡',
        icon: 'none'
      });
      return;
    }

    wx.navigateTo({
      url: `/pages/event/checkin?eventId=${this.data.eventId}`
    });
  },

  // 查看进度
  viewProgress() {
    wx.navigateTo({
      url: `/pages/event/progress?eventId=${this.data.eventId}`
    });
  },

  // 转为参与者
  async switchToParticipant() {
    if (!this.data.eventInfo.can_enroll) {
      wx.showToast({
        title: '活动已满员',
        icon: 'none'
      });
      return;
    }

    wx.showModal({
      title: '确认参与',
      content: '确定要转为正式参与者吗？转后需要提交打卡作业。',
      success: async (res) => {
        if (res.confirm) {
          try {
            // await api.switchToParticipant(this.data.eventId);

            this.setData({
              userRole: 'participant'
            });

            // 更新活动信息
            this.loadEventDetail();

            wx.showToast({
              title: '参与成功',
              icon: 'success'
            });
          } catch (error) {
            console.error('转为参与者失败:', error);
            wx.showToast({
              title: '操作失败',
              icon: 'none'
            });
          }
        }
      }
    });
  },

  
  // 作为参与者报名
  async enrollAsParticipant() {
    if (!this.data.userInfo) {
      wx.showModal({
        title: '提示',
        content: '请先登录后再参与活动',
        confirmText: '去登录',
        success: (res) => {
          if (res.confirm) {
            wx.navigateTo({
              url: '/pages/auth/auth'
            });
          }
        }
      });
      return;
    }

    if (!this.data.eventInfo.can_enroll) {
      wx.showToast({
        title: '活动已满员或已截止',
        icon: 'none'
      });
      return;
    }

    try {
      wx.showLoading({
        title: '报名中...',
        mask: true
      });

      const app = getApp();
      const response = await app.request({
        url: '/api/v1/event_enrollments',
        method: 'POST',
        data: {
          event_enrollment: {
            reading_event_id: this.data.eventId,
            enrollment_type: 'participant'
          }
        }
      });

      wx.hideLoading();

      if (response.success) {
        // 更新用户角色
        this.updateUserRole(response.data);

        // 重新加载活动详情
        this.loadEventDetail();

        wx.showToast({
          title: '参与成功',
          icon: 'success'
        });

        // 询问是否立即进入共读主页
        setTimeout(() => {
          wx.showModal({
            title: '报名成功',
            content: '是否立即进入共读主页查看今日任务？',
            confirmText: '进入',
            cancelText: '稍后',
            success: (res) => {
              if (res.confirm) {
                this.goToParticipatePage();
              }
            }
          });
        }, 1500);
      } else {
        throw new Error(response.message || '报名失败');
      }

    } catch (error) {
      wx.hideLoading();
      console.error('参与活动失败:', error);

      let errorMsg = '参与失败';
      if (error.message) {
        if (error.message.includes('满员')) {
          errorMsg = '活动人数已满';
        } else if (error.message.includes('截止')) {
          errorMsg = '报名已截止';
        } else {
          errorMsg = error.message;
        }
      }

      wx.showToast({
        title: errorMsg,
        icon: 'none'
      });
    }
  },

  // 作为围观者报名
  async enrollAsObserver() {
    if (!this.data.userInfo) {
      wx.showModal({
        title: '提示',
        content: '请先登录后再围观活动',
        confirmText: '去登录',
        success: (res) => {
          if (res.confirm) {
            wx.navigateTo({
              url: '/pages/auth/auth'
            });
          }
        }
      });
      return;
    }

    try {
      wx.showLoading({
        title: '围观中...',
        mask: true
      });

      const app = getApp();
      const response = await app.request({
        url: '/api/v1/event_enrollments',
        method: 'POST',
        data: {
          event_enrollment: {
            reading_event_id: this.data.eventId,
            enrollment_type: 'observer'
          }
        }
      });

      wx.hideLoading();

      if (response.success) {
        // 更新用户角色
        this.updateUserRole(response.data);

        // 重新加载活动详情
        this.loadEventDetail();

        wx.showToast({
          title: '围观成功',
          icon: 'success'
        });

        // 询问是否立即进入围观主页
        setTimeout(() => {
          wx.showModal({
            title: '围观成功',
            content: '是否立即进入围观主页查看精选内容？',
            confirmText: '进入',
            cancelText: '稍后',
            success: (res) => {
              if (res.confirm) {
                this.goToObservePage();
              }
            }
          });
        }, 1500);
      } else {
        throw new Error(response.message || '围观失败');
      }

    } catch (error) {
      wx.hideLoading();
      console.error('围观活动失败:', error);

      let errorMsg = '围观失败';
      if (error.message) {
        errorMsg = error.message;
      }

      wx.showToast({
        title: errorMsg,
        icon: 'none'
      });
    }
  },

  
  // 点赞打卡
  async likeCheckin(e) {
    const checkinId = e.currentTarget.dataset.id;

    try {
      // await api.likeCheckin(checkinId);

      // 更新本地状态
      const checkins = this.data.checkins.map(checkin => {
        if (checkin.id === checkinId) {
          return {
            ...checkin,
            is_liked: !checkin.is_liked,
            likes_count: checkin.is_liked ? checkin.likes_count - 1 : checkin.likes_count + 1
          };
        }
        return checkin;
      });

      this.setData({ checkins });
    } catch (error) {
      console.error('点赞失败:', error);
      wx.showToast({
        title: '操作失败',
        icon: 'none'
      });
    }
  },

  // 评论打卡
  commentCheckin(e) {
    const checkinId = e.currentTarget.dataset.id;

    // 显示评论输入框
    this.showCommentInput(checkinId);
  },

  // 显示评论输入框
  showCommentInput(checkinId) {
    this.setData({
      showCommentModal: true,
      currentCheckinId: checkinId,
      commentContent: ''
    });
  },

  // 隐藏评论输入框
  hideCommentInput() {
    this.setData({
      showCommentModal: false,
      currentCheckinId: null,
      commentContent: ''
    });
  },

  // 评论内容输入
  onCommentInput(e) {
    this.setData({
      commentContent: e.detail.value
    });
  },

  // 提交评论
  async submitComment() {
    if (!this.data.commentContent.trim()) {
      wx.showToast({
        title: '请输入评论内容',
        icon: 'none'
      });
      return;
    }

    const userInfo = wx.getStorageSync('userInfo');
    if (!userInfo) {
      wx.showModal({
        title: '提示',
        content: '请先登录后再评论',
        confirmText: '去登录',
        success: (res) => {
          if (res.confirm) {
            wx.navigateTo({
              url: '/pages/auth/auth'
            });
          }
        }
      });
      return;
    }

    try {
      wx.showLoading({
        title: '发布中...',
        mask: true
      });

      const response = await api.checkIn.addComment(this.data.currentCheckinId, {
        comment: {
          content: this.data.commentContent.trim()
        }
      });

      wx.hideLoading();
      wx.showToast({
        title: '评论成功',
        icon: 'success'
      });

      // 隐藏评论框
      this.hideCommentInput();

      // 刷新打卡列表以显示新评论
      this.loadCheckins();

    } catch (error) {
      wx.hideLoading();
      console.error('评论失败:', error);

      // 检查是否是认证错误
      if (error.message && error.message.includes('未授权')) {
        wx.showModal({
          title: '登录已过期',
          content: '请重新登录后继续',
          confirmText: '去登录',
          success: (res) => {
            if (res.confirm) {
              wx.navigateTo({
                url: '/pages/auth/auth'
              });
            }
          }
        });
        return;
      }

      wx.showToast({
        title: '评论失败',
        icon: 'none'
      });
    }
  },

  // 删除评论
  async deleteComment(e) {
    const { checkinId, commentId, commentIndex } = e.currentTarget.dataset;

    wx.showModal({
      title: '确认删除',
      content: '确定要删除这条评论吗？',
      success: async (res) => {
        if (res.confirm) {
          try {
            wx.showLoading({
              title: '删除中...',
              mask: true
            });

            await api.comment.delete(commentId);

            wx.hideLoading();
            wx.showToast({
              title: '删除成功',
              icon: 'success'
            });

            // 从本地数据中移除评论
            this.removeCommentFromList(checkinId, commentIndex);

          } catch (error) {
            wx.hideLoading();
            console.error('删除评论失败:', error);
            wx.showToast({
              title: '删除失败',
              icon: 'none'
            });
          }
        }
      }
    });
  },

  // 从本地数据中移除评论
  removeCommentFromList(checkinId, commentIndex) {
    const checkins = this.data.checkins.map(checkin => {
      if (checkin.id === checkinId) {
        const newComments = [...checkin.comments];
        newComments.splice(commentIndex, 1);

        return {
          ...checkin,
          comments: newComments,
          comments_count: Math.max(0, checkin.comments_count - 1)
        };
      }
      return checkin;
    });

    this.setData({ checkins });
  },

  // 编辑评论
  editComment(e) {
    const { checkinId, commentId, commentIndex, content } = e.currentTarget.dataset;

    // 显示编辑输入框
    this.setData({
      showEditCommentModal: true,
      currentCheckinId: checkinId,
      currentCommentId: commentId,
      currentCommentIndex: commentIndex,
      editCommentContent: content
    });
  },

  // 隐藏编辑评论输入框
  hideEditCommentInput() {
    this.setData({
      showEditCommentModal: false,
      currentCheckinId: null,
      currentCommentId: null,
      currentCommentIndex: null,
      editCommentContent: ''
    });
  },

  // 编辑评论内容输入
  onEditCommentInput(e) {
    this.setData({
      editCommentContent: e.detail.value
    });
  },

  // 提交编辑评论
  async submitEditComment() {
    if (!this.data.editCommentContent.trim()) {
      wx.showToast({
        title: '请输入评论内容',
        icon: 'none'
      });
      return;
    }

    try {
      wx.showLoading({
        title: '更新中...',
        mask: true
      });

      const response = await api.comment.update(this.data.currentCommentId, {
        comment: {
          content: this.data.editCommentContent.trim()
        }
      });

      wx.hideLoading();
      wx.showToast({
        title: '更新成功',
        icon: 'success'
      });

      // 隐藏编辑框
      this.hideEditCommentInput();

      // 更新本地数据中的评论
      this.updateCommentInList(this.data.currentCheckinId, this.data.currentCommentIndex, {
        content: this.data.editCommentContent.trim()
      });

    } catch (error) {
      wx.hideLoading();
      console.error('更新评论失败:', error);
      wx.showToast({
        title: '更新失败',
        icon: 'none'
      });
    }
  },

  // 更新本地数据中的评论
  updateCommentInList(checkinId, commentIndex, updatedData) {
    const checkins = this.data.checkins.map(checkin => {
      if (checkin.id === checkinId) {
        const newComments = [...checkin.comments];
        newComments[commentIndex] = {
          ...newComments[commentIndex],
          ...updatedData
        };

        return {
          ...checkin,
          comments: newComments
        };
      }
      return checkin;
    });

    this.setData({ checkins });
  },

  // 分享打卡
  shareCheckin(e) {
    const checkinId = e.currentTarget.dataset.id;

    wx.showShareMenu({
      withShareTicket: true
    });
  },

  // 送小红花给打卡
  async giveFlowerToCheckin(e) {
    const { id: checkinId, userId } = e.currentTarget.dataset;

    try {
      wx.showLoading({
        title: '送花中...',
        mask: true
      });

      const app = getApp();
      const response = await app.request({
        url: '/api/v1/flowers/give',
        method: 'POST',
        data: {
          flower: {
            receiver_id: userId,
            checkin_id: checkinId,
            flower_type: 'like'
          }
        }
      });

      wx.hideLoading();

      if (response?.success) {
        wx.showToast({
          title: '送花成功',
          icon: 'success'
        });

        // 重新加载数据
        this.loadCheckins();
      }
    } catch (error) {
      wx.hideLoading();
      console.error('送花失败:', error);
      wx.showToast({
        title: '送花失败',
        icon: 'none'
      });
    }
  },

  // 查看打卡详情
  viewCheckinDetail(e) {
    const checkinId = e.currentTarget.dataset.id;
    wx.navigateTo({
      url: `/pages/event/checkinDetail?id=${checkinId}`
    });
  },

  // 预览图片
  previewImage(e) {
    const { urls, current } = e.currentTarget.dataset;
    wx.previewImage({
      current,
      urls
    });
  },

  // 联系组织者
  contactOrganizer() {
    wx.showToast({
      title: '联系功能开发中',
      icon: 'none'
    });
  },

  
  // 返回列表
  goBack() {
    wx.navigateBack();
  },

  // 获取相对时间
  getRelativeTime(date) {
    const now = new Date();
    const diff = now - date;
    const minutes = Math.floor(diff / 60000);
    const hours = Math.floor(diff / 3600000);
    const days = Math.floor(diff / 86400000);

    if (minutes < 1) return '刚刚';
    if (minutes < 60) return `${minutes}分钟前`;
    if (hours < 24) return `${hours}小时前`;
    if (days < 7) return `${days}天前`;

    return date.toLocaleDateString();
  },

  // 阻止事件冒泡
  stopPropagation() {
    // 阻止点击评论内容时关闭弹窗
  },

  // === 新增的页面导航和方法 ===

  // 获取角色图标
  getRoleIcon(role) {
    const roleIcons = {
      'participant': '🎯',
      'observer': '👀',
      'organizer': '👑',
      'guest': '👤'
    };
    return roleIcons[role] || '👤';
  },

  // 获取角色文本
  getRoleText(role) {
    const roleTexts = {
      'participant': '参与者',
      'observer': '围观者',
      'organizer': '组织者',
      'guest': '游客'
    };
    return roleTexts[role] || '游客';
  },

  // 跳转到参与者主页
  goToParticipatePage() {
    console.log('=== 调试：进入参与者主页 ===');
    console.log('当前角色:', this.data.userRole);
    console.log('活动ID:', this.data.eventId);
    console.log('完整URL:', `/pages/event/participate?id=${this.data.eventId}`);

    // 显示加载提示
    wx.showLoading({
      title: '加载中...',
      mask: true
    });

    // 直接跳转到参与者页面，无论当前是什么角色
    wx.navigateTo({
      url: `/pages/event/participate?id=${this.data.eventId}`,
      success: (res) => {
        console.log('导航成功:', res);
        wx.hideLoading();
      },
      fail: (err) => {
        console.error('导航失败:', err);
        wx.hideLoading();
        wx.showToast({
          title: '页面跳转失败',
          icon: 'none'
        });
      }
    });
  },

  // 跳转到围观主页
  goToObservePage() {
    console.log('=== 调试：进入围观主页 ===');
    console.log('当前角色:', this.data.userRole);
    console.log('活动ID:', this.data.eventId);
    console.log('完整URL:', `/pages/event/observe?id=${this.data.eventId}`);

    // 显示加载提示
    wx.showLoading({
      title: '加载中...',
      mask: true
    });

    // 直接跳转到围观者页面，无论当前是什么角色
    wx.navigateTo({
      url: `/pages/event/observe?id=${this.data.eventId}`,
      success: (res) => {
        console.log('导航成功:', res);
        wx.hideLoading();
      },
      fail: (err) => {
        console.error('导航失败:', err);
        wx.hideLoading();
        wx.showToast({
          title: '页面跳转失败',
          icon: 'none'
        });
      }
    });
  },

  // 快速打卡
  quickCheckIn() {
    wx.navigateTo({
      url: `/pages/event/checkin?eventId=${this.data.eventId}&mode=quick`
    });
  },

  // 查看排行榜
  viewRanking() {
    wx.navigateTo({
      url: `/pages/event/ranking?eventId=${this.data.eventId}`
    });
  },

  // 送小红花
  giveFlowers() {
    wx.navigateTo({
      url: `/pages/event/flowers?eventId=${this.data.eventId}`
    });
  },

  // 查看精选内容
  viewFeaturedContent() {
    wx.navigateTo({
      url: `/pages/event/featured?id=${this.data.eventId}`
    });
  },

  // 分享活动
  shareEvent() {
    wx.showShareMenu({
      withShareTicket: true,
      success: () => {
        wx.showToast({
          title: '分享成功',
          icon: 'success'
        });
      }
    });
  },

  // 跳转到活动信息页面
  goToActivityInfo() {
    wx.navigateTo({
      url: `/pages/event/activity-info?id=${this.data.eventId}`
    });
  },

  // 跳转到统计数据页面
  goToStatistics() {
    wx.navigateTo({
      url: `/pages/event/statistics?id=${this.data.eventId}`
    });
  },

  // 跳转到登录页面
  goToAuth() {
    wx.navigateTo({
      url: '/pages/auth/auth'
    });
  },

  // 开始打卡
  startCheckIn() {
    console.log('=== startCheckIn 调试信息 ===');
    console.log('当前用户角色:', this.data.userRole);
    console.log('用户信息:', this.data.userInfo);
    console.log('活动信息:', this.data.eventInfo);
    console.log('我的报名信息:', this.data.myEnrollment);

    // 详细检查报名状态
    const enrollment = this.data.myEnrollment;
    if (enrollment) {
      console.log('报名详情:');
      console.log('- 报名类型:', enrollment.enrollment_type);
      console.log('- 状态:', enrollment.status);
      console.log('- 报名ID:', enrollment.id);
    }

    if (this.data.userRole !== 'participant') {
      console.log('用户角色不是参与者，显示提示弹窗');
      wx.showModal({
        title: '提示',
        content: '您尚未加入共读活动，加入后才能开始打卡哦！',
        confirmText: '立即加入',
        cancelText: '取消',
        success: (res) => {
          if (res.confirm) {
            this.enrollAsParticipant();
          }
        }
      });
      return;
    }

    console.log('用户角色是参与者，直接跳转到打卡页面');
    wx.navigateTo({
      url: `/pages/event/checkin?eventId=${this.data.eventId}`
    });
  },

  
  // 更新用户角色状态
  updateUserRole(enrollment) {
    let userRole = 'guest';
    if (enrollment) {
      userRole = enrollment.enrollment_type === 'participant' ? 'participant' : 'observer';
    }

    this.setData({
      userRole,
      myEnrollment: enrollment
    });
  },

  // 重新确定用户角色（基于真实数据，使用状态管理器）
  determineUserRoleFromData(eventData) {
    console.log('=== determineUserRoleFromData 调试 ===');
    console.log('eventData:', eventData);
    console.log('userInfo:', this.data.userInfo);
    console.log('user_enrollment:', eventData.user_enrollment);

    const userRole = eventStateManager.getUserRole(eventData, this.data.userInfo);
    console.log('计算出的用户角色:', userRole);

    return userRole;
  },

  // === 日历相关功能 ===

  // 显示日历选择器
  showCalendarPicker() {
    this.generateCalendarDays();
    this.setData({
      showCalendarPicker: true
    });
  },

  // 隐藏日历选择器
  hideCalendarPicker() {
    this.setData({
      showCalendarPicker: false
    });
  },

  // 日期改变事件
  onDateChange(e) {
    const selectedDate = e.detail.value;
    this.setData({
      selectedDate
    });
  },

  // 确认日期选择
  confirmDateSelection() {
    if (!this.data.selectedDate) {
      wx.showToast({
        title: '请选择日期',
        icon: 'none'
      });
      return;
    }

    // 格式化日期显示
    const dateObj = new Date(this.data.selectedDate);
    const selectedDateText = this.formatDateText(dateObj);

    this.setData({
      checkinFilter: 'calendar',
      selectedDateText,
      showCalendarPicker: false
    });

    // 加载指定日期的打卡数据
    this.loadCheckinsByDate(this.data.selectedDate);
  },

  // 清除日期筛选
  clearDateFilter() {
    this.setData({
      checkinFilter: 'all',
      selectedDate: '',
      selectedDateText: ''
    });
    this.loadCheckins();
  },

  // 根据日期加载打卡数据
  async loadCheckinsByDate(date) {
    try {
      wx.showLoading({
        title: '加载中...',
        mask: true
      });

      // 调用API获取指定日期的打卡数据
      // const response = await api.getCheckinsByDate(this.data.eventId, date);

      // 模拟根据日期筛选数据
      const allCheckins = this.generateMockCheckins();
      const filteredCheckins = allCheckins.filter(checkin => {
        const checkinDate = new Date(checkin.created_at).toISOString().split('T')[0];
        return checkinDate === date;
      });

      this.setData({
        checkins: filteredCheckins,
        checkinsCount: filteredCheckins.length
      });

      wx.hideLoading();

      if (filteredCheckins.length === 0) {
        wx.showToast({
          title: '该日期暂无打卡',
          icon: 'none'
        });
      }

    } catch (error) {
      wx.hideLoading();
      console.error('加载指定日期打卡失败:', error);
      wx.showToast({
        title: '加载失败',
        icon: 'none'
      });
    }
  },

  // 格式化日期文本
  formatDateText(date) {
    const year = date.getFullYear();
    const month = date.getMonth() + 1;
    const day = date.getDate();
    const weekDay = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'][date.getDay()];

    return `${year}年${month}月${day}日 ${weekDay}`;
  },

  // 生成日历数据
  generateCalendarDays() {
    const { currentYear, currentMonth, eventInfo } = this.data;
    const firstDay = new Date(currentYear, currentMonth - 1, 1);
    const lastDay = new Date(currentYear, currentMonth, 0);
    const startDate = new Date(currentYear, currentMonth - 1, 1 - firstDay.getDay());
    const endDate = new Date(currentYear, currentMonth, 6 - lastDay.getDay());

    const days = [];
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const eventStartDate = eventInfo ? new Date(eventInfo.start_date) : null;
    const eventEndDate = eventInfo ? new Date(eventInfo.end_date) : null;

    for (let d = new Date(startDate); d <= endDate; d.setDate(d.getDate() + 1)) {
      const date = new Date(d);
      const dateStr = date.toISOString().split('T')[0];

      let dayType = 'other-month';
      if (date.getMonth() === currentMonth - 1) {
        dayType = 'current-month';
      }

      let isToday = false;
      if (date.getTime() === today.getTime()) {
        isToday = true;
      }

      let isInRange = true;
      if (eventStartDate && eventEndDate) {
        isInRange = date >= eventStartDate && date <= eventEndDate;
      }

      let hasCheckins = false;
      // 简单模拟是否有打卡数据
      if (isInRange && Math.random() > 0.7) {
        hasCheckins = true;
      }

      days.push({
        date: date.getDate(),
        fullDate: dateStr,
        dayType,
        isToday,
        isInRange,
        hasCheckins,
        isSelected: this.data.selectedDate === dateStr
      });
    }

    this.setData({
      calendarDays: days
    });
  },

  // 选择日期
  selectDate(e) {
    const { date, isInRange } = e.currentTarget.dataset;

    if (!isInRange) {
      wx.showToast({
        title: '该日期不在活动范围内',
        icon: 'none'
      });
      return;
    }

    this.setData({
      selectedDate: date
    });
  },

  // 切换到上个月
  previousMonth() {
    let { currentYear, currentMonth } = this.data;
    currentMonth--;
    if (currentMonth < 1) {
      currentMonth = 12;
      currentYear--;
    }

    this.setData({
      currentYear,
      currentMonth
    });
    this.generateCalendarDays();
  },

  // 切换到下个月
  nextMonth() {
    let { currentYear, currentMonth } = this.data;
    currentMonth++;
    if (currentMonth > 12) {
      currentMonth = 1;
      currentYear++;
    }

    this.setData({
      currentYear,
      currentMonth
    });
    this.generateCalendarDays();
  },

  // 跳转到今天
  goToToday() {
    const today = new Date();
    this.setData({
      currentYear: today.getFullYear(),
      currentMonth: today.getMonth() + 1
    });
    this.generateCalendar();
  },

  // 获取活动状态文本
  getEventStatusText(status) {
    const statusMap = {
      'enrolling': '报名中',
      'in_progress': '进行中',
      'completed': '已结束'
    };
    return statusMap[status] || '未知';
  },

  // 获取剩余天数描述
  getDaysLeft(event) {
    if (!event) return '';

    const now = new Date();
    const endDate = new Date(event.end_date);
    const startDate = new Date(event.start_date);

    if (now < startDate) {
      // 活动还未开始
      const daysUntilStart = Math.ceil((startDate - now) / (1000 * 60 * 60 * 24));
      return `${daysUntilStart}天后开始`;
    } else if (now <= endDate) {
      // 活动进行中
      const daysLeft = Math.ceil((endDate - now) / (1000 * 60 * 60 * 24));
      return `剩余${daysLeft}天`;
    } else {
      // 活动已结束
      return '已结束';
    }
  },

  // 书籍封面图片加载错误处理
  handleBookCoverError(e) {
    console.log('书籍封面加载失败，使用默认图片');
    // 可以在这里设置一个默认的书籍封面图片
    // 由于小程序的限制，这里只能记录错误，实际的图片替换需要通过其他方式实现
  },

  // === 新增的筛选和日历功能 ===

  // 切换筛选条件
  changeFilter(e) {
    const filter = e.currentTarget.dataset.filter;
    if (filter === 'calendar') {
      this.toggleCalendar();
      return;
    }

    this.setData({
      currentFilter: filter,
      showCalendar: false
    });

    // 根据筛选条件加载打卡数据
    this.loadFilteredCheckins(filter);
  },

  // 切换日历显示
  toggleCalendar() {
    const showCalendar = !this.data.showCalendar;
    this.setData({
      showCalendar,
      // 当显示日历时，清空打卡列表，隐藏作业列表
      checkins: showCalendar ? [] : this.generateMockCheckins(),
      checkinsCount: showCalendar ? 0 : this.generateMockCheckins().length
    });

    if (showCalendar) {
      this.generateCalendar();
    }
  },

  // 生成日历数据
  generateCalendar() {
    const { currentYear, currentMonth } = this.data;
    const firstDay = new Date(currentYear, currentMonth - 1, 1);
    const lastDay = new Date(currentYear, currentMonth, 0);

    const days = [];
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    // 生成所有可能的打卡数据用于判断
    const allCheckins = this.generateMockCheckins();

    // 创建日期到打卡数的映射
    const dateCheckinMap = {};
    allCheckins.forEach(checkin => {
      const checkinDate = new Date(checkin.created_at).toISOString().split('T')[0];
      dateCheckinMap[checkinDate] = (dateCheckinMap[checkinDate] || 0) + 1;
    });

    // 生成月份天数
    for (let day = 1; day <= lastDay.getDate(); day++) {
      const date = new Date(currentYear, currentMonth - 1, day);
      const dateStr = this.formatDate(date);
      const isToday = date.getTime() === today.getTime();

      // 检查该日期是否有真实打卡数据
      const hasCheckins = dateCheckinMap[dateStr] > 0;
      const isSelected = this.data.selectedDate === dateStr;

      days.push({
        day,
        date: dateStr,
        isToday,
        hasCheckins,
        isSelected,
        checkinCount: dateCheckinMap[dateStr] || 0
      });
    }

    this.setData({ calendarDays: days });
  },

  // 切换月份
  changeMonth(e) {
    const direction = parseInt(e.currentTarget.dataset.direction);
    let { currentYear, currentMonth } = this.data;

    currentMonth += direction;
    if (currentMonth < 1) {
      currentMonth = 12;
      currentYear--;
    } else if (currentMonth > 12) {
      currentMonth = 1;
      currentYear++;
    }

    this.setData({ currentYear, currentMonth });
    this.generateCalendar();
  },

  // 切换年份
  changeYear(e) {
    const direction = parseInt(e.currentTarget.dataset.direction);
    let { currentYear } = this.data;

    currentYear += direction;

    this.setData({ currentYear });
    this.generateCalendar();
  },

  // 选择日期
  selectDate(e) {
    const date = e.currentTarget.dataset.date;
    this.setData({
      selectedDate: date,
      currentFilter: 'calendar',
      showCalendar: false
    });

    // 加载指定日期的打卡
    this.loadFilteredCheckins('calendar', date);
  },

  // 根据筛选条件加载打卡数据
  loadFilteredCheckins(filter, date = null) {
    let filteredCheckins = this.generateMockCheckins();

    switch (filter) {
      case 'today':
        const today = new Date().toISOString().split('T')[0];
        filteredCheckins = filteredCheckins.filter(checkin => {
          const checkinDate = new Date(checkin.created_at).toISOString().split('T')[0];
          return checkinDate === today;
        });
        break;

      case 'calendar':
        if (date) {
          filteredCheckins = filteredCheckins.filter(checkin => {
            const checkinDate = new Date(checkin.created_at).toISOString().split('T')[0];
            return checkinDate === date;
          });
        }
        break;

      default:
        // 'all' - 显示所有打卡
        break;
    }

    this.setData({
      checkins: filteredCheckins,
      checkinsCount: filteredCheckins.length
    });
  },

  // 格式化日期
  formatDate(date) {
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
  }
});