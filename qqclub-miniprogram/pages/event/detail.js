// pages/event/detail.js
Page({
  data: {
    eventId: null,
    eventInfo: null,
    userInfo: null,
    userRole: 'guest', // guest, observer, participant, organizer
    loading: true,
    currentTab: 'info',

    // 数据统计
    checkinsCount: 0,
    discussionsCount: 0,

    // 打卡相关
    checkins: [],
    checkinFilter: 'all', // all, today, liked

    // 参与成员
    participants: [],

    // 活动讨论
    discussions: [],

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
      // 这里应该调用API获取活动详情
      // const response = await api.getEventDetail(this.data.eventId);

      // 模拟数据
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
        days_count: 30,
        participants_count: 15,
        max_participants: 20,
        enrollment_fee: 0,
        can_enroll: true,
        completed_today: 8
      };

      // 模拟用户角色判断
      const userRole = this.determineUserRole(mockEvent);

      this.setData({
        eventInfo: mockEvent,
        userRole,
        loading: false
      });

      // 加载其他数据
      this.loadTabData();

    } catch (error) {
      console.error('加载活动详情失败:', error);
      this.setData({ loading: false });
      wx.showToast({
        title: '加载失败',
        icon: 'none'
      });
    }
  },

  // 确定用户角色
  determineUserRole(event) {
    if (!this.data.userInfo) {
      return 'guest';
    }

    // 模拟判断逻辑
    const userId = this.data.userInfo.id;

    if (event.leader.id === userId) {
      return 'organizer';
    }

    // 模拟判断是否为参与者或围观者
    const isParticipant = Math.random() > 0.5;
    const isObserver = Math.random() > 0.7;

    if (isParticipant) {
      return 'participant';
    } else if (isObserver) {
      return 'observer';
    }

    return 'guest';
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
      case 'discussions':
        await this.loadDiscussions();
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

  // 加载活动讨论
  async loadDiscussions() {
    try {
      // const response = await api.getDiscussions(this.data.eventId);

      // 模拟数据
      const mockDiscussions = this.generateMockDiscussions();

      this.setData({
        discussions: mockDiscussions,
        discussionsCount: mockDiscussions.length
      });
    } catch (error) {
      console.error('加载活动讨论失败:', error);
    }
  },

  // 生成模拟讨论数据
  generateMockDiscussions() {
    const discussions = [];

    for (let i = 0; i < 5; i++) {
      discussions.push({
        id: i + 1,
        title: `关于第${i + 1}章节的深入讨论`,
        content_preview: `今天读了第${i + 1}章，有一些想法想和大家交流一下。特别是关于...`,
        author: {
          id: Math.floor(Math.random() * 10) + 1,
          nickname: `讨论者${Math.floor(Math.random() * 100) + 1}`,
          avatar_url: `https://picsum.photos/50/50?random=${i + 400}`
        },
        created_at: new Date(Date.now() - Math.random() * 7 * 24 * 60 * 60 * 1000).toISOString(),
        created_at_relative: this.getRelativeTime(new Date(Date.now() - Math.random() * 7 * 24 * 60 * 60 * 1000)),
        comments_count: Math.floor(Math.random() * 15) + 5,
        views_count: Math.floor(Math.random() * 50) + 20
      });
    }

    return discussions;
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

  // 查看讨论
  viewDiscussions() {
    this.setData({
      currentTab: 'discussions'
    });
    this.loadDiscussions();
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
        title: '活动已满员',
        icon: 'none'
      });
      return;
    }

    try {
      // await api.enrollAsParticipant(this.data.eventId);

      this.setData({
        userRole: 'participant'
      });

      this.loadEventDetail();

      wx.showToast({
        title: '参与成功',
        icon: 'success'
      });
    } catch (error) {
      console.error('参与活动失败:', error);
      wx.showToast({
        title: '参与失败',
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
      // await api.enrollAsObserver(this.data.eventId);

      this.setData({
        userRole: 'observer'
      });

      this.loadEventDetail();

      wx.showToast({
        title: '围观成功',
        icon: 'success'
      });
    } catch (error) {
      console.error('围观活动失败:', error);
      wx.showToast({
        title: '围观失败',
        icon: 'none'
      });
    }
  },

  // 管理活动
  manageEvent() {
    wx.navigateTo({
      url: `/pages/event/manage?eventId=${this.data.eventId}`
    });
  },

  // 查看统计数据
  viewStatistics() {
    wx.navigateTo({
      url: `/pages/event/stats?eventId=${this.data.eventId}`
    });
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

  // 发起讨论
  startDiscussion() {
    if (this.data.userRole === 'observer') {
      wx.showToast({
        title: '围观者不能发起讨论',
        icon: 'none'
      });
      return;
    }

    wx.navigateTo({
      url: `/pages/event/createDiscussion?eventId=${this.data.eventId}`
    });
  },

  // 查看讨论详情
  viewDiscussion(e) {
    const discussionId = e.currentTarget.dataset.id;
    wx.navigateTo({
      url: `/pages/event/discussionDetail?id=${discussionId}`
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
  }
});