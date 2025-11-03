Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # API routes
  namespace :api do
    # API健康检查
    get "health", to: "application#health", as: :health

    # 认证路由
    post "auth/mock_login", to: "auth#mock_login"
    post "auth/wechat_login", to: "auth#wechat_login"
    post "auth/login", to: "auth#login"
    post "auth/refresh_token", to: "auth#refresh_token"
    get "auth/me", to: "auth#me"
    put "auth/profile", to: "auth#update_profile"

    # 论坛路由
    resources :posts, only: [:index, :show, :create, :update, :destroy] do
      member do
        post :pin
        post :unpin
        post :hide
        post :unhide
        post :like
        delete :like
      end
      resources :comments, only: [:index, :create]
    end

    # 评论路由（独立路由用于更新和删除）
    resources :comments, only: [:update, :destroy]

    # 图片上传路由
    post 'upload/image', to: 'uploads#create'

    # API版本控制
    namespace :v1 do
      # 性能优化路由
      resources :performance_posts, only: [:index, :show, :create] do
        collection do
          get :stats
        end
      end

      # 审批工作流路由
      namespace :approval_workflow do
        post :submit_for_approval
        post :approve_event
        post :reject_event
        post :batch_approve
        post :batch_reject
        get :approval_queue
        get :approval_statistics
        post :escalate_approval
        get :event_approval_status
      end

      # 共读活动路由
      resources :reading_events do
        member do
          post :start          # 开始活动
          post :complete       # 完成活动
          post :approve        # 审批通过（管理员）
          post :reject         # 审批拒绝（管理员）
          post :observe        # 围观活动
          get :statistics      # 活动统计
          get :today_task      # 今日任务
        end

        # 阅读计划路由（嵌套在活动下）
        resources :reading_schedules, only: [:index, :show] do
          member do
            post :assign_leader  # 分配领读人
            post :remove_leader  # 移除领读人
          end

          # 领读内容路由（单数资源）
          resource :daily_leading, only: [:create, :show, :update, :destroy]
        end

        # 领读人分配路由
        resources :leader_assignments, only: [] do
          collection do
            post :auto_assign       # 自动分配领读人
            get :statistics        # 分配统计
            get :backup_needed     # 需要补位的日程
            get :permissions       # 检查领读权限
          end

          member do
            post :claim             # 自由报名领读
            post :reassign           # 重新分配领读人
            post :backup            # 补位分配
          end
        end
      end

      # 活动报名路由
      resources :event_enrollments, only: [:create, :show, :update, :destroy] do
        member do
          post :cancel         # 取消报名
        end
        collection do
          get :my_progress     # 获取我的进度
        end
      end

      # 活动报名路由
      resources :reading_events, only: [] do
        resources :enrollments, controller: 'event_enrollments', only: [:index] do
          collection do
            get :statistics    # 报名统计
          end
        end
      end

      # 阅读计划路由
      resources :reading_schedules, only: [:index, :show] do
        member do
          post :assign_leader  # 分配领读人
          post :remove_leader  # 移除领读人
        end

        # 打卡路由
        resources :check_ins, only: [:create, :index, :show, :update]

        # 领读内容路由（单数资源）
        resource :daily_leading, only: [:create, :show, :update]

        # 小红花路由
        resources :flowers, only: [:index, :create, :show] do
          # 小红花评论路由
          resources :comments, controller: 'flower_comments', only: [:index, :create, :show, :destroy] do
            collection do
              get :search          # 搜索评论
              get :stats           # 评论统计
              delete :batch        # 批量删除评论
            end
          end
        end
      end

      # 打卡详情路由
      resources :check_ins, only: [:show, :update, :destroy] do
        # 给打卡送小红花
        resources :flowers, only: [:create], controller: 'check_in_flowers'
        # 打卡评论
        resources :comments, only: [:index, :create], controller: 'check_in_comments'
      end

      # 用户路由
      resources :users, only: [:show] do
        member do
          get :enrollments    # 用户的报名记录
          get :certificates   # 用户的证书
          get :statistics     # 用户统计信息
        end
      end

      # 证书路由
      resources :certificates, only: [:show] do
        member do
          get :verify         # 验证证书
          post :share         # 分享证书
        end
      end

      # 通知路由
      resources :notifications, only: [:index, :show, :update, :destroy] do
        collection do
          post :mark_all_read    # 批量标记为已读
          delete :batch          # 批量删除
          get :unread_count      # 获取未读数量
          get :stats             # 获取统计信息
          get :recent            # 获取最近通知
          get :check_new         # 检查新通知
          post :test             # 测试通知（开发环境）
        end
      end

      # 内容搜索路由
      resources :content_search, only: [:index] do
        collection do
          get :advanced        # 高级搜索
          get :suggestions     # 搜索建议
          get :popular_keywords # 热门关键词
          get :trends          # 搜索趋势
          get :facets          # 搜索统计
          post :save_search    # 保存搜索
          get :history         # 搜索历史
        end

        member do
          get :related         # 相关内容推荐
        end
      end

      # 内容导出路由
      resources :content_export, only: [] do
        collection do
          get :statistics      # 导出统计
          get :preview         # 导出预览
          get :export          # 执行导出
          post :batch_export   # 批量导出
          get :templates       # 导出模板
          post :save_template  # 保存模板
          get :history         # 导出历史
          post :schedule       # 定时导出
        end
      end

      # 内容举报路由
      resources :content_reports, only: [:create, :index, :show, :update] do
        collection do
          post :batch_process  # 批量处理
          get :statistics      # 举报统计
          get :pending         # 待处理举报
          get :high_priority   # 高优先级举报
          get :export          # 导出举报数据
          get :my_reports      # 我的举报历史
        end
      end

      # 小红花排行榜路由
      resources :flower_leaderboards, only: [:index] do
        collection do
          get :trends         # 获取小红花趋势数据
          get :statistics     # 获取小红花统计
          get :suggestions    # 获取小红花发放建议
          get :my_ranking     # 获取当前用户的排名
        end
      end

      # 小红花激励机制路由
      resources :reading_events, only: [] do
        resources :flower_incentives, only: [] do
          collection do
            get :quota_info               # 获取配额信息
            post :give_flower             # 赠送小红花
            get :top_three               # 获取前三名排行榜
            get :my_certificates         # 获取我的证书
            get :certificate_detail      # 获取证书详情
            post :finalize_certificates   # 生成活动证书（管理员）
            post :initialize_quotas      # 初始化配额（管理员）
          end
        end
      end

      # 统计分析路由
      resources :analytics, only: [] do
        collection do
          get :overview                    # 系统总览（管理员）
          get :dashboard                   # 用户仪表板
          get :summary                     # 简化统计摘要
          get :trends                      # 趋势数据
          get :leaderboards                # 排行榜
          get :reports                     # 生成报告（管理员）
          get :export                      # 导出数据（管理员）
        end

        member do
          get :user_stats                  # 用户详细统计
          get :event_stats                 # 活动详细统计
        end
      end
    end

    # 保持向后兼容的旧路由
    resources :events, controller: 'v1/reading_events' do
      member do
        post :enroll
        post :approve
        post :reject
        post :claim_leadership
        post :complete
        get :backup_needed
      end
    end

    # 阅读计划路由
    resources :reading_schedules, only: [] do
      # 打卡路由
      resources :check_ins, only: [:create, :index]
      # 领读内容路由（单数资源）
      resource :daily_leading, only: [:create, :show, :update]
      # 小红花列表（某天的所有小红花）
      resources :flowers, only: [:index]
    end

    # 打卡详情路由
    resources :check_ins, only: [:show, :update] do
      # 给打卡送小红花
      resource :flower, only: [:create]
      # 打卡评论
      resources :comments, only: [:index, :create], controller: 'check_in_comments'
    end

    # 用户收到的小红花
    get "users/:user_id/flowers", to: "flowers#user_flowers"

    # 管理员路由
    namespace :admin do
      get "dashboard", to: "admin#dashboard"
      get "users", to: "admin#users"
      get "events/pending", to: "admin#pending_events"
      put "users/:id/promote_admin", to: "admin#promote_user_to_admin"
      put "users/:id/demote", to: "admin#demote_user"
      post "init_root", to: "admin#init_root_user"
    end
  end

  # Defines the root path route ("/")
  # root "posts#index"
end
