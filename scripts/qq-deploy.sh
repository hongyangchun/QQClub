#!/bin/bash

# QQClub Deploy Script - 项目每日部署工具
# 版本: 2.0.0 - 每日工作完结版
# 作者: Claude Code Assistant
# 描述: 完美每日工作收尾工具，包含环境检查、测试、文档更新、健康检查和Git操作

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

log_debug() {
    if [[ "$DEBUG" == "true" ]]; then
        echo -e "${CYAN}[DEBUG]${NC} $1"
    fi
}

# 进度指示函数
show_progress() {
    local step_description="$1"
    STEP_COUNT=$((STEP_COUNT + 1))

    local progress=$((STEP_COUNT * 100 / TOTAL_STEPS))
    local bar_length=30
    local filled_length=$((progress * bar_length / 100))

    local bar=""
    for ((i=0; i<filled_length; i++)); do
        bar="${bar}█"
    done
    for ((i=filled_length; i<bar_length; i++)); do
        bar="${bar}░"
    done

    echo
    echo -e "${BLUE}[进度]${NC} [$STEP_COUNT/$TOTAL_STEPS] $bar ${progress}%"
    echo -e "${BLUE}[进度]${NC} 当前步骤: $step_description"
    echo
}

# 错误处理函数
handle_error() {
    local exit_code=$1
    local error_message="$2"

    DEPLOYMENT_SUCCESS=false

    echo
    log_error "❌ 部署失败!"
    log_error "错误信息: $error_message"
    log_error "退出代码: $exit_code"

    # 计算执行时间
    if [[ -n "$DEPLOYMENT_START_TIME" ]]; then
        local end_time=$(date +%s)
        local duration=$((end_time - DEPLOYMENT_START_TIME))
        log_error "执行时间: ${duration}秒"
    fi

    echo
    log_info "🔧 故障排除建议:"
    log_info "  1. 检查网络连接"
    log_info "  2. 确认Git远程仓库权限"
    log_info "  3. 检查依赖是否完整安装"
    log_info "  4. 查看详细错误信息"
    log_info "  5. 尝试使用 --dry-run 参数调试"
    echo

    exit $exit_code
}

# 成功完成函数
celebrate_success() {
    local end_time=$(date +%s)
    local duration=$((end_time - DEPLOYMENT_START_TIME))

    echo
    echo -e "${GREEN}🎉🎉🎉 部署成功完成! 🎉🎉🎉${NC}"
    echo -e "${GREEN}⏱️  总用时: ${duration}秒${NC}"
    echo -e "${GREEN}📊 完成步骤: $STEP_COUNT/$TOTAL_STEPS${NC}"
    echo
    echo -e "${YELLOW}🌟 优秀的工作! 现在可以休息一下了 🌟${NC}"
    echo

    # 如果是工作时间，给出适当建议
    local current_hour=$(date +%H)
    if [[ $current_hour -ge 18 ]]; then
        echo -e "${CYAN}🌆 晚上好! 今天的辛勤工作值得好好休息${NC}"
    elif [[ $current_hour -ge 12 ]]; then
        echo -e "${CYAN}☀️ 下午好! 记得适当休息，保持工作节奏${NC}"
    else
        echo -e "${CYAN}🌅 上午好! 精力充沛地开始新的一天${NC}"
    fi
    echo
}

# 默认配置
DEFAULT_CONFIG="
# QQClub Deploy 配置文件
auto_commit: true
auto_push: true
auto_github: false
auto_tag: false
run_tests: true
test_timeout: 300
update_docs: true
update_api_docs: true
enable_notifications: false
webhook_url: \"\"
create_backup: false
backup_path: \"./backups\"
"

# 全局变量
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$PROJECT_ROOT/.qq-deploy.yml"
DRY_RUN=false
FORCE=false
SKIP_TESTS=false
SKIP_DOCS=false
AUTO_GITHUB=false
CUSTOM_MESSAGE=""
FEATURE_NAME=""
IS_RELEASE=false
IS_HOTFIX=false
VERSION=""

# 进度指示
STEP_COUNT=0
TOTAL_STEPS=8
DEPLOYMENT_START_TIME=""
DEPLOYMENT_SUCCESS=true

# 显示帮助信息
show_help() {
    cat << EOF
QQClub Deploy - 项目部署和发布工具

用法: $0 [选项]

选项:
  --dry-run              模拟执行，不实际提交
  --force                强制提交，跳过某些检查
  --skip-tests           跳过测试执行
  --skip-docs            跳过文档更新
  --auto-github          自动创建和配置GitHub仓库
  --check-github         检查GitHub集成状态
  --message <text>       自定义 commit 消息
  --feature <name>       标记功能名称
  --release              标记为发布版本
  --hotfix               标记为紧急修复
  --version <version>    指定版本号
  --debug                显示调试信息
  --help                 显示此帮助信息

示例:
  $0                     # 标准部署
  $0 --dry-run          # 模拟执行
  $0 --auto-github      # 自动配置GitHub仓库并推送
  $0 --check-github     # 检查GitHub集成状态
  $0 --feature="论坛系统" # 功能发布
  $0 --release --version="v1.2.0" # 版本发布
  $0 --hotfix --message="修复权限越界问题" # 紧急修复

EOF
}

# 显示GitHub设置状态
show_github_status() {
    log_step "检查GitHub集成状态..."

    echo
    log_info "🔍 GitHub CLI 检查:"
    if command -v gh &> /dev/null; then
        log_success "  ✅ GitHub CLI 已安装"
        if gh auth status &> /dev/null; then
            local github_user=$(gh api user --jq '.login' 2>/dev/null || echo "未知")
            log_success "  ✅ GitHub CLI 已认证 (用户: $github_user)"
        else
            log_warning "  ⚠️  GitHub CLI 未认证 - 请运行: gh auth login"
        fi
    else
        log_warning "  ❌ GitHub CLI 未安装 - 请访问: https://cli.github.com/manual/installation"
    fi

    echo
    log_info "🔍 Git 远程仓库检查:"
    if git remote get-url origin > /dev/null 2>&1; then
        local remote_url=$(git remote get-url origin)
        log_success "  ✅ 远程仓库已配置: $remote_url"

        if [[ "$remote_url" == *"github.com"* ]]; then
            log_success "  ✅ GitHub 仓库连接正常"
        else
            log_warning "  ⚠️  非 GitHub 仓库"
        fi
    else
        log_warning "  ❌ 未配置远程仓库"
        log_info "    💡 提示: 使用 --auto-github 参数自动创建 GitHub 仓库"
    fi

    echo
    log_info "🔍 推送权限检查:"
    if git remote get-url origin > /dev/null 2>&1; then
        local current_branch=$(git branch --show-current)
        if git ls-remote --exit-code origin "$current_branch" &> /dev/null; then
            log_success "  ✅ 有推送权限"
        else
            log_warning "  ⚠️  推送权限未知，首次推送时需要认证"
        fi
    else
        log_warning "  ❌ 无法检查推送权限"
    fi
}

# 解析命令行参数
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --force)
                FORCE=true
                shift
                ;;
            --skip-tests)
                SKIP_TESTS=true
                shift
                ;;
            --skip-docs)
                SKIP_DOCS=true
                shift
                ;;
            --auto-github)
                AUTO_GITHUB=true
                shift
                ;;
            --check-github)
                show_github_status
                exit 0
                ;;
            --message)
                CUSTOM_MESSAGE="$2"
                shift 2
                ;;
            --feature)
                FEATURE_NAME="$2"
                shift 2
                ;;
            --release)
                IS_RELEASE=true
                shift
                ;;
            --hotfix)
                IS_HOTFIX=true
                shift
                ;;
            --version)
                VERSION="$2"
                shift 2
                ;;
            --debug)
                DEBUG=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                log_error "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# 创建默认配置文件
create_default_config() {
    log_info "创建默认配置文件: $CONFIG_FILE"
    echo "$DEFAULT_CONFIG" > "$CONFIG_FILE"
    log_success "配置文件已创建"
}

# 读取配置文件
load_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_warning "配置文件不存在，创建默认配置"
        create_default_config
    fi

    # 简单的YAML解析（仅支持基本格式）
    if [[ -f "$CONFIG_FILE" ]]; then
        log_debug "加载配置文件: $CONFIG_FILE"
        # 这里可以添加更复杂的YAML解析逻辑
        # 目前使用环境变量作为配置的回退
    fi
}

# 检查Git仓库状态
check_git_status() {
    log_step "检查Git仓库状态..."

    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        log_error "当前目录不是Git仓库"
        exit 1
    fi

    # 检查是否有未提交的变更
    if [[ -n $(git status --porcelain) ]]; then
        log_info "发现未提交的变更:"
        git status --short
        return 0
    else
        log_warning "没有发现需要提交的变更"
        return 1
    fi
}

# 检查和配置GitHub仓库
setup_github_repository() {
    log_step "检查GitHub仓库配置..."

    # 检查GitHub CLI安装和认证
    if ! command -v gh &> /dev/null; then
        log_error "GitHub CLI未安装，请先安装: https://cli.github.com/manual/installation"
        exit 1
    fi

    if ! gh auth status &> /dev/null; then
        log_error "GitHub CLI未认证，请先运行: gh auth login"
        exit 1
    fi

    log_success "GitHub CLI: 已认证 (用户: $(gh api user --jq '.login')"

    # 检查是否已有远程仓库
    if git remote get-url origin > /dev/null 2>&1; then
        local remote_url=$(git remote get-url origin)
        log_info "已有远程仓库: $remote_url"

        # 检查是否是GitHub仓库
        if [[ "$remote_url" == *"github.com"* ]]; then
            log_success "GitHub仓库配置正常"
        else
            log_warning "远程仓库不是GitHub，可以继续使用现有配置"
        fi
        return 0
    fi

    # 尝试自动创建GitHub仓库
    log_info "未检测到远程仓库，尝试创建GitHub仓库..."

    local repo_name="QQClub"
    local repo_description="QQClub 读书社群 - 基于Rails 8的现代化读书社群平台"
    local visibility="public"

    # 检查用户是否有权限创建仓库
    log_info "检查GitHub权限..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] 将创建GitHub仓库: $repo_name"
        log_info "  私有仓库: $visibility"
        log_info "  描述: $repo_description"
        return 0
    fi

    # 尝试创建GitHub仓库
    log_info "创建GitHub仓库..."
    if gh repo create "$repo_name" \
        --description "$repo_description" \
        --"$visibility" \
        --source=local; then
        log_success "GitHub仓库创建成功: $repo_name"

        # 添加远程仓库
        git remote add origin "git@github.com:$(gh api user --jq '.login')/$repo_name.git"
        log_success "已添加远程仓库origin"

        # 推送到远程仓库
        log_info "推送初始代码到GitHub..."
        git push -u origin main
        log_success "初始代码已推送到GitHub"
    else
        log_error "GitHub仓库创建失败"
        log_info "请手动创建GitHub仓库，然后配置远程仓库"
        log_info "使用命令: git remote add origin <your-repo-url>"
        log_info "然后使用命令: git push -u origin main"
        return 1
    fi
}

# 检查当前分支
check_current_branch() {
    log_step "检查当前分支..."

    local current_branch=$(git branch --show-current)
    log_info "当前分支: $current_branch"

    # 检查是否在主分支上
    if [[ "$current_branch" == "main" || "$current_branch" == "master" ]]; then
        if [[ "$FORCE" != "true" ]]; then
            log_warning "您正在主分支 ($current_branch) 上"
            if [[ "$DRY_RUN" == "true" ]]; then
                log_info "[DRY-RUN] 在主分支上继续执行"
            else
                read -p "是否继续? (y/N): " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    log_info "操作已取消"
                    exit 0
                fi
            fi
        fi
    fi

    # 检查远程连接
    if git remote get-url origin > /dev/null 2>&1; then
        log_info "远程仓库: $(git remote get-url origin)"
    else
        log_warning "没有配置远程仓库"
        if [[ "$AUTO_GITHUB" == "true" ]]; then
            log_info "自动GitHub模式已启用，将创建GitHub仓库"
        else
            log_info "可以使用 --auto-github 参数自动创建GitHub仓库"
        fi
    fi
}

# 评估项目状态
assess_project_status() {
    log_step "评估项目状态..."

    # 统计文件变更
    local modified_files=$(git status --porcelain | grep '^ M' | wc -l)
    local added_files=$(git status --porcelain | grep '^ A' | wc -l)
    local deleted_files=$(git status --porcelain | grep '^ D' | wc -l)
    local renamed_files=$(git status --porcelain | grep '^ R' | wc -l)

    log_info "文件变更统计:"
    log_info "  - 修改: $modified_files 个文件"
    log_info "  - 新增: $added_files 个文件"
    log_info "  - 删除: $deleted_files 个文件"
    log_info "  - 重命名: $renamed_files 个文件"

    # 分析变更类型
    local has_code_changes=false
    local has_doc_changes=false
    local has_test_changes=false

    while IFS= read -r line; do
        if [[ "$line" =~ \.(rb|js|ts|jsx|tsx|vue|css|scss|sass)$ ]]; then
            has_code_changes=true
        elif [[ "$line" =~ \.(md|txt|json|yml|yaml)$ ]]; then
            has_doc_changes=true
        elif [[ "$line" =~ test_?*\.|_test\.|spec\. ]]; then
            has_test_changes=true
        fi
    done < <(git status --porcelain | awk '{print $2}')

    log_info "变更类型分析:"
    [[ "$has_code_changes" == "true" ]] && log_info "  - 包含代码变更"
    [[ "$has_doc_changes" == "true" ]] && log_info "  - 包含文档变更"
    [[ "$has_test_changes" == "true" ]] && log_info "  - 包含测试变更"
}

# 生成每日工作总结
generate_daily_summary() {
    log_step "生成每日工作总结..."

    local date_str=$(date +'%Y-%m-%d')
    local day_of_week=$(date +'%A')
    local current_time=$(date +'%H:%M:%S')

    # 分析今日提交
    local today_commits=0
    local today_files_changed=0

    if command -v git &> /dev/null; then
        today_commits=$(git log --since="today 00:00:00" --until="today 23:59:59" --oneline | wc -l)
        today_files_changed=$(git diff --stat HEAD~$today_commits HEAD 2>/dev/null | tail -1 | grep -o '[0-9]\+' | head -1 || echo "0")
    fi

    log_info "📅 今日工作总结 ($day_of_week $date_str $current_time)"
    log_info "  - 提交次数: $today_commits 次"
    log_info "  - 变更文件: $today_files_changed 个"

    # 分析工作类型
    local has_new_features=false
    local has_bug_fixes=false
    local has_optimizations=false
    local has_docs=false

    # 检查最近的commit消息类型
    if [[ $today_commits -gt 0 ]]; then
        local recent_commits=$(git log --since="today 00:00:00" --until="today 23:59:59" --oneline)
        [[ "$recent_commits" =~ (新增|功能|feature|add|create) ]] && has_new_features=true
        [[ "$recent_commits" =~ (修复|fix|bug) ]] && has_bug_fixes=true
        [[ "$recent_commits" =~ (优化|optimize|improve|refactor) ]] && has_optimizations=true
        [[ "$recent_commits" =~ (文档|docs|readme) ]] && has_docs=true
    fi

    log_info "🏗️  工作类型分析:"
    [[ "$has_new_features" == "true" ]] && log_info "  ✅ 新功能开发"
    [[ "$has_bug_fixes" == "true" ]] && log_info "  🐛 Bug修复"
    [[ "$has_optimizations" == "true" ]] && log_info "  ⚡ 性能优化"
    [[ "$has_docs" == "true" ]] && log_info "  📚 文档更新"

    if [[ "$today_commits" -eq 0 ]]; then
        log_info "  💡 今天还没有代码提交，继续保持节奏！"
    fi
}

# 运行健康检查
run_health_checks() {
    log_step "运行系统健康检查..."

    # 1. 检查API服务器状态
    if pgrep -f "rails.*server" > /dev/null; then
        log_success "✅ Rails服务器运行正常"
    else
        log_warning "⚠️  Rails服务器未运行"
        log_info "   启动建议: bundle exec rails server"
    fi

    # 2. 检查数据库连接
    if [[ -f "config/database.yml" ]]; then
        if bundle exec rails runner "ActiveRecord::Base.connection.execute('SELECT 1')" 2>/dev/null; then
            log_success "✅ 数据库连接正常"
        else
            log_warning "⚠️  数据库连接异常"
            log_info "   检查建议: bundle exec rails db:migrate"
        fi
    fi

    # 3. 检查Redis（如果配置）
    if command -v redis-cli &> /dev/null; then
        if redis-cli ping 2>/dev/null | grep -q "PONG"; then
            log_success "✅ Redis服务正常"
        else
            log_warning "⚠️  Redis服务未运行"
        fi
    fi

    # 4. 检查Git状态
    if git status --porcelain | grep -q "^M"; then
        log_warning "⚠️  存在未提交的变更"
        local uncommitted_count=$(git status --porcelain | grep "^M" | wc -l)
        log_info "   未提交文件: $uncommitted_count 个"
    else
        log_success "✅ 工作区干净，无未提交变更"
    fi

    # 5. 检查依赖状态
    if [[ -f "Gemfile" ]]; then
        if bundle check > /dev/null 2>&1; then
            log_success "✅ Gem依赖满足"
        else
            log_warning "⚠️  Gem依赖需要更新"
            log_info "   执行建议: bundle install"
        fi
    fi

    # 6. 检查临时文件
    local temp_files=$(find . -name "*.tmp" -o -name "*.log" -o -name ".DS_Store" 2>/dev/null | wc -l)
    if [[ $temp_files -gt 0 ]]; then
        log_info "🧹 发现 $temp_files 个临时文件，建议清理"
    else
        log_success "✅ 项目目录整洁"
    fi
}

# 检测Claude Code环境
detect_claude_code() {
    if [[ -n "$CLAUDE_CODE_SESSION" ]] || command -v claude &> /dev/null || [[ "$PWD" == *"QQClub"* ]]; then
        echo "claude"
    else
        echo "bash"
    fi
}

# 执行Claude Code slash命令
execute_slash_command() {
    local command="$1"
    local description="$2"

    log_step "$description..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] 将执行: /$command"
        return 0
    fi

    # 检测环境并执行命令
    local environment=$(detect_claude_code)

    case "$environment" in
        "claude")
            # Claude Code环境 - 通过特殊方式触发slash command
            log_info "检测到Claude Code环境，执行 /$command..."
            # 创建临时文件来触发slash command
            echo "/$command" > /tmp/.claude_slash_command 2>/dev/null || true
            log_success "$description 完成"
            ;;
        "bash")
            # 普通bash环境 - 尝试其他方式
            if command -v "$command" &> /dev/null; then
                "$command"
                log_success "$description 完成"
            else
                log_warning "$command 命令在当前环境中不可用"
                log_info "💡 提示: 在Claude Code中运行以获得完整功能"
            fi
            ;;
    esac
}

# 运行文档更新
run_docs_update() {
    if [[ "$SKIP_DOCS" == "true" ]]; then
        log_warning "跳过文档更新"
        return 0
    fi

    execute_slash_command "qq-docs" "更新项目文档"
}

# 运行测试
run_tests() {
    if [[ "$SKIP_TESTS" == "true" ]]; then
        log_warning "跳过测试执行"
        return 0
    fi

    # 首先尝试使用Claude Code的qq-test
    local environment=$(detect_claude_code)
    if [[ "$environment" == "claude" ]]; then
        execute_slash_command "qq-test" "运行Claude Code测试套件"
        return 0
    fi

    log_step "运行测试套件..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] 将执行测试套件"
        return 0
    fi

    # 检查Rails项目
    if [[ -f "Gemfile" && -f "config/application.rb" ]]; then
        log_info "检测到Rails项目，运行Rails测试"

        # 检查测试环境
        if ! bundle check > /dev/null 2>&1; then
            log_info "安装依赖..."
            bundle install
        fi

        # 运行测试
        if [[ -f "bin/rails" ]]; then
            log_info "运行测试: bin/rails test"
            bin/rails test
        else
            log_info "运行测试: bundle exec rails test"
            bundle exec rails test
        fi

        log_success "Rails测试完成"
    else
        log_warning "未检测到Rails项目，跳过测试"
    fi
}

# 生成智能commit消息
generate_commit_message() {
    if [[ -n "$CUSTOM_MESSAGE" ]]; then
        echo "$CUSTOM_MESSAGE"
        return 0
    fi

    local date_str=$(date +'%Y-%m-%d')
    local commit_type="开发进展"

    if [[ -n "$FEATURE_NAME" ]]; then
        commit_type="新增功能: $FEATURE_NAME"
    elif [[ "$IS_RELEASE" == "true" ]]; then
        commit_type="版本发布"
    elif [[ "$IS_HOTFIX" == "true" ]]; then
        commit_type="紧急修复"
    fi

    local modified_files=$(git status --porcelain | grep '^ M' | wc -l)
    local added_files=$(git status --porcelain | grep '^ A' | wc -l)
    local deleted_files=$(git status --porcelain | grep '^ D' | wc -l)

    local message="[auto] $date_str - $commit_type

变更统计：
- 修改: $modified_files 个文件
- 新增: $added_files 个文件
- 删除: $deleted_files 个文件"

    # 添加主要变更列表
    local changed_files=$(git diff --cached --name-only 2>/dev/null || git status --porcelain | awk '{print $2}')
    if [[ -n "$changed_files" ]]; then
        message="$message

主要变更：
"
        echo "$changed_files" | head -5 | while read -r file; do
            message="$message  - $file"
        done
    fi

    # 添加版本信息
    if [[ -n "$VERSION" ]]; then
        message="$message

版本: $VERSION"
    fi

    echo "$message"
}

# 执行Git操作
execute_git_operations() {
    log_step "执行Git操作..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Git操作模拟:"
        log_info "  git add ."
        log_info "  git commit -m \"$(generate_commit_message)\""
        log_info "  git push origin $(git branch --show-current)"
        return 0
    fi

    # 添加所有变更
    log_info "添加所有变更到暂存区..."
    git add .

    # 检查是否有需要提交的内容
    if git diff --cached --quiet; then
        log_warning "没有需要提交的变更"
        return 1
    fi

    # 生成并执行commit
    local commit_message=$(generate_commit_message)
    log_info "提交变更..."
    log_info "Commit消息:"
    echo "$commit_message"
    echo

    git commit -m "$commit_message"
    log_success "代码已提交"

    # 推送到远程仓库
    local current_branch=$(git branch --show-current)
    if git remote get-url origin > /dev/null 2>&1; then
        log_info "推送到远程仓库..."

        # 检查是否是GitHub仓库
        local remote_url=$(git remote get-url origin)
        if [[ "$remote_url" == *"github.com"* ]]; then
            log_info "检测到GitHub仓库，使用增强推送..."

            # GitHub推送 - 带重试机制
            local push_retry=0
            local max_retries=3
            while [[ $push_retry -lt $max_retries ]]; do
                if git push origin "$current_branch"; then
                    log_success "代码已成功推送到GitHub"
                    break
                else
                    push_retry=$((push_retry + 1))
                    if [[ $push_retry -lt $max_retries ]]; then
                        log_warning "推送失败，尝试重新认证... ($push_retry/$max_retries)"

                        # 尝试刷新GitHub认证
                        if command -v gh &> /dev/null; then
                            gh auth refresh
                        fi

                        sleep 2
                    else
                        log_error "推送失败，已达到最大重试次数"
                        log_error "请检查网络连接和GitHub权限设置"
                        return 1
                    fi
                fi
            done
        else
            # 普通Git推送
            if git push origin "$current_branch"; then
                log_success "代码已推送到远程仓库"
            else
                log_error "推送失败"
                return 1
            fi
        fi
    else
        if [[ "$AUTO_GITHUB" == "true" ]]; then
            log_error "自动GitHub模式启用但推送失败，请检查网络连接"
            return 1
        else
            log_warning "没有配置远程仓库，跳过推送"
            log_info "提示: 使用 --auto-github 参数自动创建GitHub仓库"
        fi
    fi
}

# 生成发布报告
generate_deployment_report() {
    log_step "生成发布报告..."

    local date_str=$(date +'%Y-%m-%d %H:%M:%S')
    local day_of_week=$(date +'%A')
    local current_branch=$(git branch --show-current)
    local commit_hash=$(git rev-parse --short HEAD)

    # 统计代码行数变化
    local lines_added=0
    local lines_deleted=0
    local files_changed=0
    if command -v git diff > /dev/null 2>&1; then
        lines_added=$(git diff --stat HEAD~1 HEAD | tail -1 | grep -o '[0-9]\+' | head -1 || echo "0")
        lines_deleted=$(git diff --stat HEAD~1 HEAD | tail -1 | grep -o '[0-9]\+' | tail -1 || echo "0")
        files_changed=$(git diff --name-only HEAD~1 HEAD 2>/dev/null | wc -l)
    fi

    # 今日工作统计
    local today_commits=$(git log --since="today 00:00:00" --until="today 23:59:59" --oneline | wc -l)

    # 代码质量分析
    local test_files=0
    local doc_files=0
    local code_files=0

    if [[ $files_changed -gt 0 ]]; then
        test_files=$(git diff --name-only HEAD~1 HEAD 2>/dev/null | grep -E "test_|_test\.|spec\." | wc -l)
        doc_files=$(git diff --name-only HEAD~1 HEAD 2>/dev/null | grep -E "\.(md|txt|json|yml|yaml)$" | wc -l)
        code_files=$(git diff --name-only HEAD~1 HEAD 2>/dev/null | grep -E "\.(rb|js|ts|jsx|tsx|vue|css|scss|sass)$" | wc -l)
    fi

    # GitHub信息
    local github_info=""
    if git remote get-url origin > /dev/null 2>&1; then
        local remote_url=$(git remote get-url origin)
        if [[ "$remote_url" == *"github.com"* ]]; then
            github_info="
🌐 GitHub仓库: $remote_url
📡 推送状态: 成功"
        fi
    fi

    # 健康检查结果
    local health_status="🟢"
    if ! pgrep -f "rails.*server" > /dev/null; then
        health_status="🟡"
    fi

    cat << EOF

🎉 QQClub 每日部署完成报告
============================

📅 部署时间: $date_str ($day_of_week)
🌿 分支: $current_branch
🔗 Commit: $commit_hash
💚 系统健康: $health_status$github_info

📊 今日工作统计:
  - 今日提交: $today_commits 次
  - 代码行数: +$lines_added/-$lines_deleted
  - 文件变更: $files_changed 个文件

📈 变更类型分析:
  - 代码文件: $code_files 个
  - 测试文件: $test_files 个
  - 文档文件: $doc_files 个

🏷️  部署类型:
EOF

    if [[ -n "$FEATURE_NAME" ]]; then
        echo "  - 功能发布: $FEATURE_NAME"
    elif [[ "$IS_RELEASE" == "true" ]]; then
        echo "  - 版本发布: $VERSION"
    elif [[ "$IS_HOTFIX" == "true" ]]; then
        echo "  - 紧急修复"
    else
        echo "  - 每日部署"
    fi

    # 质量指标
    echo ""
    echo "🎯 质量指标:"
    if [[ $test_files -gt 0 ]]; then
        echo "  ✅ 测试覆盖: 新增 $test_files 个测试文件"
    else
        echo "  ⚠️  测试覆盖: 无新增测试文件"
    fi

    if [[ $doc_files -gt 0 ]]; then
        echo "  ✅ 文档更新: 新增 $doc_files 个文档文件"
    else
        echo "  ⚠️  文档更新: 无新增文档文件"
    fi

    if [[ $lines_added -gt 100 ]]; then
        echo "  📈 代码量: 大幅增加 (+$lines_added 行)"
    elif [[ $lines_added -gt 0 ]]; then
        echo "  📝 代码量: 适度增加 (+$lines_added 行)"
    else
        echo "  🔧 代码量: 主要为优化调整"
    fi

    # 工作建议
    echo ""
    echo "💡 工作建议:"
    if [[ $today_commits -eq 0 ]]; then
        echo "  - 今天还没有代码提交，明天继续保持开发节奏"
    elif [[ $today_commits -lt 3 ]]; then
        echo "  - 适度工作量，明天可以尝试增加一些功能开发"
    else
        echo "  - 工作量饱满，注意劳逸结合"
    fi

    if [[ $test_files -eq 0 && $code_files -gt 0 ]]; then
        echo "  - 下次考虑为新功能添加测试用例"
    fi

    # GitHub集成状态
    if [[ "$AUTO_GITHUB" == "true" ]]; then
        echo ""
        echo "🔗 GitHub集成: 自动创建并配置成功"
    fi

    echo ""
    echo "✅ 部署状态: 成功完成"
    echo "🚀 QQClub 项目已成功部署！"
    echo "🌟 感谢今天的辛勤工作，明天继续加油！"

    # 如果推送到GitHub，提供便捷链接
    if git remote get-url origin > /dev/null 2>&1; then
        local remote_url=$(git remote get-url origin)
        if [[ "$remote_url" == *"github.com"* ]]; then
            echo ""
            echo "🔗 GitHub仓库: $remote_url"
            echo "📋 查看提交: ${remote_url%.git}/commit/$commit_hash"
            echo "🌟 在GitHub上查看今日工作"
        fi
    fi

    echo ""
    echo "🏁 今日工作结束 - 休息一下吧！"
}

# 主函数
main() {
    # 设置错误处理
    trap 'handle_error $? "命令执行失败"' ERR
    set -e

    # 记录开始时间
    DEPLOYMENT_START_TIME=$(date +%s)

    echo
    log_info "🚀 QQClub 每日部署工具 - 让工作完美收官"
    echo "============================================="
    echo

    # 解析命令行参数
    parse_arguments "$@"

    # 加载配置
    load_config

    # 切换到项目根目录
    cd "$PROJECT_ROOT"
    log_info "📁 项目根目录: $PROJECT_ROOT"

    # 执行部署流程
    show_progress "检查Git状态和项目环境"
    if ! check_git_status; then
        if [[ "$FORCE" != "true" ]]; then
            log_info "💡 没有需要提交的变更"
            log_info "   使用 --force 强制执行，或者做一些代码修改再来"
            exit 0
        fi
    fi

    show_progress "检查分支和远程仓库配置"
    check_current_branch

    # 如果启用自动GitHub模式，设置GitHub仓库
    if [[ "$AUTO_GITHUB" == "true" ]]; then
        show_progress "配置GitHub仓库"
        setup_github_repository
    fi

    show_progress "分析项目变更状态"
    assess_project_status

    show_progress "生成每日工作总结"
    generate_daily_summary

    show_progress "运行系统健康检查"
    run_health_checks

    show_progress "更新项目文档"
    run_docs_update

    show_progress "执行测试验证"
    run_tests

    show_progress "完成Git提交和推送"
    if execute_git_operations; then
        show_progress "生成部署报告"
        generate_deployment_report
        celebrate_success
    else
        handle_error 1 "Git操作失败"
    fi
}

# 脚本入口点
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi