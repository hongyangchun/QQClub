// pages/forum/list.js
const api = require('../../utils/api')

Page({
  data: {
    userInfo: null,
    posts: [],
    currentCategory: 'all',
    currentSort: 'latest',
    searchKeyword: '',
    loading: false,
    hasMore: true,
    page: 1,
    showMoreMenu: false,
    currentPost: null,
    userId: null,
    categoryCounts: {
      reading: 0,
      activity: 0,
      chat: 0,
      help: 0
    }
  },

  onLoad(options) {
    this.setData({
      userId: wx.getStorageSync('userInfo')?.id || null
    });
    this.getUserInfo();
    this.loadPosts(true);
  },

  onShow() {
    this.getUserInfo();
    // 如果从其他页面返回，刷新列表
    if (this.data.posts.length > 0) {
      this.loadPosts(true);
    }
  },

  onPullDownRefresh() {
    this.loadPosts(true).then(() => {
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

  // 切换板块
  switchCategory(e) {
    const category = e.currentTarget.dataset.category;
    if (category !== this.data.currentCategory) {
      this.setData({
        currentCategory: category,
        page: 1,
        posts: []
      });
      this.loadPosts(true);
    }
  },

  // 切换排序
  changeSort(e) {
    const sort = e.currentTarget.dataset.sort;
    if (sort !== this.data.currentSort) {
      this.setData({
        currentSort: sort,
        page: 1,
        posts: []
      });
      this.loadPosts(true);
    }
  },

  // 搜索输入
  onSearchInput(e) {
    this.setData({
      searchKeyword: e.detail.value
    });
  },

  // 清空搜索
  clearSearch() {
    this.setData({
      searchKeyword: '',
      page: 1,
      posts: []
    });
    this.loadPosts(true);
  },

  // 搜索确认
  onSearchConfirm() {
    this.performSearch();
  },

  // 执行搜索
  performSearch() {
    this.setData({
      page: 1,
      posts: []
    });
    this.loadPosts(true);
  },

  // 根据标签搜索
  searchByTag(e) {
    const tag = e.currentTarget.dataset.tag;
    this.setData({
      searchKeyword: tag,
      page: 1,
      posts: []
    });
    this.loadPosts(true);
  },

  // 加载帖子列表
  async loadPosts(refresh = false) {
    if (this.data.loading) return;

    this.setData({ loading: true });

    try {
      const params = {
        category: this.data.currentCategory === 'all' ? '' : this.data.currentCategory,
        keyword: this.data.searchKeyword
      };

      // 使用真实API调用
      const response = await api.post.getList(params);

      if (Array.isArray(response)) {
        const newPosts = refresh ? response : [...this.data.posts, ...response];

        // 计算分类数量
        const categoryCounts = {
          reading: response.filter(p => p.category === 'reading').length,
          activity: response.filter(p => p.category === 'activity').length,
          chat: response.filter(p => p.category === 'chat').length,
          help: response.filter(p => p.category === 'help').length
        };

        this.setData({
          posts: newPosts,
          hasMore: false, // 暂时关闭分页，因为后端API还没有实现分页
          categoryCounts: categoryCounts
        });
      }
    } catch (error) {
      console.error('加载帖子失败:', error);

      // 检查是否是认证错误
      if (error.message && error.message.includes('未授权')) {
        // 认证失败，清除本地存储并跳转到登录页
        wx.removeStorageSync('token');
        wx.removeStorageSync('userInfo');
        wx.showModal({
          title: '登录已过期',
          content: '请重新登录后继续使用',
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
        title: '加载失败',
        icon: 'none'
      });

      // 如果API调用失败，回退到模拟数据
      const response = await this.mockApiCall({
        page: 1,
        category: this.data.currentCategory === 'all' ? '' : this.data.currentCategory,
        sort: this.data.currentSort,
        keyword: this.data.searchKeyword
      });

      const newPosts = refresh ? response.posts : [...this.data.posts, ...response.posts];

      this.setData({
        posts: newPosts,
        hasMore: response.hasMore,
        page: this.data.page + 1,
        categoryCounts: response.categoryCounts || this.data.categoryCounts
      });
    } finally {
      this.setData({ loading: false });
    }
  },

  // 加载更多
  loadMore() {
    this.loadPosts(false);
  },

  // 模拟API调用
  mockApiCall(params) {
    return new Promise((resolve) => {
      setTimeout(() => {
        const mockPosts = this.generateMockPosts(params.page);
        resolve({
          posts: mockPosts,
          hasMore: params.page < 3,
          categoryCounts: {
            reading: 15,
            activity: 8,
            chat: 23,
            help: 5
          }
        });
      }, 500);
    });
  },

  // 生成模拟帖子数据
  generateMockPosts(page) {
    const categories = {
      reading: '读书心得',
      activity: '活动讨论',
      chat: '闲聊区',
      help: '求助问答'
    };

    const posts = [];
    const startIndex = (page - 1) * 10;

    for (let i = 0; i < 10; i++) {
      const categoryKey = Object.keys(categories)[Math.floor(Math.random() * 4)];
      const isEssence = Math.random() > 0.8;

      posts.push({
        id: startIndex + i + 1,
        title: `【${categories[categoryKey]}】这是一个非常有趣的帖子标题 ${startIndex + i + 1}`,
        content: '这是帖子的内容预览，展示了帖子的主要信息。这里会有一些精彩的文字描述，让用户快速了解帖子的内容...',
        content_preview: '这是帖子的内容预览，展示了帖子的主要信息...',
        author: {
          id: Math.floor(Math.random() * 100) + 1,
          nickname: `用户${Math.floor(Math.random() * 1000) + 1}`,
          avatar_url: 'https://picsum.photos/100/100?random=' + Math.random()
        },
        category: categoryKey,
        category_name: categories[categoryKey],
        views_count: Math.floor(Math.random() * 1000) + 50,
        comments_count: Math.floor(Math.random() * 100) + 5,
        likes_count: Math.floor(Math.random() * 200) + 10,
        created_at: new Date(Date.now() - Math.random() * 7 * 24 * 60 * 60 * 1000).toISOString(),
        created_at_relative: this.getRelativeTime(new Date(Date.now() - Math.random() * 7 * 24 * 60 * 60 * 1000)),
        is_essence: isEssence,
        tags: this.generateRandomTags(),
        images: Math.random() > 0.7 ? this.generateRandomImages() : []
      });
    }

    return posts;
  },

  // 生成随机标签
  generateRandomTags() {
    const allTags = ['小说', '散文', '诗歌', '历史', '哲学', '心理学', '科技', '艺术', '音乐', '电影'];
    const tagCount = Math.floor(Math.random() * 4);
    const tags = [];

    for (let i = 0; i < tagCount; i++) {
      const randomTag = allTags[Math.floor(Math.random() * allTags.length)];
      if (!tags.includes(randomTag)) {
        tags.push(randomTag);
      }
    }

    return tags;
  },

  // 生成随机图片
  generateRandomImages() {
    const imageCount = Math.floor(Math.random() * 3) + 1;
    const images = [];

    for (let i = 0; i < imageCount; i++) {
      images.push(`https://picsum.photos/300/200?random=${Math.random()}`);
    }

    return images;
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

  // 跳转到帖子详情
  goToPostDetail(e) {
    const postId = e.currentTarget.dataset.id;
    wx.navigateTo({
      url: `/pages/forum/detail?id=${postId}`
    });
  },

  // 跳转到发帖页面
  goToCreatePost() {
    if (!this.data.userInfo) {
      wx.showModal({
        title: '提示',
        content: '请先登录后再发帖',
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

    wx.navigateTo({
      url: '/pages/forum/create'
    });
  },

  // 显示更多菜单
  toggleMoreMenu(e) {
    const postId = e.currentTarget.dataset.id;
    const post = this.data.posts.find(p => p.id === postId);

    if (!post) {
      console.warn('Post not found for ID:', postId);
      return;
    }

    console.log('Setting currentPost:', post);
    this.setData({
      showMoreMenu: true,
      currentPost: post
    });
  },

  // 隐藏更多菜单
  hideMoreMenu() {
    this.setData({
      showMoreMenu: false,
      currentPost: null
    });
  },

  // 阻止事件冒泡
  stopPropagation() {
    // 阻止点击菜单内容时关闭弹窗
  },

  // 编辑帖子
  editPost() {
    if (!this.data.currentPost) return;

    this.hideMoreMenu();
    wx.navigateTo({
      url: `/pages/forum/create?id=${this.data.currentPost.id}`
    });
  },

  // 删除帖子
  async deletePost() {
    if (!this.data.currentPost) {
      console.warn('currentPost is null, cannot delete');
      return;
    }

    const postId = this.data.currentPost.id;
    if (!postId) {
      console.warn('currentPost.id is null, cannot delete');
      return;
    }

    // 先保存帖子信息，避免在操作过程中被重置
    const postToDelete = this.data.currentPost;

    wx.showModal({
      title: '确认删除',
      content: '删除后将无法恢复，确定要删除这个帖子吗？',
      success: async (res) => {
        if (res.confirm) {
          this.hideMoreMenu();

          try {
            // 显示删除中状态
            wx.showLoading({
              title: '删除中...',
              mask: true
            });

            // 调用删除API
            await api.post.delete(postId);

            wx.hideLoading();
            wx.showToast({
              title: '删除成功',
              icon: 'success'
            });

            // 从本地列表中立即移除帖子，提供更好的用户体验
            const newPosts = this.data.posts.filter(post => post.id !== postId);
            this.setData({
              posts: newPosts,
              currentPost: null // 确保清除currentPost
            });

            // 然后重新加载列表以确保数据同步
            setTimeout(() => {
              this.loadPosts(true);
            }, 1000);
          } catch (error) {
            wx.hideLoading();
            console.error('删除帖子失败:', error);

            // 根据错误类型显示不同的提示
            let errorMessage = '删除失败';
            if (error.message) {
              if (error.message.includes('权限')) {
                errorMessage = '无权限删除此帖子';
              } else if (error.message.includes('未找到')) {
                errorMessage = '帖子不存在';
              } else if (error.message.includes('未授权')) {
                errorMessage = '登录已过期，请重新登录';
              }
            }

            wx.showToast({
              title: errorMessage,
              icon: 'none',
              duration: 2000
            });
          }
        }
      }
    });
  },

  // 举报帖子
  reportPost() {
    if (!this.data.currentPost) return;

    this.hideMoreMenu();
    wx.showModal({
      title: '举报帖子',
      content: '请选择举报原因',
      showCancel: true,
      success: (res) => {
        if (res.confirm) {
          wx.showToast({
            title: '举报成功',
            icon: 'success'
          });
        }
      }
    });
  },

  // 分享帖子
  sharePost() {
    if (!this.data.currentPost) return;

    this.hideMoreMenu();
    wx.showShareMenu({
      withShareTicket: true
    });
  },

  // 分享功能
  onShareAppMessage() {
    return {
      title: '恰恰读书会 - 交流区',
      path: '/pages/forum/list',
      imageUrl: '/images/share-cover.jpg'
    }
  },

  onShareTimeline() {
    return {
      title: '恰恰读书会 - 交流区',
      imageUrl: '/images/share-cover.jpg'
    }
  },

  // 预览图片
  previewImage(e) {
    const { urls, current } = e.currentTarget.dataset;
    wx.previewImage({
      current,
      urls
    });
  },

  // 点赞帖子
  async likePost(e) {
    const postId = e.currentTarget.dataset.id;
    const userInfo = this.data.userInfo;

    if (!userInfo) {
      wx.showModal({
        title: '提示',
        content: '请先登录后再点赞',
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
      // 找到对应的帖子
      const posts = this.data.posts.map(post => {
        if (post.id === postId) {
          // 切换点赞状态
          if (post.liked_by_current_user) {
            // 取消点赞
            api.post.unlike(postId);
            return {
              ...post,
              liked_by_current_user: false,
              likes_count: Math.max(0, post.likes_count - 1)
            };
          } else {
            // 点赞
            api.post.like(postId);
            return {
              ...post,
              liked_by_current_user: true,
              likes_count: post.likes_count + 1
            };
          }
        }
        return post;
      });

      this.setData({ posts });

      // 异步更新后端状态
      try {
        if (this.data.posts.find(p => p.id === postId)?.liked_by_current_user) {
          await api.post.like(postId);
        } else {
          await api.post.unlike(postId);
        }
      } catch (error) {
        console.error('点赞操作失败:', error);
        // 如果API调用失败，回滚UI状态
        this.loadPosts(true);
      }
    } catch (error) {
      console.error('点赞失败:', error);
      wx.showToast({
        title: '操作失败',
        icon: 'none'
      });
    }
  }
});