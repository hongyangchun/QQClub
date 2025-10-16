// pages/profile/note-export.js
Page({
  data: {
    userInfo: null,
    activities: [],
    selectedActivities: [],
    exportFormat: 'txt',
    loading: false,
    hasMore: true,
    page: 1,
    searchKeyword: '',
    dateFilter: 'all',
    statusFilter: 'all'
  },

  onLoad(options) {
    this.getUserInfo();
    this.loadActivities(true);
  },

  onShow() {
    this.getUserInfo();
  },

  onPullDownRefresh() {
    this.loadActivities(true).then(() => {
      wx.stopPullDownRefresh();
    });
  },

  onReachBottom() {
    if (this.data.hasMore && !this.data.loading) {
      this.loadMore();
    }
  },

  // 获取用户信息
  getUserInfo() {
    const userInfo = wx.getStorageSync('userInfo');
    if (userInfo) {
      this.setData({ userInfo });
    }
  },

  // 搜索输入
  onSearchInput(e) {
    this.setData({
      searchKeyword: e.detail.value
    });
  },

  // 搜索确认
  onSearchConfirm() {
    this.setData({
      page: 1,
      activities: []
    });
    this.loadActivities(true);
  },

  // 清空搜索
  clearSearch() {
    this.setData({
      searchKeyword: '',
      page: 1,
      activities: []
    });
    this.loadActivities(true);
  },

  // 切换日期筛选
  changeDateFilter(e) {
    const filter = e.currentTarget.dataset.filter;
    if (filter !== this.data.dateFilter) {
      this.setData({
        dateFilter: filter,
        page: 1,
        activities: []
      });
      this.loadActivities(true);
    }
  },

  // 切换状态筛选
  changeStatusFilter(e) {
    const filter = e.currentTarget.dataset.filter;
    if (filter !== this.data.statusFilter) {
      this.setData({
        statusFilter: filter,
        page: 1,
        activities: []
      });
      this.loadActivities(true);
    }
  },

  // 加载活动列表
  async loadActivities(refresh = false) {
    if (this.data.loading) return;

    this.setData({ loading: true });

    try {
      const page = refresh ? 1 : this.data.page;
      const response = await this.mockApiCall({
        page,
        keyword: this.data.searchKeyword,
        dateFilter: this.data.dateFilter,
        statusFilter: this.data.statusFilter
      });

      const newActivities = refresh ? response.activities : [...this.data.activities, ...response.activities];

      this.setData({
        activities: newActivities,
        hasMore: response.hasMore,
        page: page + 1
      });
    } catch (error) {
      console.error('加载活动失败:', error);
      wx.showToast({
        title: '加载失败',
        icon: 'none'
      });
    } finally {
      this.setData({ loading: false });
    }
  },

  // 加载更多
  loadMore() {
    this.loadActivities(false);
  },

  // 模拟API调用
  mockApiCall(params) {
    return new Promise((resolve) => {
      setTimeout(() => {
        const mockActivities = this.generateMockActivities(params.page);
        resolve({
          activities: mockActivities,
          hasMore: params.page < 3
        });
      }, 500);
    });
  },

  // 生成模拟活动数据
  generateMockActivities(page) {
    const activities = [];
    const startIndex = (page - 1) * 10;

    const statusOptions = ['ongoing', 'completed', 'upcoming'];
    const statusTexts = {
      ongoing: '进行中',
      completed: '已结束',
      upcoming: '即将开始'
    };

    for (let i = 0; i < 10; i++) {
      const status = statusOptions[Math.floor(Math.random() * statusOptions.length)];
      const participantCount = Math.floor(Math.random() * 50) + 10;
      const homeworkCount = Math.floor(Math.random() * 20) + 5;

      activities.push({
        id: startIndex + i + 1,
        title: `共读活动《示例书籍${startIndex + i + 1}》`,
        book_name: `示例书籍${startIndex + i + 1}`,
        book_author: `作者${startIndex + i + 1}`,
        description: '这是一个关于深度阅读和思考分享的活动，我们通过每日打卡和作业提交来共同进步。',
        status: status,
        status_text: statusTexts[status],
        start_date: new Date(Date.now() - Math.random() * 30 * 24 * 60 * 60 * 1000).toISOString().split('T')[0],
        end_date: new Date(Date.now() + Math.random() * 30 * 24 * 60 * 60 * 1000).toISOString().split('T')[0],
        participants_count: participantCount,
        homework_count: homeworkCount,
        my_homework_count: Math.floor(Math.random() * homeworkCount),
        created_at: new Date(Date.now() - Math.random() * 60 * 24 * 60 * 60 * 1000).toISOString(),
        role: Math.random() > 0.7 ? 'organizer' : 'participant'
      });
    }

    return activities;
  },

  // 切换活动选择
  toggleActivitySelection(e) {
    const activityId = e.currentTarget.dataset.id;
    const { selectedActivities } = this.data;

    if (selectedActivities.includes(activityId)) {
      this.setData({
        selectedActivities: selectedActivities.filter(id => id !== activityId)
      });
    } else {
      this.setData({
        selectedActivities: [...selectedActivities, activityId]
      });
    }
  },

  // 全选/取消全选
  toggleSelectAll() {
    const { activities, selectedActivities } = this.data;
    const allIds = activities.map(a => a.id);

    if (selectedActivities.length === activities.length) {
      // 取消全选
      this.setData({ selectedActivities: [] });
    } else {
      // 全选
      this.setData({ selectedActivities: allIds });
    }
  },

  // 切换导出格式
  changeExportFormat(e) {
    this.setData({
      exportFormat: e.currentTarget.dataset.format
    });
  },

  // 导出笔记
  async exportNotes() {
    if (this.data.selectedActivities.length === 0) {
      wx.showToast({
        title: '请选择要导出的活动',
        icon: 'none'
      });
      return;
    }

    this.setData({ loading: true });

    try {
      // 模拟导出过程
      await this.performExport();

      wx.showToast({
        title: '导出成功',
        icon: 'success'
      });

      // 清空选择
      this.setData({ selectedActivities: [] });

    } catch (error) {
      console.error('导出失败:', error);
      wx.showToast({
        title: '导出失败',
        icon: 'none'
      });
    } finally {
      this.setData({ loading: false });
    }
  },

  // 执行导出
  performExport() {
    return new Promise((resolve) => {
      setTimeout(() => {
        // 这里模拟实际的导出逻辑
        const selectedActivities = this.data.activities.filter(a =>
          this.data.selectedActivities.includes(a.id)
        );

        console.log('导出活动:', selectedActivities);
        console.log('导出格式:', this.data.exportFormat);

        resolve();
      }, 2000);
    });
  },

  // 查看活动详情
  goToActivityDetail(e) {
    const activityId = e.currentTarget.dataset.id;
    wx.navigateTo({
      url: `/pages/event/detail?id=${activityId}`
    });
  },

  // 预览导出内容
  previewExport() {
    if (this.data.selectedActivities.length === 0) {
      wx.showToast({
        title: '请选择要预览的活动',
        icon: 'none'
      });
      return;
    }

    const selectedActivities = this.data.activities.filter(a =>
      this.data.selectedActivities.includes(a.id)
    );

    wx.showModal({
      title: '导出预览',
      content: `将导出 ${selectedActivities.length} 个活动的作业内容，共 ${selectedActivities.reduce((sum, a) => sum + a.my_homework_count, 0)} 篇笔记。格式：${this.data.exportFormat.toUpperCase()}`,
      showCancel: false,
      confirmText: '知道了'
    });
  },

  // 分享功能
  onShareAppMessage() {
    return {
      title: '恰恰读书会 - 笔记导出',
      path: '/pages/profile/note-export',
      imageUrl: '/images/share-cover.jpg'
    }
  }
});