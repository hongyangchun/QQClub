// pages/event/participate.js
Page({
  data: {
    eventId: null,
    eventInfo: null,
    myEnrollment: null,
    userInfo: null,
    loading: true,

    // 今日任务
    todayTask: null,
    currentDay: 1,
    hasCheckedToday: false,
    todayCheckinTime: '',
    canCheckIn: true,

    // 打卡作业相关
    checkins: [],
    checkinFilter: 'all', // all, today, featured

    // UI状态
    showEventInfo: false,
    showCommentModal: false,
    currentCheckinId: null,
    commentContent: '',

    // 小红花相关
    flowerQuota: 3,
    hasGivenFlowerToday: false,
    totalFlowersCount: 0,

    // 活动动态
    todayCheckinsCount: 0,
    totalCheckinsCount: 0,

    // 统计数据
    myProgress: {
      completionRate: 0,
      checkInsCount: 0,
      flowersReceivedCount: 0,
      leaderDaysCount: 0
    }
  },

  onLoad(options) {
    console.log('=== 参与者页面加载 ===');
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

    console.log('参与者页面 - 活动ID:', eventId);
    this.setData({ eventId });
    this.getUserInfo();
    this.loadParticipateData();
  },

  onShow() {
    // 刷新数据
    if (this.data.eventId) {
      this.loadParticipateData();
    }
  },

  onPullDownRefresh() {
    this.loadParticipateData().then(() => {
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

  // 加载参与者页面数据
  async loadParticipateData() {
    this.setData({ loading: true });

    try {
      const app = getApp();

      // 并行加载多个数据
      const [eventResponse, progressResponse, todayTaskResponse] = await Promise.all([
        // 获取活动详情
        app.request({
          url: `/api/v1/reading_events/${this.data.eventId}`,
          method: 'GET'
        }),
        // 获取我的进度
        this.getMyProgress(),
        // 获取今日任务
        this.getTodayTask()
      ]);

      if (eventResponse.success) {
        const eventData = eventResponse.data;
        const myEnrollment = eventData.user_enrollment;

        // 验证用户是否为参与者
        if (!myEnrollment || myEnrollment.enrollment_type !== 'participant') {
          wx.showModal({
            title: '权限提示',
            content: '您还不是此活动的参与者，请先报名参与',
            confirmText: '去报名',
            success: (res) => {
              if (res.confirm) {
                wx.navigateTo({
                  url: `/pages/event/detail?id=${this.data.eventId}`
                });
              } else {
                wx.navigateBack();
              }
            }
          });
          return;
        }

        // 计算当前是第几天
        const currentDay = this.calculateCurrentDay(eventData);

        this.setData({
          eventInfo: eventData,
          myEnrollment,
          currentDay,
          myProgress: {
            completionRate: myEnrollment.completion_rate || 0,
            checkInsCount: myEnrollment.check_ins_count || 0,
            flowersReceivedCount: myEnrollment.flowers_received_count || 0,
            leaderDaysCount: myEnrollment.leader_days_count || 0
          }
        });
      } else {
        throw new Error(eventResponse.message || '加载活动详情失败');
      }

      // 加载其他数据
      await this.loadAdditionalData();

      this.setData({ loading: false });

    } catch (error) {
      console.error('加载参与者数据失败:', error);

      // 如果API调用失败，使用模拟数据
      this.loadMockData();
    }
  },

  // 获取我的进度
  async getMyProgress() {
    try {
      const app = getApp();
      const response = await app.request({
        url: `/api/v1/event_enrollments/my_progress`,
        method: 'GET',
        data: {
          reading_event_id: this.data.eventId
        }
      });

      return response;
    } catch (error) {
      console.error('获取进度失败:', error);
      return null;
    }
  },

  // 获取今日任务
  async getTodayTask() {
    try {
      const app = getApp();
      const response = await app.request({
        url: `/api/v1/reading_events/${this.data.eventId}/today_task`,
        method: 'GET'
      });

      return response;
    } catch (error) {
      console.error('获取今日任务失败:', error);
      return null;
    }
  },

  // 加载其他数据
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
          url: `/api/v1/reading_events/${this.data.eventId}/participate_stats`,
          method: 'GET'
        })
      ]);

      // 设置统计数据
      if (statsResponse?.success) {
        const statsData = statsResponse.data;
        this.setData({
          todayCheckinsCount: statsData.today_checkins_count || 0,
          totalCheckinsCount: statsData.total_checkins_count || 0,
          totalFlowersCount: statsData.total_flowers_count || 0,
          flowerQuota: statsData.flower_quota || 3,
          hasGivenFlowerToday: statsData.has_given_flower_today || false
        });
      }

      // 检查今日打卡状态
      await this.checkTodayCheckinStatus();

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

  // 检查今日打卡状态
  async checkTodayCheckinStatus() {
    try {
      const app = getApp();
      const response = await app.request({
        url: `/api/v1/reading_events/${this.data.eventId}/today_checkin_status`,
        method: 'GET'
      });

      if (response?.success) {
        const statusData = response.data;
        this.setData({
          hasCheckedToday: statusData.has_checked_today || false,
          todayCheckinTime: statusData.checkin_time || '',
          canCheckIn: statusData.can_check_in !== false
        });
      }

    } catch (error) {
      console.error('检查打卡状态失败:', error);
      // 默认可以打卡
      this.setData({
        hasCheckedToday: false,
        canCheckIn: true
      });
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
        status: 'in_progress',
        status_text: '进行中',
        days_count: 30,
        participants_count: 15
      };

      const mockEnrollment = {
        id: 1,
        enrollment_type: 'participant',
        enrollment_date: '2024-01-15',
        completion_rate: 65,
        check_ins_count: 18,
        flowers_received_count: 12,
        leader_days_count: 3
      };

      const currentDay = this.calculateCurrentDay(mockEvent);

      this.setData({
        eventInfo: mockEvent,
        myEnrollment: mockEnrollment,
        currentDay,
        myProgress: {
          completionRate: mockEnrollment.completion_rate,
          checkInsCount: mockEnrollment.check_ins_count,
          flowersReceivedCount: mockEnrollment.flowers_received_count,
          leaderDaysCount: mockEnrollment.leader_days_count
        },
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
    const mockTodayTask = {
      date: '2024年1月20日',
      reading_content: '第5-6章：梅尔基亚德斯的预言和布恩迪亚家族的命运',
      thinking_questions: [
        '马尔克斯如何通过预言展现宿命论？',
        '布恩迪亚家族的循环命运有什么象征意义？'
      ]
    };

    const mockCheckins = [
      {
        id: 1,
        author: {
          id: 1,
          nickname: '读书达人',
          avatar_url: 'https://picsum.photos/50/50?random=1'
        },
        content: '今天读到了关于马孔多的预言部分，感觉很有意思。马尔克斯通过预言的方式，展现了时间的循环和命运的必然性。布恩迪亚家族的每个人似乎都在重复着相似的命运，这种循环让人深思。',
        images: ['https://picsum.photos/300/200?random=100'],
        day_number: 15,
        is_featured: true,
        is_liked: false,
        likes_count: 15,
        comments_count: 8,
        created_at_relative: '今天 20:30',
        comments: [
          {
            id: 1,
            author: {
              id: 2,
              nickname: '书虫小明',
              avatar_url: 'https://picsum.photos/50/50?random=2'
            },
            content: '很有深度的分析！我也注意到这个宿命论的主题了',
            created_at_relative: '2小时前'
          }
        ]
      },
      {
        id: 2,
        author: {
          id: 3,
          nickname: '阅读爱好者',
          avatar_url: 'https://picsum.photos/50/50?random=3'
        },
        content: '今天的阅读内容让我对拉丁美洲的魔幻现实主义有了更深的理解。马尔克斯用这种手法不仅仅是讲故事，更是在探讨历史和现实。',
        images: [],
        day_number: 15,
        is_featured: false,
        is_liked: true,
        likes_count: 12,
        comments_count: 6,
        created_at_relative: '今天 18:15',
        comments: []
      }
    ];

    this.setData({
      todayTask: mockTodayTask,
      checkins: mockCheckins,
      flowerQuota: 3,
      hasGivenFlowerToday: false,
      totalFlowersCount: 156,
      todayCheckinsCount: 8,
      totalCheckinsCount: 156,
      hasCheckedToday: false,
      canCheckIn: true
    });
  },

  // === 页面交互方法 ===

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

  // 提交打卡
  submitCheckIn() {
    if (this.data.hasCheckedToday) {
      wx.showToast({
        title: '今日已打卡',
        icon: 'none'
      });
      return;
    }

    if (!this.data.canCheckIn) {
      wx.showToast({
        title: '当前时段无法打卡',
        icon: 'none'
      });
      return;
    }

    wx.navigateTo({
      url: `/pages/event/checkin?eventId=${this.data.eventId}&mode=participate`
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

  // 选择小红花接收者
  selectFlowerRecipient() {
    if (this.data.flowerQuota <= 0) {
      wx.showToast({
        title: '今日小红花已用完',
        icon: 'none'
      });
      return;
    }

    wx.navigateTo({
      url: `/pages/event/flowers?eventId=${this.data.eventId}`
    });
  },

  // 查看更多精选
  viewMoreFeatured() {
    wx.navigateTo({
      url: `/pages/event/featured?eventId=${this.data.eventId}`
    });
  },

  // 查看完整排行
  viewFullRanking() {
    wx.navigateTo({
      url: `/pages/event/ranking?eventId=${this.data.eventId}`
    });
  },

  // 查看所有活动动态
  viewAllActivity() {
    wx.navigateTo({
      url: `/pages/event/activity?eventId=${this.data.eventId}`
    });
  },

  // 查看我的进度
  viewMyProgress() {
    wx.navigateTo({
      url: `/pages/event/progress?eventId=${this.data.eventId}`
    });
  },

  // 查看我的打卡
  viewMyCheckins() {
    wx.navigateTo({
      url: `/pages/event/myCheckins?eventId=${this.data.eventId}`
    });
  },

  // 查看小红花历史
  viewFlowersHistory() {
    wx.navigateTo({
      url: `/pages/event/flowersHistory?eventId=${this.data.eventId}`
    });
  },

  // 查看参与者
  viewParticipants() {
    wx.navigateTo({
      url: `/pages/event/participants?eventId=${this.data.eventId}`
    });
  },

  // === 页面导航方法 ===

  // 跳转到围观主页
  goToObserve() {
    // 参与者可以随时切换到围观模式查看内容
    wx.navigateTo({
      url: `/pages/event/observe?id=${this.data.eventId}`
    });
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