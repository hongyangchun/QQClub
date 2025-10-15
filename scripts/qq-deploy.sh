#!/bin/bash

# QQClub Deploy Script - 项目部署和发布工具
# 版本: 1.0.0
# 作者: Claude Code Assistant
# 描述: 自动化部署流程，包括环境检查、测试、文档更新和Git操作

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

# 默认配置
DEFAULT_CONFIG="
# QQClub Deploy 配置文件
auto_commit: true
auto_push: true
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
CUSTOM_MESSAGE=""
FEATURE_NAME=""
IS_RELEASE=false
IS_HOTFIX=false
VERSION=""

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
  $0 --feature="论坛系统" # 功能发布
  $0 --release --version="v1.2.0" # 版本发布
  $0 --hotfix --message="修复权限越界问题" # 紧急修复

EOF
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

# 检查当前分支
check_current_branch() {
    log_step "检查当前分支..."

    local current_branch=$(git branch --show-current)
    log_info "当前分支: $current_branch"

    # 检查是否在主分支上
    if [[ "$current_branch" == "main" || "$current_branch" == "master" ]]; then
        if [[ "$FORCE" != "true" ]]; then
            log_warning "您正在主分支 ($current_branch) 上"
            read -p "是否继续? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_info "操作已取消"
                exit 0
            fi
        fi
    fi

    # 检查远程连接
    if git remote get-url origin > /dev/null 2>&1; then
        log_info "远程仓库: $(git remote get-url origin)"
    else
        log_warning "没有配置远程仓库"
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

# 运行文档更新
run_docs_update() {
    if [[ "$SKIP_DOCS" == "true" ]]; then
        log_warning "跳过文档更新"
        return 0
    fi

    log_step "更新项目文档..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] 将执行: /qq-docs"
        return 0
    fi

    # 检查是否存在qq-docs命令
    if command -v qq-docs &> /dev/null; then
        qq-docs
        log_success "文档更新完成"
    else
        log_warning "qq-docs 命令不存在，跳过文档更新"
    fi
}

# 运行测试
run_tests() {
    if [[ "$SKIP_TESTS" == "true" ]]; then
        log_warning "跳过测试执行"
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
        git push origin "$current_branch"
        log_success "代码已推送到远程仓库"
    else
        log_warning "没有配置远程仓库，跳过推送"
    fi
}

# 生成发布报告
generate_deployment_report() {
    log_step "生成发布报告..."

    local date_str=$(date +'%Y-%m-%d %H:%M:%S')
    local current_branch=$(git branch --show-current)
    local commit_hash=$(git rev-parse --short HEAD)

    # 统计代码行数变化（需要git配置）
    local lines_added=0
    local lines_deleted=0
    if command -v git diff > /dev/null 2>&1; then
        lines_added=$(git diff --stat HEAD~1 HEAD | tail -1 | grep -o '[0-9]\+' | head -1 || echo "0")
        lines_deleted=$(git diff --stat HEAD~1 HEAD | tail -1 | grep -o '[0-9]\+' | tail -1 || echo "0")
    fi

    cat << EOF

🎉 QQClub 部署完成报告
========================

📅 部署时间: $date_str
🌿 分支: $current_branch
🔗 Commit: $commit_hash

📊 变更统计:
  - 代码行数: +$lines_added/-$lines_deleted
  - 文件变更: $(git diff --name-only HEAD~1 HEAD 2>/dev/null | wc -l) 个文件

🏷️  部署类型:
EOF

    if [[ -n "$FEATURE_NAME" ]]; then
        echo "  - 功能发布: $FEATURE_NAME"
    elif [[ "$IS_RELEASE" == "true" ]]; then
        echo "  - 版本发布: $VERSION"
    elif [[ "$IS_HOTFIX" == "true" ]]; then
        echo "  - 紧急修复"
    else
        echo "  - 常规部署"
    fi

    echo
    echo "✅ 部署状态: 成功"
    echo "🚀 项目已成功部署！"
}

# 主函数
main() {
    echo
    log_info "🚀 QQClub Deploy - 项目部署和发布工具"
    echo "=================================================="
    echo

    # 解析命令行参数
    parse_arguments "$@"

    # 加载配置
    load_config

    # 切换到项目根目录
    cd "$PROJECT_ROOT"

    log_info "项目根目录: $PROJECT_ROOT"

    # 执行部署流程
    if ! check_git_status; then
        if [[ "$FORCE" != "true" ]]; then
            log_error "没有需要提交的变更，使用 --force 强制执行"
            exit 1
        fi
    fi

    check_current_branch
    assess_project_status
    run_docs_update
    run_tests

    if execute_git_operations; then
        generate_deployment_report
        log_success "🎉 部署流程完成！"
    else
        log_error "部署过程中出现错误"
        exit 1
    fi
}

# 脚本入口点
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi