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
    post "auth/login", to: "auth#login"
    get "auth/me", to: "auth#me"
    put "auth/profile", to: "auth#update_profile"

    # 论坛路由
    resources :posts, only: [:index, :show, :create, :update, :destroy] do
      member do
        post :pin
        post :unpin
        post :hide
        post :unhide
      end
    end

    # 活动路由
    resources :events do
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
