// pages/event/checkin.js
const app = getApp()

Page({
  data: {
    eventId: null,
    eventInfo: null,
    userInfo: null,
    myEnrollment: null,

    // 今日任务信息
    todayTask: null,
    currentDay: 1,
    readingContent: '',
    thinkingQuestions: [],

    // 打卡表单
    checkinContent: '',
    selectedImages: [],
    maxImages: 9,

    // 加载状态
    loading: false,
    submitting: false,

    // UI状态
    wordCount: 0,
    maxWords: 500,

    // 页面模式
    mode: 'create', // create, edit
    checkinId: null,

    // 预览图片相关
    previewCurrentIndex: 0,
    showImagePreview: false
  },

  onLoad(options) {
    console.log('=== 打卡编辑页面加载 ===');
    console.log('参数:', options);

    const eventId = options.eventId;
    const mode = options.mode || 'create';
    const checkinId = options.checkinId;

    if (!eventId) {
      wx.showToast({
        title: '参数错误',
        icon: 'none'
      });
      wx.navigateBack();
      return;
    }

    this.setData({
      eventId,
      mode,
      checkinId
    });

    this.getUserInfo();
    this.loadPageData();
  },

  // 获取用户信息
  getUserInfo() {
    const userInfo = wx.getStorageSync('userInfo');
    if (userInfo) {
      this.setData({ userInfo });
    }
  },

  // 加载页面数据
  async loadPageData() {
    this.setData({ loading: true });

    try {
      // 并行加载活动详情、今日任务和编辑数据（如果是编辑模式）
      const [eventResponse, todayTaskResponse] = await Promise.all([
        // 获取活动详情
        app.request({
          url: `/api/v1/reading_events/${this.data.eventId}`,
          method: 'GET'
        }),
        // 获取今日任务
        this.getTodayTask()
      ]);

      if (eventResponse.success) {
        const eventData = eventResponse.data;
        const myEnrollment = eventData.user_enrollment;

        // 验证用户权限
        if (!myEnrollment || myEnrollment.enrollment_type !== 'participant') {
          wx.showModal({
            title: '权限提示',
            content: '只有活动参与者才能提交打卡作业',
            confirmText: '返回',
            success: (res) => {
              if (res.confirm) {
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
          currentDay
        });
      }

      // 如果是编辑模式，加载打卡数据
      if (this.data.mode === 'edit' && this.data.checkinId) {
        await this.loadCheckinData();
      }

      this.setData({ loading: false });

    } catch (error) {
      console.error('加载页面数据失败:', error);
      this.loadMockData();
    }
  },

  // 获取今日任务
  async getTodayTask() {
    try {
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

  // 加载打卡数据（编辑模式）
  async loadCheckinData() {
    try {
      const response = await app.request({
        url: `/api/v1/checkins/${this.data.checkinId}`,
        method: 'GET'
      });

      if (response?.success) {
        const checkinData = response.data;
        this.setData({
          checkinContent: checkinData.content || '',
          selectedImages: checkinData.images || []
        });
        this.updateWordCount();
      }
    } catch (error) {
      console.error('加载打卡数据失败:', error);
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

    return Math.max(1, Math.min(diffDays, eventData.days_count || 30));
  },

  // 加载模拟数据
  loadMockData() {
    try {
      const mockEvent = {
        id: this.data.eventId,
        title: '《百年孤独》深度阅读共读活动',
        book_name: '百年孤独',
        status: 'in_progress',
        days_count: 30
      };

      const mockEnrollment = {
        enrollment_type: 'participant',
        completion_rate: 65,
        check_ins_count: 18
      };

      const mockTodayTask = {
        date: '2024年1月20日',
        reading_content: '第15-16章：预言的循环与宿命的必然\n\n今天我们读到关于梅尔基亚德斯预言的部分，这是小说中非常重要的主题。马尔克斯通过预言的方式，展现了时间的循环性和命运的必然性。布恩迪亚家族的每一个人似乎都无法逃脱这个魔咒，每一个重要事件都有对应的预言。',
        thinking_questions: [
          '1. 马尔克斯如何通过预言展现宿命论？',
          '2. 布恩迪亚家族的循环命运有什么象征意义？',
          '3. 你认为预言在现实生活中有什么样的作用？',
          '4. 宿命与自由意志之间的关系是什么？'
        ],
        leader_notes: '重点分析预言的象征意义，以及它如何推动情节发展。'
      };

      const currentDay = this.calculateCurrentDay(mockEvent);

      this.setData({
        eventInfo: mockEvent,
        myEnrollment: mockEnrollment,
        currentDay,
        todayTask: mockTodayTask,
        loading: false
      });

    } catch (error) {
      console.error('加载模拟数据失败:', error);
      this.setData({ loading: false });
    }
  },

  // === 今日任务相关方法 ===

  // 获取任务内容
  getReadingContent() {
    if (this.data.todayTask) {
      return this.data.todayTask.reading_content || '暂无今日任务内容';
    }
    return '暂无任务信息';
  },

  // 获取思考问题
  getThinkingQuestions() {
    if (this.data.todayTask) {
      return this.data.todayTask.thinking_questions || [];
    }
    return [];
  },

  // === 打卡内容编辑相关方法 ===

  // 输入打卡内容
  onCheckinContentInput(e) {
    const content = e.detail.value;
    this.setData({
      checkinContent: content,
      wordCount: content.length
    });
  },

  // 更新字数统计
  updateWordCount() {
    this.setData({
      wordCount: this.data.checkinContent.length
    });
  },

  // 选择图片
  chooseImage() {
    const remainingCount = this.data.maxImages - this.data.selectedImages.length;

    if (remainingCount <= 0) {
      wx.showToast({
        title: `最多只能上传${this.data.maxImages}张图片`,
        icon: 'none'
      });
      return;
    }

    wx.chooseImage({
      count: remainingCount,
      sizeType: ['compressed'],
      sourceType: ['album', 'camera'],
      success: (res) => {
        const newImages = [...this.data.selectedImages, ...res.tempFilePaths];
        this.setData({ selectedImages: newImages });
      },
      fail: (err) => {
        console.error('选择图片失败:', err);
      }
    });
  },

  // 预览图片
  previewImage(e) {
    const index = e.currentTarget.dataset.index;
    wx.previewImage({
      current: this.data.selectedImages[index],
      urls: this.data.selectedImages
    });
  },

  // 删除图片
  removeImage(e) {
    const index = e.currentTarget.dataset.index;
    const newImages = this.data.selectedImages.filter((_, i) => i !== index);
    this.setData({ selectedImages: newImages });
  },

  // 表单验证
  validateForm() {
    if (!this.data.checkinContent.trim()) {
      wx.showToast({
        title: '请输入打卡内容',
        icon: 'none'
      });
      return false;
    }

    if (this.data.checkinContent.length < 10) {
      wx.showToast({
        title: '打卡内容太短，请至少输入10个字符',
        icon: 'none'
      });
      return false;
    }

    if (this.data.checkinContent.length > this.data.maxWords) {
      wx.showToast({
        title: `打卡内容不能超过${this.data.maxWords}个字符`,
        icon: 'none'
      });
      return false;
    }

    return true;
  },

  // 提交打卡
  async submitCheckIn() {
    if (!this.validateForm()) {
      return;
    }

    this.setData({ submitting: true });

    try {
      wx.showLoading({
        title: '提交中...',
        mask: true
      });

      let url = '/api/v1/checkins';
      let method = 'POST';

      if (this.data.mode === 'edit' && this.data.checkinId) {
        url = `/api/v1/checkins/${this.data.checkinId}`;
        method = 'PUT';
      }

      const response = await app.request({
        url,
        method,
        data: {
          checkin: {
            reading_event_id: this.data.eventId,
            content: this.data.checkinContent.trim(),
            images: this.data.selectedImages,
            day_number: this.data.currentDay
          }
        }
      });

      wx.hideLoading();

      if (response?.success) {
        wx.showToast({
          title: this.data.mode === 'edit' ? '修改成功' : '提交成功',
          icon: 'success'
        });

        // 延迟跳转，让用户看到成功提示
        setTimeout(() => {
          // 返回到活动主页
          wx.navigateBack();
        }, 1500);
      } else {
        throw new Error(response.message || '提交失败');
      }

    } catch (error) {
      wx.hideLoading();
      console.error('提交打卡失败:', error);

      let errorMsg = this.data.mode === 'edit' ? '修改失败' : '提交失败';
      if (error.message) {
        errorMsg = error.message;
      }

      wx.showToast({
        title: errorMsg,
        icon: 'none'
      });
    } finally {
      this.setData({ submitting: false });
    }
  },

  // 保存为草稿
  async saveDraft() {
    // 将打卡内容保存到本地存储
    const draftData = {
      eventId: this.data.eventId,
      checkinContent: this.data.checkinContent,
      selectedImages: this.data.selectedImages,
      currentDay: this.data.currentDay,
      savedAt: new Date().toISOString()
    };

    wx.setStorageSync('checkin_draft', JSON.stringify(draftData));

    wx.showToast({
      title: '草稿已保存',
      icon: 'success'
    });
  },

  // 加载草稿
  loadDraft() {
    try {
      const draftData = wx.getStorageSync('checkin_draft');
      if (draftData) {
        const draft = JSON.parse(draftData);

        // 验证草稿是否属于当前活动
        if (draft.eventId === this.data.eventId) {
          wx.showModal({
            title: '发现草稿',
            content: '是否加载之前保存的草稿内容？',
            confirmText: '加载',
            cancelText: '不用了',
            success: (res) => {
              if (res.confirm) {
                this.setData({
                  checkinContent: draft.checkinContent || '',
                  selectedImages: draft.selectedImages || []
                });
                this.updateWordCount();
              }
            }
          });
        }
      }
    } catch (error) {
      console.error('加载草稿失败:', error);
    }
  },

  // 清除草稿
  clearDraft() {
    wx.removeStorageSync('checkin_draft');
  },

  // 返回上一页
  goBack() {
    // 如果有未保存的内容，提示用户
    if (this.data.checkinContent.trim() || this.data.selectedImages.length > 0) {
      wx.showModal({
        title: '内容未保存',
        content: '返回将丢失当前编辑的内容，是否保存为草稿？',
        confirmText: '保存草稿',
        cancelText: '直接返回',
        success: (res) => {
          if (res.confirm) {
            this.saveDraft().then(() => {
              wx.navigateBack();
            });
          } else {
            this.navigateBack();
          }
        }
      });
    } else {
      this.navigateBack();
    }
  },

  // 直接返回
  navigateBack() {
    wx.navigateBack();
  },

  // 查看今日任务详情
  viewTaskDetail() {
    wx.showModal({
      title: '任务详情',
      content: this.getReadingContent(),
      showCancel: false,
      confirmText: '知道了'
    });
  },

  // 查看思考问题
  viewThinkingQuestions() {
    const questions = this.getThinkingQuestions();
    if (questions.length === 0) {
      wx.showToast({
        title: '今日暂无思考问题',
        icon: 'none'
      });
      return;
    }

    wx.showModal({
      title: '思考问题',
      content: questions.join('\n\n'),
      showCancel: false,
      confirmText: '知道了'
    });
  },

  // === 页面生命周期 ===

  onShow() {
    // 检查是否有草稿
    this.loadDraft();
  },

  onUnload() {
    // 页面卸载时清理资源
    this.clearDraft();
  },

  // 分享功能
  onShareAppMessage() {
    return {
      title: `${this.data.eventInfo?.book_name || '读书活动'} - 第${this.data.currentDay}天打卡`,
      path: `/pages/event/home?id=${this.data.eventId}`,
      imageUrl: this.data.eventInfo?.book_cover_url || '/images/share-cover.jpg'
    };
  },

  onShareTimeline() {
    return {
      title: `我在${this.data.eventInfo?.title || '读书活动'}完成了第${this.data.currentDay}天的打卡`,
      imageUrl: this.data.eventInfo?.book_cover_url || '/images/share-cover.jpg'
    };
  }
});