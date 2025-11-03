// components/custom-tabbar/custom-tabbar.js
Component({
  /**
   * 组件的属性列表
   */
  properties: {
    current: {
      type: Number,
      value: 0
    }
  },

  /**
   * 组件的初始数据
   */
  data: {
    tabs: [
      {
        pagePath: "/pages/index/index",
        text: "首页",
        icon: "🏠",
        selectedIcon: "🏠"
      },
      {
        pagePath: "/pages/event/list",
        text: "共读",
        icon: "📚",
        selectedIcon: "📖"
      },
      {
        pagePath: "/pages/forum/list",
        text: "交流",
        icon: "💬",
        selectedIcon: "💭"
      },
      {
        pagePath: "/pages/profile/profile",
        text: "我的",
        icon: "👤",
        selectedIcon: "👤"
      }
    ]
  },

  /**
   * 组件的方法列表
   */
  methods: {
    // 切换tab
    switchTab(e) {
      const index = e.currentTarget.dataset.index;
      const tab = this.data.tabs[index];

      if (index === this.data.current) {
        return; // 如果是当前页面，不做处理
      }

      // 使用switchTab切换页面（因为app.json中配置了custom tabBar）
      wx.switchTab({
        url: tab.pagePath,
        success: () => {
          // 通知父组件更新当前选中状态
          this.triggerEvent('change', { current: index });
        },
        fail: (err) => {
          console.error('切换页面失败:', err);
          // 如果switchTab失败，尝试使用redirectTo
          wx.redirectTo({
            url: tab.pagePath
          });
        }
      });
    }
  }
});