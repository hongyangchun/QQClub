// pages/forum/create.js
const api = require('../../utils/api')

Page({
  data: {
    userInfo: null,
    postId: null, // 编辑帖子时的ID
    selectedCategory: '',
    title: '',
    content: '',
    images: [],
    showImagePreview: false,
    previewImageUrl: '',
    isEditing: false
  },

  onLoad(options) {
    this.getUserInfo();

    // 如果有ID，说明是编辑模式
    if (options.id) {
      this.setData({
        postId: options.id,
        isEditing: true
      });
      this.loadPostData(options.id);
    }
  },

  // 获取用户信息
  getUserInfo() {
    const userInfo = wx.getStorageSync('userInfo');
    if (userInfo) {
      this.setData({ userInfo });
    } else {
      wx.showModal({
        title: '提示',
        content: '请先登录后再发帖',
        confirmText: '去登录',
        success: (res) => {
          if (res.confirm) {
            wx.navigateTo({
              url: '/pages/auth/auth'
            });
          } else {
            wx.navigateBack();
          }
        }
      });
    }
  },

  // 加载帖子数据（编辑模式）
  async loadPostData(postId) {
    try {
      // 调用API获取帖子数据
      const response = await api.post.getDetail(postId);

      if (response) {
        // 检查当前用户是否有编辑权限
        const userInfo = wx.getStorageSync('userInfo');
        const isAuthor = userInfo && userInfo.id === (response.author?.id || response.author_info?.id || response.user_id);

        if (!isAuthor) {
          wx.showToast({
            title: '无权限编辑此帖子',
            icon: 'none'
          });
          setTimeout(() => {
            wx.navigateBack();
          }, 1500);
          return;
        }

        this.setData({
          title: response.title || '',
          content: response.content || '',
          selectedCategory: response.category || '',
          images: response.images || []
        });
      } else {
        throw new Error('帖子不存在');
      }

    } catch (error) {
      console.error('加载帖子数据失败:', error);

      // 检查是否是权限错误
      if (error.message && error.message.includes('权限')) {
        wx.showToast({
          title: '无权限编辑此帖子',
          icon: 'none'
        });
      } else if (error.message && error.message.includes('未找到')) {
        wx.showToast({
          title: '帖子不存在或已被删除',
          icon: 'none'
        });
      } else {
        wx.showToast({
          title: '加载失败，请重试',
          icon: 'none'
        });
      }

      setTimeout(() => {
        wx.navigateBack();
      }, 1500);
    }
  },

  // 返回上一页
  goBack() {
    if (this.hasUnsavedChanges()) {
      wx.showModal({
        title: '确认离开',
        content: '您有未保存的内容，确定要离开吗？',
        success: (res) => {
          if (res.confirm) {
            wx.navigateBack();
          }
        }
      });
    } else {
      wx.navigateBack();
    }
  },

  // 检查是否有未保存的更改
  hasUnsavedChanges() {
    return this.data.title || this.data.content || this.data.images.length > 0;
  },

  // 选择板块
  selectCategory(e) {
    const category = e.currentTarget.dataset.category;
    this.setData({
      selectedCategory: category
    });
  },

  // 标题输入
  onTitleInput(e) {
    this.setData({
      title: e.detail.value
    });
  },

  // 内容输入
  onContentInput(e) {
    this.setData({
      content: e.detail.value
    });
  },

  // 选择图片
  async chooseImage() {
    const maxCount = 9 - this.data.images.length;

    if (maxCount <= 0) {
      wx.showToast({
        title: '最多上传9张图片',
        icon: 'none'
      });
      return;
    }

    try {
      const res = await new Promise((resolve, reject) => {
        wx.chooseImage({
          count: maxCount,
          sizeType: ['compressed'],
          sourceType: ['album', 'camera'],
          success: resolve,
          fail: reject
        });
      });

      wx.showLoading({
        title: '上传中...',
        mask: true
      });

      const uploadPromises = res.tempFilePaths.map(filePath => this.uploadImage(filePath));
      const uploadedImages = await Promise.all(uploadPromises);

      // 过滤掉上传失败的图片
      const validImages = uploadedImages.filter(img => img !== null);

      const newImages = [...this.data.images, ...validImages];
      this.setData({
        images: newImages
      });

      if (validImages.length > 0) {
        wx.showToast({
          title: `成功上传${validImages.length}张图片`,
          icon: 'success'
        });
      }

    } catch (error) {
      console.error('选择图片失败:', error);
      wx.showToast({
        title: '选择图片失败',
        icon: 'none'
      });
    } finally {
      wx.hideLoading();
    }
  },

  // 上传单张图片
  async uploadImage(filePath) {
    try {
      const response = await api.upload.image(filePath);
      if (response && response.url) {
        return response.url;
      }
      return null;
    } catch (error) {
      console.error('上传图片失败:', error);
      return null;
    }
  },

  // 预览图片
  previewImage(e) {
    const index = e.currentTarget.dataset.index;
    wx.previewImage({
      current: this.data.images[index],
      urls: this.data.images
    });
  },

  // 删除图片
  deleteImage(e) {
    const index = e.currentTarget.dataset.index;
    const newImages = this.data.images.filter((_, i) => i !== index);
    this.setData({
      images: newImages
    });
  },

  
  
  // 验证表单
  validateForm() {
    if (!this.data.selectedCategory) {
      wx.showToast({
        title: '请选择板块',
        icon: 'none'
      });
      return false;
    }

    if (!this.data.title.trim()) {
      wx.showToast({
        title: '请输入帖子标题',
        icon: 'none'
      });
      return false;
    }

    if (this.data.title.trim().length < 5) {
      wx.showToast({
        title: '标题至少5个字符',
        icon: 'none'
      });
      return false;
    }

    if (!this.data.content.trim()) {
      wx.showToast({
        title: '请输入帖子内容',
        icon: 'none'
      });
      return false;
    }

    if (this.data.content.trim().length < 10) {
      wx.showToast({
        title: '内容至少10个字符',
        icon: 'none'
      });
      return false;
    }

    return true;
  },

  // 发布帖子
  async publishPost() {
    if (!this.validateForm()) {
      return;
    }

    // 检查登录状态
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

    wx.showLoading({
      title: this.data.isEditing ? '保存中...' : '发布中...',
      mask: true
    });

    try {
      const postData = {
        post: {
          category: this.data.selectedCategory,
          title: this.data.title.trim(),
          content: this.data.content.trim(),
          images: this.data.images
        }
      };

      let response;
      if (this.data.isEditing) {
        // 编辑帖子
        response = await api.post.update(this.data.postId, postData.post);
        wx.showToast({
          title: '保存成功',
          icon: 'success'
        });
      } else {
        // 发布新帖子
        response = await api.post.create(postData.post);
        wx.showToast({
          title: '发布成功',
          icon: 'success'
        });
      }

      // 清空表单
      if (!this.data.isEditing) {
        this.setData({
          title: '',
          content: '',
          images: []
        });
      }

      // 延迟跳转，让用户看到成功提示
      setTimeout(() => {
        if (this.data.isEditing) {
          wx.navigateBack();
        } else {
          wx.switchTab({
            url: '/pages/forum/list'
          });
        }
      }, 1500);

    } catch (error) {
      console.error('发布帖子失败:', error);

      // 检查是否是认证错误
      if (error.message && error.message.includes('未授权')) {
        wx.showModal({
          title: '登录已过期',
          content: '您的登录已过期，请重新登录后继续',
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
        title: this.data.isEditing ? '保存失败' : '发布失败',
        icon: 'none'
      });
    } finally {
      wx.hideLoading();
    }
  },

  // 显示图片预览
  showImagePreview(e) {
    const url = e.currentTarget.dataset.url;
    this.setData({
      showImagePreview: true,
      previewImageUrl: url
    });
  },

  // 隐藏图片预览
  hideImagePreview() {
    this.setData({
      showImagePreview: false,
      previewImageUrl: ''
    });
  },

  // 阻止事件冒泡
  stopPropagation() {
    // 阻止点击预览图片时关闭弹窗
  }
});