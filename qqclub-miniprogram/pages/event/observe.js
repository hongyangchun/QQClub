// pages/event/observe.js
Page({
  data: {
    eventId: null,
    eventInfo: null,
    myEnrollment: null,
    userInfo: null,
    loading: true,

    // 统计数据
    activityProgress: 0,
    currentDay: 1,
    todayCheckinsCount: 0,
    totalCheckinsCount: 0,
    totalFlowersCount: 0,

    // 打卡作业相关
    checkins: [],
    checkinFilter: 'all', // all, today, featured

    // UI状态
    showEventInfo: false,
    showCommentModal: false,
    currentCheckinId: null,
    commentContent: ''
  },

  onLoad(options) {
    console.log('=== 围观页面加载 ===');
    console.log('接收到的参数:', options);

    const eventId = options.id;
    if (!eventId) {
      wx.showToast({
        title: '参数错误',
        icon: 'none'
      });
      wx.navigateBack();
      return;
    }

    console.log('围观页面 - 活动ID:', eventId);
    this.setData({ eventId });
    this.getUserInfo();
    this.loadObserveData();
  },

  onShow() {
    // 刷新数据
    if (this.data.eventId) {
      this.loadObserveData();
    }
  },

  onPullDownRefresh() {
    this.loadObserveData().then(() => {
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

  // 加载围观页面数据
  async loadObserveData() {
    this.setData({ loading: true });

    try {
      const app = getApp();

      // 获取活动详情
      const eventResponse = await app.request({
        url: `/api/v1/reading_events/${this.data.eventId}`,
        method: 'GET'
      });

      if (eventResponse.success) {
        const eventData = eventResponse.data;
        const myEnrollment = eventData.user_enrollment;

        // 验证用户是否为围观者或未参与
        if (myEnrollment && myEnrollment.enrollment_type !== 'observer') {
          wx.showModal({
            title: '状态提示',
            content: '您已经是此活动的参与者了',
            confirmText: '去参与主页',
            cancelText: '继续围观',
            success: (res) => {
              if (res.confirm) {
                wx.redirectTo({
                  url: `/pages/event/participate?id=${this.data.eventId}`
                });
              }
            }
          });
          return;
        }

        // 计算活动进度
        const currentDay = this.calculateCurrentDay(eventData);
        const progressPercent = Math.min(100, Math.round((currentDay / eventData.days_count) * 100));

        this.setData({
          eventInfo: eventData,
          myEnrollment,
          currentDay,
          activityProgress: progressPercent
        });

        // 加载其他数据
        await this.loadAdditionalData();

        this.setData({ loading: false });

      } else {
        throw new Error(eventResponse.message || '加载活动详情失败');
      }

    } catch (error) {
      console.error('加载围观数据失败:', error);

      // 如果API调用失败，使用模拟数据
      this.loadMockData();
    }
  },

  // 加载额外数据
  async loadAdditionalData() {
    try {
      const app = getApp();

      // 并行加载打卡数据和统计数据
      const [
        checkinsResponse,
        statsResponse
      ] = await Promise.all([
        // 获取打卡作业列表
        this.loadCheckinsData(),
        // 获取统计数据
        app.request({
          url: `/api/v1/reading_events/${this.data.eventId}/observe_stats`,
          method: 'GET'
        })
      ]);

      // 设置统计数据
      if (statsResponse?.success) {
        const statsData = statsResponse.data;
        this.setData({
          todayCheckinsCount: statsData.today_checkins_count || 0,
          totalCheckinsCount: statsData.total_checkins_count || 0,
          totalFlowersCount: statsData.total_flowers_count || 0
        });
      }

    } catch (error) {
      console.error('加载额外数据失败:', error);
      // 加载模拟数据作为后备
      this.loadMockAdditionalData();
    }
  },

  // 加载打卡数据
  async loadCheckinsData() {
    try {
      const app = getApp();
      let url = `/api/v1/reading_events/${this.data.eventId}/checkins`;
      let data = {};

      // 根据筛选条件调整请求参数
      if (this.data.checkinFilter === 'today') {
        data.today_only = true;
      } else if (this.data.checkinFilter === 'featured') {
        data.featured_only = true;
      }

      const response = await app.request({
        url,
        method: 'GET',
        data
      });

      if (response?.success) {
        this.setData({
          checkins: response.data.checkins || []
        });
      }

      return response;
    } catch (error) {
      console.error('加载打卡数据失败:', error);
      return null;
    }
  },

  // 计算当前是第几天
  calculateCurrentDay(eventData) {
    if (!eventData.start_date || !eventData.end_date) {
      return 1;
    }

    const now = new Date();
    const startDate = new Date(eventData.start_date);
    const diffDays = Math.floor((now - startDate) / (1000 * 60 * 60 * 24)) + 1;

    return Math.max(1, Math.min(diffDays, eventData.days_count));
  },

  // 加载模拟数据（后备方案）
  loadMockData() {
    try {
      const mockEvent = {
        id: this.data.eventId,
        title: '《百年孤独》深度阅读共读活动',
        book_name: '百年孤独',
        description: '这是一场关于《百年孤独》的深度阅读活动。我们将用30天的时间，一起探索马尔克斯创造的魔幻现实主义世界。',
        status: 'in_progress',
        status_text: '进行中',
        date_range: '2024-01-15 至 2024-02-14',
        days_count: 30,
        participants_count: 15,
        max_participants: 20,
        can_enroll: true
      };

      const currentDay = this.calculateCurrentDay(mockEvent);
      const progressPercent = Math.min(100, Math.round((currentDay / mockEvent.days_count) * 100));

      this.setData({
        eventInfo: mockEvent,
        currentDay,
        activityProgress: progressPercent,
        loading: false
      });

      // 加载模拟的额外数据
      this.loadMockAdditionalData();

    } catch (error) {
      console.error('加载模拟数据失败:', error);
      this.setData({ loading: false });
      wx.showToast({
        title: '加载失败',
        icon: 'none'
      });
    }
  },

  // 加载模拟额外数据
  loadMockAdditionalData() {
    const mockFeaturedCheckins = [
      {
        id: 1,
        author: {
          id: 1,
          nickname: '读书达人',
          avatar_url: 'https://picsum.photos/50/50?random=1'
        },
        content_preview: '今天读到了关于马孔多的预言部分，感觉很有意思。马尔克斯通过预言的方式，展现了时间的循环和命运的必然性。',
        images: ['https://picsum.photos/300/200?random=100'],
        likes_count: 15,
        comments_count: 8,
        views_count: 45,
        created_at_relative: '今天 20:30'
      },
      {
        id: 2,
        author: {
          id: 2,
          nickname: '书虫小明',
          avatar_url: 'https://picsum.photos/50/50?random=2'
        },
        content_preview: '布恩迪亚家族的循环命运让我深思，每个人都有自己的"预言"。',
        images: [],
        likes_count: 12,
        comments_count: 6,
        views_count: 32,
        created_at_relative: '今天 18:15'
      }
    ];

    const mockHotDiscussions = [
      {
        id: 1,
        title: '马尔克斯的魔幻现实主义技巧分析',
        author: {
          id: 1,
          nickname: '读书达人',
          avatar_url: 'https://picsum.photos/50/50?random=1'
        },
        content_preview: '今天想和大家探讨一下马尔克斯在《百年孤独》中运用的魔幻现实主义技巧...',
        comments_count: 15,
        views_count: 128,
        created_at_relative: '2小时前'
      }
    ];

    const mockLearningResources = [
      {
        id: 1,
        type: 'article',
        title: '《百年孤独》人物关系图谱',
        description: '帮助理解复杂的人物关系',
        created_at_relative: '3天前',
        views_count: 89
      },
      {
        id: 2,
        type: 'video',
        title: '马尔克斯创作背景介绍',
        description: '了解作者和作品的创作历程',
        created_at_relative: '1周前',
        views_count: 156
      }
    ];

    const mockImpactData = {
      totalViews: 2456,
      totalShares: 89,
      avgEngagement: 78,
      weeklyTrend: [
        { day: '周一', percentage: 65 },
        { day: '周二', percentage: 72 },
        { day: '周三', percentage: 78 },
        { day: '周四', percentage: 85 },
        { day: '周五', percentage: 92 },
        { day: '周六', percentage: 88 },
        { day: '周日', percentage: 76 }
      ]
    };

    const mockTopParticipants = [
      {
        id: 1,
        nickname: '读书达人',
        avatar_url: 'https://picsum.photos/50/50?random=1',
        check_ins_count: 25,
        flowers_received_count: 18,
        badges: ['活跃', '优秀']
      },
      {
        id: 2,
        nickname: '书虫小明',
        avatar_url: 'https://picsum.photos/50/50?random=2',
        check_ins_count: 22,
        flowers_received_count: 15,
        badges: ['认真']
      }
    ];

    this.setData({
      todayFeaturedCheckins: mockFeaturedCheckins,
      hotDiscussions: mockHotDiscussions,
      learningResources: mockLearningResources,
      impactData: mockImpactData,
      topParticipants: mockTopParticipants,
      todayCheckinsCount: 8,
      totalCheckinsCount: 156,
      totalFlowersCount: 89
    });
  },

  // === 页面交互方法 ===

  // 升级为参与者
  upgradeToParticipant() {
    if (!this.data.eventInfo.can_enroll) {
      wx.showToast({
        title: '活动已满员',
        icon: 'none'
      });
      return;
    }

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

    wx.showModal({
      title: '升级为参与者',
      content: '升级后可以提交打卡、参与互动，获得完整的学习体验。确定要升级吗？',
      confirmText: '立即升级',
      cancelText: '再想想',
      success: async (res) => {
        if (res.confirm) {
          try {
            wx.showLoading({
              title: '升级中...',
              mask: true
            });

            const app = getApp();
            const response = await app.request({
              url: '/api/v1/event_enrollments/upgrade',
              method: 'POST',
              data: {
                reading_event_id: this.data.eventId
              }
            });

            wx.hideLoading();

            if (response.success) {
              // 重新加载数据
              this.loadObserveData();

              wx.showToast({
                title: '升级成功',
                icon: 'success'
              });

              // 询问是否进入参与主页
              setTimeout(() => {
                wx.showModal({
                  title: '升级成功',
                  content: '是否立即进入参与主页查看今日任务？',
                  confirmText: '进入',
                  cancelText: '稍后',
                  success: (res) => {
                    if (res.confirm) {
                      wx.redirectTo({
                        url: `/pages/event/participate?id=${this.data.eventId}`
                      });
                    }
                  }
                });
              }, 1500);

            } else {
              throw new Error(response.message || '升级失败');
            }

          } catch (error) {
            wx.hideLoading();
            console.error('升级失败:', error);

            let errorMsg = '升级失败';
            if (error.message) {
              if (error.message.includes('满员')) {
                errorMsg = '活动人数已满';
              } else {
                errorMsg = error.message;
              }
            }

            wx.showToast({
              title: errorMsg,
              icon: 'none'
            });
          }
        }
      }
    });
  },

  // 查看打卡详情
  viewCheckinDetail(e) {
    const checkinId = e.currentTarget.dataset.id;
    wx.navigateTo({
      url: `/pages/event/checkinDetail?id=${checkinId}`
    });
  },

  // 查看讨论详情
  viewDiscussionDetail(e) {
    const discussionId = e.currentTarget.dataset.id;
    wx.navigateTo({
      url: `/pages/event/discussionDetail?id=${discussionId}`
    });
  },

  // 查看资源详情
  viewResourceDetail(e) {
    const resourceId = e.currentTarget.dataset.id;
    wx.navigateTo({
      url: `/pages/event/resourceDetail?id=${resourceId}`
    });
  },

  // 查看参与者资料
  viewParticipantProfile(e) {
    const participantId = e.currentTarget.dataset.id;
    wx.navigateTo({
      url: `/pages/event/participantProfile?id=${participantId}`
    });
  },

  // 过滤打卡
  async filterCheckins(e) {
    const filter = e.currentTarget.dataset.filter;
    this.setData({
      checkinFilter: filter
    });
    await this.loadCheckinsData();
  },

  // 点赞打卡
  async likeCheckin(e) {
    const checkinId = e.currentTarget.dataset.id;

    try {
      const app = getApp();
      const response = await app.request({
        url: `/api/v1/checkins/${checkinId}/like`,
        method: 'POST'
      });

      if (response?.success) {
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
      }
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

    try {
      const app = getApp();
      const response = await app.request({
        url: `/api/v1/checkins/${this.data.currentCheckinId}/comments`,
        method: 'POST',
        data: {
          comment: {
            content: this.data.commentContent.trim()
          }
        }
      });

      if (response?.success) {
        wx.showToast({
          title: '评论成功',
          icon: 'success'
        });

        // 隐藏评论框
        this.hideCommentInput();

        // 重新加载打卡列表
        await this.loadCheckinsData();
      }
    } catch (error) {
      console.error('评论失败:', error);
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
            const app = getApp();
            const response = await app.request({
              url: `/api/v1/comments/${commentId}`,
              method: 'DELETE'
            });

            if (response?.success) {
              wx.showToast({
                title: '删除成功',
                icon: 'success'
              });

              // 从本地数据中移除评论
              this.removeCommentFromList(checkinId, commentIndex);
            }
          } catch (error) {
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

  // 送小红花给打卡
  async giveFlowerToCheckin(e) {
    const { id: checkinId, userId } = e.currentTarget.dataset;

    try {
      const app = getApp();
      const response = await app.request({
        url: `/api/v1/flowers/give`,
        method: 'POST',
        data: {
          flower: {
            receiver_id: userId,
            checkin_id: checkinId,
            flower_type: 'like'
          }
        }
      });

      if (response?.success) {
        wx.showToast({
          title: '送花成功',
          icon: 'success'
        });

        // 重新加载数据
        await this.loadAdditionalData();
      }
    } catch (error) {
      console.error('送花失败:', error);
      wx.showToast({
        title: '送花失败',
        icon: 'none'
      });
    }
  },

  // 分享打卡
  shareCheckin(e) {
    const checkinId = e.currentTarget.dataset.id;
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

  // 切换活动信息显示
  toggleEventInfo() {
    this.setData({
      showEventInfo: !this.data.showEventInfo
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

  // === 查看更多方法 ===

  // 查看完整统计
  viewFullStats() {
    wx.navigateTo({
      url: `/pages/event/stats?eventId=${this.data.eventId}`
    });
  },

  // 查看所有精选
  viewAllFeatured() {
    wx.navigateTo({
      url: `/pages/event/featured?eventId=${this.data.eventId}`
    });
  },

  // 查看全部讨论
  viewAllDiscussions() {
    wx.navigateTo({
      url: `/pages/event/discussions?eventId=${this.data.eventId}`
    });
  },

  // 查看全部资源
  viewAllResources() {
    wx.navigateTo({
      url: `/pages/event/resources?eventId=${this.data.eventId}`
    });
  },

  // 查看影响力详情
  viewImpactDetails() {
    wx.navigateTo({
      url: `/pages/event/impact?eventId=${this.data.eventId}`
    });
  },

  // 查看所有参与者
  viewAllParticipants() {
    wx.navigateTo({
      url: `/pages/event/participants?eventId=${this.data.eventId}`
    });
  },

  // 查看排行榜
  viewRanking() {
    wx.navigateTo({
      url: `/pages/event/ranking?eventId=${this.data.eventId}`
    });
  },

  // 联系组织者
  contactOrganizer() {
    wx.showToast({
      title: '联系功能开发中',
      icon: 'none'
    });
  },

  // 分享活动
  shareActivity() {
    const shareData = {
      title: this.data.eventInfo.title,
      path: `/pages/event/detail?id=${this.data.eventId}`,
      imageUrl: this.data.eventInfo.book_cover_url || ''
    };

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

  // === 页面导航方法 ===

  // 跳转到参与主页
  goToParticipate() {
    // 如果已经是参与者，直接跳转
    if (this.data.myEnrollment && this.data.myEnrollment.enrollment_type === 'participant') {
      wx.redirectTo({
        url: `/pages/event/participate?id=${this.data.eventId}`
      });
      return;
    }

    // 否则提示升级为参与者
    this.upgradeToParticipant();
  },

  // 跳转到活动详情页
  goToDetail() {
    wx.navigateTo({
      url: `/pages/event/detail?id=${this.data.eventId}`
    });
  },

  // 返回列表
  goBack() {
    wx.navigateBack();
  }
});