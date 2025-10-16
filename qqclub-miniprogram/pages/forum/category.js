// pages/forum/category.js
Page({
  data: {
    categories: []
  },

  onLoad() {
    this.loadCategories();
  },

  // 加载分类数据
  loadCategories() {
    // 模拟分类数据
    const categories = [
      {
        id: 'reading',
        name: '读书心得',
        description: '分享读书感悟、好书推荐、阅读心得',
        icon: '📚',
        posts_count: 156,
        today_posts: 12
      },
      {
        id: 'activity',
        name: '活动讨论',
        description: '共读活动相关讨论、经验分享',
        icon: '📖',
        posts_count: 89,
        today_posts: 5
      },
      {
        id: 'chat',
        name: '闲聊区',
        description: '轻松愉快的日常交流、生活分享',
        icon: '☕',
        posts_count: 234,
        today_posts: 18
      },
      {
        id: 'help',
        name: '求助问答',
        description: '问题求助、经验交流、知识分享',
        icon: '❓',
        posts_count: 67,
        today_posts: 8
      }
    ];

    this.setData({ categories });
  },

  // 选择分类
  selectCategory(e) {
    const category = e.currentTarget.dataset.category;

    wx.navigateTo({
      url: `/pages/forum/list?category=${category.id}`
    });
  },

  // 返回上一页
  goBack() {
    wx.navigateBack();
  }
});