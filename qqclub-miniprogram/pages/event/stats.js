// pages/event/stats.js
Page({
  data: {
    eventId: null,
    eventInfo: null,
    loading: true,
    timeFilter: 'week', // week, month, all

    // 统计数据
    overallProgress: 75,
    completedTodayCount: 8,
    pendingTodayCount: 7,
    observersCount: 12,

    // 每日统计数据
    dailyStats: [],

    // 打卡排行榜
    topParticipants: [],

    // 活跃度分析
    averageCheckins: 12,
    completionRate: 85,
    activeUsers: 18,

    // 热力图数据
    heatmapData: []
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
    this.loadStatsData();
  },

  // 加载统计数据
  async loadStatsData() {
    this.setData({ loading: true });

    try {
      // 这里应该调用API获取统计数据
      // const response = await api.getEventStats(this.data.eventId);

      // 模拟数据
      const mockEventInfo = {
        id: this.data.eventId,
        title: '《百年孤独》深度阅读共读活动',
        book_name: '百年孤独',
        status: 'in_progress',
        status_text: '进行中',
        status_icon: '📖',
        days_count: 30,
        days_passed: 22,
        days_left: 8,
        participants_count: 15,
        max_participants: 20
      };

      this.setData({
        eventInfo: mockEventInfo,
        overallProgress: Math.round((mockEventInfo.days_passed / mockEventInfo.days_count) * 100)
      });

      // 生成统计数据
      this.generateDailyStats();
      this.generateTopParticipants();
      this.generateHeatmapData();
      this.calculateActivityStats();

      this.setData({ loading: false });

    } catch (error) {
      console.error('加载统计数据失败:', error);
      this.setData({ loading: false });
      wx.showToast({
        title: '加载失败',
        icon: 'none'
      });
    }
  },

  // 生成每日统计数据
  generateDailyStats() {
    const stats = [];
    const maxCount = 15;
    const days = this.data.timeFilter === 'week' ? 7 :
                 this.data.timeFilter === 'month' ? 30 : 30;

    for (let i = days - 1; i >= 0; i--) {
      const date = new Date();
      date.setDate(date.getDate() - i);

      const count = Math.floor(Math.random() * maxCount) + 5;
      const height = (count / maxCount) * 200;

      stats.push({
        date: date.toISOString().split('T')[0],
        label: date.getMonth() + 1 + '/' + date.getDate(),
        count: count,
        height: height,
        color: count > 12 ? 'var(--gradient-primary)' :
               count > 8 ? 'rgba(79, 70, 229, 0.7)' :
               'rgba(79, 70, 229, 0.4)'
      });
    }

    this.setData({ dailyStats: stats });
  },

  // 生成排行榜数据
  generateTopParticipants() {
    const participants = [
      {
        id: 1,
        rank: 1,
        nickname: '读书达人',
        avatar_url: 'https://picsum.photos/100/100?random=1',
        checkins_count: 22,
        activity_score: 95,
        streak: 12,
        medal: '🥇'
      },
      {
        id: 2,
        rank: 2,
        nickname: '书虫小明',
        avatar_url: 'https://picsum.photos/100/100?random=2',
        checkins_count: 20,
        activity_score: 88,
        streak: 8,
        medal: '🥈'
      },
      {
        id: 3,
        rank: 3,
        nickname: '阅读爱好者',
        avatar_url: 'https://picsum.photos/100/100?random=3',
        checkins_count: 18,
        activity_score: 82,
        streak: 6,
        medal: '🥉'
      },
      {
        id: 4,
        rank: 4,
        nickname: '文学青年',
        avatar_url: 'https://picsum.photos/100/100?random=4',
        checkins_count: 17,
        activity_score: 78,
        streak: 3
      },
      {
        id: 5,
        rank: 5,
        nickname: '书海拾贝',
        avatar_url: 'https://picsum.photos/100/100?random=5',
        checkins_count: 16,
        activity_score: 75,
        streak: 5
      },
      {
        id: 6,
        rank: 6,
        nickname: '墨香书韵',
        avatar_url: 'https://picsum.photos/100/100?random=6',
        checkins_count: 15,
        activity_score: 72,
        streak: 2
      },
      {
        id: 7,
        rank: 7,
        nickname: '知行合一',
        avatar_url: 'https://picsum.photos/100/100?random=7',
        checkins_count: 14,
        activity_score: 68,
        streak: 4
      },
      {
        id: 8,
        rank: 8,
        nickname: '书山有路',
        avatar_url: 'https://picsum.photos/100/100?random=8',
        checkins_count: 13,
        activity_score: 65,
        streak: 1
      },
      {
        id: 9,
        rank: 9,
        nickname: '学海无涯',
        avatar_url: 'https://picsum.photos/100/100?random=9',
        checkins_count: 12,
        activity_score: 62,
        streak: 0
      },
      {
        id: 10,
        rank: 10,
        nickname: '静心阅读',
        avatar_url: 'https://picsum.photos/100/100?random=10',
        checkins_count: 11,
        activity_score: 58,
        streak: 0
      }
    ];

    this.setData({ topParticipants: participants });
  },

  // 生成热力图数据
  generateHeatmapData() {
    const heatmapData = [];
    const days = 35; // 5周的数据

    for (let i = days - 1; i >= 0; i--) {
      const date = new Date();
      date.setDate(date.getDate() - i);

      const count = Math.floor(Math.random() * 20);
      let color;

      if (count === 0) {
        color = 'rgba(79, 70, 229, 0.05)';
      } else if (count <= 5) {
        color = 'rgba(79, 70, 229, 0.2)';
      } else if (count <= 10) {
        color = 'rgba(79, 70, 229, 0.4)';
      } else if (count <= 15) {
        color = 'rgba(79, 70, 229, 0.6)';
      } else {
        color = 'rgba(79, 70, 229, 0.8)';
      }

      heatmapData.push({
        date: date.toISOString().split('T')[0],
        count: count,
        color: color
      });
    }

    this.setData({ heatmapData });
  },

  // 计算活跃度统计
  calculateActivityStats() {
    const totalCheckins = this.data.topParticipants.reduce((sum, p) => sum + p.checkins_count, 0);
    const averageCheckins = Math.round(totalCheckins / this.data.topParticipants.length);

    const activeUsers = this.data.topParticipants.filter(p => p.activity_score >= 70).length;
    const completionRate = Math.round((this.data.completedTodayCount / this.data.eventInfo.participants_count) * 100);

    this.setData({
      averageCheckins: averageCheckins,
      activeUsers: activeUsers,
      completionRate: completionRate
    });
  },

  // 切换时间过滤器
  switchTimeFilter(e) {
    const filter = e.currentTarget.dataset.filter;
    this.setData({ timeFilter: filter });
    this.generateDailyStats();
  },

  // 显示热力图详情
  showHeatmapDetail(e) {
    const date = e.currentTarget.dataset.date;
    const dayData = this.data.heatmapData.find(item => item.date === date);

    if (dayData && dayData.count > 0) {
      wx.showModal({
        title: `${date} 打卡详情`,
        content: `当天共有 ${dayData.count} 人完成打卡`,
        showCancel: false
      });
    }
  },

  // 分享统计数据
  shareStats() {
    wx.showShareMenu({
      withShareTicket: true
    });
  },

  // 返回上一页
  goBack() {
    wx.navigateBack();
  },

  // 页面分享
  onShareAppMessage() {
    return {
      title: `${this.data.eventInfo?.title || '活动'}数据统计`,
      path: `/pages/event/stats?id=${this.data.eventId}`,
      imageUrl: '' // 可以设置分享图片
    };
  },

  // 分享到朋友圈
  onShareTimeline() {
    return {
      title: `${this.data.eventInfo?.title || '活动'}数据统计`,
      query: `id=${this.data.eventId}`,
      imageUrl: '' // 可以设置分享图片
    };
  }
});