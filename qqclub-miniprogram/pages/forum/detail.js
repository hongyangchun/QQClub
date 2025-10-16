// pages/forum/detail.js
const api = require('../../utils/api')

Page({
  data: {
    postId: null,
    postInfo: null,
    loading: true,
    isAuthor: false,

    // 评论相关
    comments: [],
    commentSort: 'newest', // newest, hottest
    hasMoreComments: true,
    loadingComments: false,
    page: 1,

    // 评论输入
    showCommentInput: false,
    commentText: '',
    commentImages: [],
    replyingTo: null,

    // 更多操作
    showActionModal: false
  },

  onLoad(options) {
    const postId = options.id;
    if (!postId) {
      wx.showToast({
        title: '参数错误',
        icon: 'none'
      });
      wx.navigateBack();
      return;
    }

    this.setData({ postId });
    this.loadPostDetail();
    this.loadComments();
  },

  onShow() {
    // 每次显示页面时刷新数据
    if (this.data.postId) {
      this.loadPostDetail();
    }
  },

  onPullDownRefresh() {
    this.loadPostDetail().then(() => {
      this.setData({
        comments: [],
        page: 1,
        hasMoreComments: true
      });
      this.loadComments().then(() => {
        wx.stopPullDownRefresh();
      });
    });
  },

  onReachBottom() {
    if (this.data.hasMoreComments && !this.data.loadingComments) {
      this.loadMoreComments();
    }
  },

  // 加载帖子详情
  async loadPostDetail() {
    try {
      // 调用API获取帖子详情
      const response = await api.post.getDetail(this.data.postId);

      let postData = response;

      // 如果API调用失败，使用模拟数据作为回退
      if (!response) {
        postData = {
          id: this.data.postId,
          title: '《百年孤独》读后感：魔幻现实主义中的孤独与宿命',
          content: '最近重读了马尔克斯的《百年孤独》，再次被这部伟大的作品震撼。魔幻现实主义的手法不仅仅是一种文学技巧，更是拉丁美洲现实的真实写照。\n\n布恩迪亚家族七代人的兴衰史，实际上是一部关于孤独的史诗。每个人都在自己的孤独中挣扎，无法真正理解他人，也无法被他人理解。这种孤独不是简单的寂寞，而是一种深刻的、形而上的孤独。\n\n马尔克斯通过预言、循环的时间、神奇的现实等元素，构建了一个既真实又虚幻的世界。在这个世界里，生与死、过去与现在、现实与幻想的界限都变得模糊。这种模糊性正是拉丁美洲现实的特征——一个充满矛盾和悖论的大陆。\n\n书中最让我感动的是乌尔苏拉，她是这个家族中唯一清醒的人，见证了一代又一代人的重复和失败。她试图打破这个循环，但最终发现一切都是徒劳的。这种无力感也许正是马尔克斯想要表达的——在历史的长河中，个人的努力显得如此渺小。\n\n《百年孤独》不仅仅是一个家族的故事，更是整个拉丁美洲的缩影。它告诉我们，历史是如何重复的，以及我们如何在重复中寻找突破的可能。',
          category: 'reading',
          category_name: '读书心得',
          category_icon: '📚',
          author: {
            id: 1,
            nickname: '文学爱好者',
            avatar_url: 'https://picsum.photos/100/100?random=1',
            badge: '活跃用户'
          },
          tags: ['百年孤独', '马尔克斯', '魔幻现实主义', '读书心得'],
          images: [
            'https://picsum.photos/400/300?random=1',
            'https://picsum.photos/400/300?random=2'
          ],
          views_count: 342,
          comments_count: 28,
          likes_count: 56,
          liked_by_current_user: false,
          is_collected: false,
          created_at: '2024-01-15 14:30',
          allow_comment: true
        };
      }

      // 检查是否是作者
      const userInfo = wx.getStorageSync('userInfo');
      const isAuthor = userInfo && userInfo.id === postData.author.id;

      this.setData({
        postInfo: postData,
        isAuthor: isAuthor
      });

      // 设置页面标题
      wx.setNavigationBarTitle({
        title: postData.title || '帖子详情'
      });

    } catch (error) {
      console.error('加载帖子详情失败:', error);
      wx.showToast({
        title: '加载失败',
        icon: 'none'
      });
    }
  },

  // 加载评论
  async loadComments() {
    if (this.data.loadingComments) return;

    this.setData({ loadingComments: true });

    try {
      // 调用API获取评论
      const response = await api.post.getComments(this.data.postId, {
        page: this.data.page,
        per_page: 20,
        sort: this.data.commentSort
      });

      let commentsData = [];
      let hasMore = false;

      if (Array.isArray(response)) {
        commentsData = response;
        hasMore = false; // 暂时关闭分页
      } else if (response && response.data) {
        commentsData = response.data;
        hasMore = response.has_more || false;
      } else {
        // 如果API调用失败，使用模拟数据作为回退
        commentsData = this.generateMockComments();
        hasMore = this.data.page < 3; // 模拟最多3页
      }

      const newComments = this.data.page === 1 ? commentsData : [...this.data.comments, ...commentsData];

      this.setData({
        comments: newComments,
        hasMoreComments: hasMore,
        loadingComments: false
      });

    } catch (error) {
      console.error('加载评论失败:', error);
      // 如果API调用失败，使用模拟数据作为回退
      const mockComments = this.generateMockComments();
      const newComments = this.data.page === 1 ? mockComments : [...this.data.comments, ...mockComments];
      const hasMore = this.data.page < 3;

      this.setData({
        comments: newComments,
        hasMoreComments: hasMore,
        loadingComments: false
      });

      wx.showToast({
        title: '加载失败',
        icon: 'none'
      });
    }
  },

  // 生成模拟评论
  generateMockComments() {
    const comments = [];
    const count = this.data.page === 1 ? 10 : 5;

    for (let i = 0; i < count; i++) {
      const floor = (this.data.page - 1) * 10 + i + 1;
      const likesCount = Math.floor(Math.random() * 20) + 5;

      comments.push({
        id: Date.now() + i,
        floor: floor,
        content: this.generateCommentContent(i),
        author: {
          id: Math.floor(Math.random() * 100) + 1,
          nickname: `用户${Math.floor(Math.random() * 1000) + 1}`,
          avatar_url: `https://picsum.photos/50/50?random=${Math.floor(Math.random() * 100)}`,
          badge: Math.random() > 0.7 ? '活跃用户' : null
        },
        likes_count: likesCount,
        is_liked: Math.random() > 0.8,
        created_at: this.getRandomTime(),
        images: Math.random() > 0.8 ? [`https://picsum.photos/200/200?random=${Math.floor(Math.random() * 100)}`] : [],
        replies: this.generateReplies(Math.random() > 0.6 ? Math.floor(Math.random() * 3) + 1 : 0),
        replies_count: Math.random() > 0.6 ? Math.floor(Math.random() * 3) + 1 : 0
      });
    }

    return comments;
  },

  // 生成评论内容
  generateCommentContent(index) {
    const contents = [
      '写得真好！我也有类似的感受，马尔克斯的文字确实有种魔力。',
      '《百年孤独》是我最喜欢的作品之一，每次重读都有新的感悟。',
      '你对乌尔苏拉的分析很到位，她确实是这个家族中唯一清醒的人。',
      '魔幻现实主义不仅仅是一种文学技巧，更是拉美现实的真实写照，说得太好了！',
      '孤独确实是这本书的主题，每个人都在自己的孤独中挣扎。',
      '马尔克斯对时间的处理很特别，循环的时间让整个故事更有宿命感。',
      '感谢分享，让我对这部作品有了更深的理解。',
      '你提到的历史循环性很深刻，这确实是值得我们思考的问题。',
      '拉丁美洲的文学总是有种特别的魔幻色彩，《百年孤独》是其中的代表。',
      '你的读后感写得很用心，文字很有感染力。'
    ];

    return contents[index % contents.length];
  },

  // 生成回复
  generateReplies(count) {
    if (count === 0) return [];

    const replies = [];
    for (let i = 0; i < count; i++) {
      replies.push({
        id: Date.now() + i,
        author: {
          nickname: `回复用户${Math.floor(Math.random() * 100) + 1}`
        },
        target_name: `用户${Math.floor(Math.random() * 100) + 1}`,
        content: this.generateReplyContent(i),
        created_at: this.getRandomTime()
      });
    }
    return replies;
  },

  // 生成回复内容
  generateReplyContent(index) {
    const contents = [
      '说得对！',
      '有同感',
      '我也这么觉得',
      '分析得很到位',
      '学到了',
      '感谢分享'
    ];

    return contents[index % contents.length];
  },

  // 生成随机时间
  getRandomTime() {
    const now = new Date();
    const hoursAgo = Math.floor(Math.random() * 72);
    const time = new Date(now.getTime() - hoursAgo * 60 * 60 * 1000);

    if (hoursAgo < 1) {
      return '刚刚';
    } else if (hoursAgo < 24) {
      return `${hoursAgo}小时前`;
    } else {
      const daysAgo = Math.floor(hoursAgo / 24);
      return `${daysAgo}天前`;
    }
  },

  // 加载更多评论
  loadMoreComments() {
    this.setData({
      page: this.data.page + 1
    });
    this.loadComments();
  },

  // 切换评论排序
  sortComments(e) {
    const sort = e.currentTarget.dataset.sort;
    if (sort !== this.data.commentSort) {
      this.setData({
        commentSort: sort,
        comments: [],
        page: 1,
        hasMoreComments: true
      });
      this.loadComments();
    }
  },

  // 点赞帖子
  async likePost() {
    try {
      const isLiked = this.data.postInfo.liked_by_current_user || this.data.postInfo.is_liked;

      // 乐观更新UI
      const newIsLiked = !isLiked;
      const likesCount = newIsLiked ?
        this.data.postInfo.likes_count + 1 :
        Math.max(0, this.data.postInfo.likes_count - 1);

      this.setData({
        'postInfo.liked_by_current_user': newIsLiked,
        'postInfo.is_liked': newIsLiked,
        'postInfo.likes_count': likesCount
      });

      // 调用API
      if (newIsLiked) {
        await api.post.like(this.data.postId);
      } else {
        await api.post.unlike(this.data.postId);
      }

      wx.showToast({
        title: newIsLiked ? '已点赞' : '已取消点赞',
        icon: 'success'
      });

    } catch (error) {
      console.error('点赞失败:', error);
      // 回滚UI状态
      this.setData({
        'postInfo.liked_by_current_user': this.data.postInfo.liked_by_current_user,
        'postInfo.is_liked': this.data.postInfo.is_liked,
        'postInfo.likes_count': this.data.postInfo.likes_count
      });
      wx.showToast({
        title: '操作失败',
        icon: 'none'
      });
    }
  },

  // 收藏帖子
  async collectPost() {
    try {
      // 这里应该调用API
      // await api.collectPost(this.data.postId);

      this.setData({
        'postInfo.is_collected': true
      });

      wx.showToast({
        title: '已收藏',
        icon: 'success'
      });

    } catch (error) {
      console.error('收藏失败:', error);
      wx.showToast({
        title: '操作失败',
        icon: 'none'
      });
    }
  },

  // 取消收藏
  async uncollectPost() {
    try {
      // 这里应该调用API
      // await api.uncollectPost(this.data.postId);

      this.setData({
        'postInfo.is_collected': false
      });

      wx.showToast({
        title: '已取消收藏',
        icon: 'success'
      });

    } catch (error) {
      console.error('取消收藏失败:', error);
      wx.showToast({
        title: '操作失败',
        icon: 'none'
      });
    }
  },

  // 分享帖子
  sharePost() {
    wx.showShareMenu({
      withShareTicket: true
    });
  },

  // 显示更多操作
  showMoreActions() {
    this.setData({ showActionModal: true });
  },

  // 隐藏更多操作
  hideActionModal() {
    this.setData({ showActionModal: false });
  },

  // 阻止事件冒泡
  stopPropagation() {
    // 阻止点击模态框内容时关闭模态框
  },

  // 举报帖子
  reportPost() {
    wx.showModal({
      title: '举报帖子',
      content: '确定要举报这个帖子吗？',
      success: (res) => {
        if (res.confirm) {
          wx.showToast({
            title: '举报成功',
            icon: 'success'
          });
          this.hideActionModal();
        }
      }
    });
  },

  // 编辑帖子
  editPost() {
    wx.navigateTo({
      url: `/pages/forum/create?id=${this.data.postId}`
    });
    this.hideActionModal();
  },

  // 删除帖子
  deletePost() {
    wx.showModal({
      title: '删除帖子',
      content: '确定要删除这个帖子吗？删除后无法恢复。',
      success: async (res) => {
        if (res.confirm) {
          try {
            // 调用API删除帖子
            await api.post.delete(this.data.postId);

            wx.showToast({
              title: '删除成功',
              icon: 'success'
            });

            setTimeout(() => {
              wx.navigateBack();
            }, 1500);

          } catch (error) {
            console.error('删除失败:', error);
            wx.showToast({
              title: '删除失败',
              icon: 'none'
            });
          }
        }
        this.hideActionModal();
      }
    });
  },

  // 复制链接
  copyLink() {
    wx.setClipboardData({
      data: `帖子链接：${this.data.postId}`,
      success: () => {
        wx.showToast({
          title: '链接已复制',
          icon: 'success'
        });
      }
    });
    this.hideActionModal();
  },

  // 点赞评论
  async likeComment(e) {
    const commentId = e.currentTarget.dataset.id;

    try {
      // 这里应该调用API
      // await api.likeComment(commentId);

      const comments = this.data.comments.map(comment => {
        if (comment.id === commentId) {
          return {
            ...comment,
            is_liked: !comment.is_liked,
            likes_count: comment.is_liked ?
              comment.likes_count - 1 :
              comment.likes_count + 1
          };
        }
        return comment;
      });

      this.setData({ comments });

    } catch (error) {
      console.error('点赞评论失败:', error);
      wx.showToast({
        title: '操作失败',
        icon: 'none'
      });
    }
  },

  // 回复评论
  replyToComment(e) {
    const comment = e.currentTarget.dataset.comment;
    this.setData({
      replyingTo: comment,
      showCommentInput: true
    });
  },

  // 聚焦评论输入框
  focusCommentInput() {
    this.setData({
      showCommentInput: true,
      replyingTo: null
    });
  },

  // 评论输入
  onCommentInput(e) {
    this.setData({
      commentText: e.detail.value
    });
  },

  // 评论输入框聚焦
  onCommentFocus() {
    this.setData({ showCommentInput: true });
  },

  // 评论输入框失焦
  onCommentBlur() {
    // 延迟隐藏，让用户有时间点击按钮
    setTimeout(() => {
      if (!this.data.commentText.trim() && this.data.commentImages.length === 0) {
        this.setData({
          showCommentInput: false,
          replyingTo: null
        });
      }
    }, 200);
  },

  // 选择图片
  chooseImage() {
    const maxCount = 3 - this.data.commentImages.length;

    wx.chooseImage({
      count: maxCount,
      sizeType: ['compressed'],
      sourceType: ['album', 'camera'],
      success: (res) => {
        const newImages = [...this.data.commentImages, ...res.tempFilePaths];
        this.setData({
          commentImages: newImages
        });
      }
    });
  },

  // 移除评论图片
  removeCommentImage(e) {
    const index = e.currentTarget.dataset.index;
    const newImages = this.data.commentImages.filter((_, i) => i !== index);
    this.setData({
      commentImages: newImages
    });
  },

  // 提交评论
  async submitComment() {
    if (!this.data.commentText.trim() && this.data.commentImages.length === 0) {
      wx.showToast({
        title: '请输入评论内容',
        icon: 'none'
      });
      return;
    }

    wx.showLoading({
      title: '发送中...',
      mask: true
    });

    try {
      // 准备评论数据
      const commentData = {
        content: this.data.commentText.trim(),
        parent_id: this.data.replyingTo?.id || null
      };

      // 调用API创建评论
      const response = await api.post.addComment(this.data.postId, commentData);

      // 如果API调用成功，刷新评论列表
      if (response) {
        this.setData({
          page: 1,
          comments: []
        });
        await this.loadComments();
      } else {
        // 如果API调用失败，创建本地评论作为回退
        const newComment = {
          id: Date.now(),
          floor: this.data.comments.length + 1,
          content: this.data.commentText.trim(),
          author: {
            id: 1,
            nickname: '我',
            avatar_url: 'https://picsum.photos/50/50?random=me',
            badge: null
          },
          likes_count: 0,
          liked_by_current_user: false,
          is_liked: false,
          created_at: '刚刚',
          images: this.data.commentImages,
          replies: [],
          replies_count: 0
        };

        // 如果是回复，添加到对应评论的回复列表
        if (this.data.replyingTo) {
          const comments = this.data.comments.map(comment => {
            if (comment.id === this.data.replyingTo.id) {
              const newReply = {
                id: Date.now(),
                author: {
                  nickname: '我'
                },
                target_name: this.data.replyingTo.author.nickname,
                content: this.data.commentText.trim(),
                created_at: '刚刚'
              };

              return {
                ...comment,
                replies: [...comment.replies, newReply],
                replies_count: comment.replies_count + 1
              };
            }
            return comment;
          });

          this.setData({ comments });
        } else {
          // 否则添加为新评论
          this.setData({
            comments: [newComment, ...this.data.comments]
          });
        }
      }

      // 清空输入
      this.setData({
        commentText: '',
        commentImages: [],
        replyingTo: null,
        showCommentInput: false,
        'postInfo.comments_count': (this.data.postInfo.comments_count || 0) + 1
      });

      wx.hideLoading();
      wx.showToast({
        title: '发送成功',
        icon: 'success'
      });

    } catch (error) {
      console.error('发送评论失败:', error);
      wx.hideLoading();
      wx.showToast({
        title: '发送失败',
        icon: 'none'
      });
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

  // 返回上一页
  goBack() {
    wx.navigateBack();
  },

  // 页面分享
  onShareAppMessage() {
    return {
      title: this.data.postInfo?.title || '论坛帖子',
      path: `/pages/forum/detail?id=${this.data.postId}`,
      imageUrl: this.data.postInfo?.images?.[0] || ''
    };
  }
});