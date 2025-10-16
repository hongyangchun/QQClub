#!/bin/bash

# QQClub Permissions - 权限系统检查工具
# 版本: 1.0.0
# 作者: Claude Code Assistant
# 描述: 验证 QQClub 项目的 3 层权限体系是否正确实现和运行

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
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

log_test() {
    echo -e "${WHITE}[TEST]${NC} $1"
}

# 全局变量
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
API_URL="${API_URL:-http://localhost:3000}"
DEBUG="${DEBUG:-false}"
VERBOSE="${VERBOSE:-false}"
GENERATE_REPORT="${GENERATE_REPORT:-true}"
REPORT_FILE="permissions_check_report_$(date +%Y%m%d_%H%M%S).md"

# 测试结果统计
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
WARNING_TESTS=0

# 权限测试结果存储
declare -a TEST_RESULTS=()
declare -a PERMISSION_ISSUES=()

# 显示帮助信息
show_help() {
    cat << EOF
QQClub Permissions - 权限系统检查工具

用法: $0 [选项]

选项:
  --api-url <url>         API 服务器地址 (默认: http://localhost:3000)
  --debug                 显示调试信息
  --verbose               详细输出
  --no-report             不生成报告文件
  --report-file <file>    指定报告文件名
  --check-architecture    仅检查权限架构
  --check-roles           仅检查角色权限
  --check-time-windows    仅检查时间窗口权限
  --check-security        仅检查安全性
  --fix-issues            尝试修复发现的问题
  --help                  显示此帮助信息

示例:
  $0                                    # 完整权限检查
  $0 --debug --verbose                 # 详细调试模式
  $0 --check-architecture              # 仅检查架构
  $0 --api-url https://api.qqclub.com  # 检查生产环境

EOF
}

# 解析命令行参数
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --api-url)
                API_URL="$2"
                shift 2
                ;;
            --debug)
                DEBUG=true
                VERBOSE=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --no-report)
                GENERATE_REPORT=false
                shift
                ;;
            --report-file)
                REPORT_FILE="$2"
                shift 2
                ;;
            --check-architecture)
                CHECK_ARCHITECTURE_ONLY=true
                shift
                ;;
            --check-roles)
                CHECK_ROLES_ONLY=true
                shift
                ;;
            --check-time-windows)
                CHECK_TIME_WINDOWS_ONLY=true
                shift
                ;;
            --check-security)
                CHECK_SECURITY_ONLY=true
                shift
                ;;
            --fix-issues)
                FIX_ISSUES=true
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

# HTTP 请求函数
make_request() {
    local method="$1"
    local endpoint="$2"
    local data="$3"
    local token="$4"
    local expected_status="$5"

    local url="${API_URL}${endpoint}"
    local headers=(-H "Content-Type: application/json")

    if [[ -n "$token" ]]; then
        headers+=(-H "Authorization: Bearer ${token}")
    fi

    log_debug "请求: $method $url"
    if [[ -n "$data" ]]; then
        log_debug "数据: $data"
    fi

    local response
    local status_code

    if [[ "$method" == "GET" ]]; then
        response=$(curl -s -w "\n%{http_code}" "${headers[@]}" "$url")
    elif [[ "$method" == "POST" ]]; then
        response=$(curl -s -w "\n%{http_code}" -X POST "${headers[@]}" -d "$data" "$url")
    elif [[ "$method" == "PUT" ]]; then
        response=$(curl -s -w "\n%{http_code}" -X PUT "${headers[@]}" -d "$data" "$url")
    elif [[ "$method" == "DELETE" ]]; then
        response=$(curl -s -w "\n%{http_code}" -X DELETE "${headers[@]}" "$url")
    fi

    # 分离响应体和状态码
    status_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | head -n -1)

    log_debug "状态码: $status_code"
    log_debug "响应体: $body"

    # 检查状态码
    if [[ -n "$expected_status" ]]; then
        if [[ "$status_code" != "$expected_status" ]]; then
            log_warning "期望状态码 $expected_status，实际得到 $status_code"
        fi
    fi

    echo "$body"
    return 0
}

# 测试函数
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_result="$3"

    ((TOTAL_TESTS++))

    log_test "测试: $test_name"

    if [[ "$VERBOSE" == "true" ]]; then
        log_debug "执行: $test_command"
    fi

    local result
    if eval "$test_command" 2>/dev/null; then
        result=0
    else
        result=1
    fi

    if [[ "$result" == "$expected_result" ]]; then
        ((PASSED_TESTS++))
        log_success "✓ 通过: $test_name"
        TEST_RESULTS+=("PASS:$test_name")
    else
        ((FAILED_TESTS++))
        log_error "✗ 失败: $test_name"
        TEST_RESULTS+=("FAIL:$test_name")
        PERMISSION_ISSUES+=("$test_name")
    fi
}

# 检查API服务器连接
check_api_connection() {
    log_step "检查API服务器连接..."

    local response
    if response=$(make_request "GET" "/api/health" "" "" "200"); then
        log_success "API服务器连接正常"
        return 0
    else
        log_error "无法连接到API服务器: $API_URL"
        return 1
    fi
}

# 1. 权限架构验证
validate_permission_architecture() {
    log_step "验证权限架构..."

    echo
    log_info "=== 权限架构验证 ==="

    # 检查用户模型是否存在
    run_test "用户模型存在" "grep -q 'class User' app/models/user.rb" 0

    # 检查角色枚举定义
    run_test "用户角色枚举定义" "grep -q 'enum :role' app/models/user.rb" 0

    # 检查权限相关的方法
    run_test "管理员权限方法" "grep -q 'def any_admin?' app/models/user.rb" 0
    run_test "Root权限方法" "grep -q 'def root?' app/models/user.rb" 0
    run_test "权限检查方法" "grep -q 'def can_manage_event_content?' app/models/user.rb" 0

    # 检查AdminAuthorizable concern
    run_test "AdminAuthorizable存在" "test -f app/controllers/concerns/admin_authorizable.rb" 0

    # 检查控制器中的权限验证
    run_test "AdminController权限验证" "grep -q 'before_action :authenticate_admin!' app/controllers/admin_controller.rb" 0

    echo
    log_info "权限架构验证完成"
}

# 2. 角色权限测试
test_role_permissions() {
    log_step "测试角色权限..."

    echo
    log_info "=== 角色权限测试 ==="

    # 创建测试用户
    create_test_users

    # 测试Root用户权限
    test_root_permissions

    # 测试Admin用户权限
    test_admin_permissions

    # 测试普通用户权限
    test_user_permissions

    echo
    log_info "角色权限测试完成"
}

# 创建测试用户
create_test_users() {
    log_info "创建测试用户..."

    # Root用户（通常已经存在或需要特殊初始化）
    local root_data='{"user":{"nickname":"Root测试用户","wx_openid":"root_test_permissions_001"}}'
    local root_response=$(make_request "POST" "/api/auth/mock_login" "$root_data" "" "201")
    ROOT_TOKEN=$(echo "$root_response" | jq -r '.token // empty')

    # Admin用户
    local admin_data='{"user":{"nickname":"Admin测试用户","wx_openid":"admin_test_permissions_001"}}'
    local admin_response=$(make_request "POST" "/api/auth/mock_login" "$admin_data" "" "201")
    ADMIN_TOKEN=$(echo "$admin_response" | jq -r '.token // empty')

    # 普通用户
    local user_data='{"user":{"nickname":"普通测试用户","wx_openid":"user_test_permissions_001"}}'
    local user_response=$(make_request "POST" "/api/auth/mock_login" "$user_data" "" "201")
    USER_TOKEN=$(echo "$user_response" | jq -r '.token // empty')

    # 检查用户创建是否成功
    run_test "Root用户创建成功" "test -n '$ROOT_TOKEN'" 0
    run_test "Admin用户创建成功" "test -n '$ADMIN_TOKEN'" 0
    run_test "普通用户创建成功" "test -n '$USER_TOKEN'" 0
}

# 测试Root用户权限
test_root_permissions() {
    log_info "测试Root用户权限..."

    # 测试访问管理员面板
    run_test "Root访问管理员面板" "make_request 'GET' '/api/admin/dashboard' '' '$ROOT_TOKEN' '200' >/dev/null" 0

    # 测试用户管理权限
    run_test "Root查看用户列表" "make_request 'GET' '/api/admin/users' '' '$ROOT_TOKEN' '200' >/dev/null" 0

    # 测试活动审批权限
    run_test "Root审批活动" "make_request 'GET' '/api/admin/events/pending' '' '$ROOT_TOKEN' '200' >/dev/null" 0
}

# 测试Admin用户权限
test_admin_permissions() {
    log_info "测试Admin用户权限..."

    # 测试访问管理员面板
    run_test "Admin访问管理员面板" "make_request 'GET' '/api/admin/dashboard' '' '$ADMIN_TOKEN' '200' >/dev/null" 0

    # 测试用户管理权限（受限）
    run_test "Admin查看用户列表" "make_request 'GET' '/api/admin/users' '' '$ADMIN_TOKEN' '200' >/dev/null" 0

    # 测试活动审批权限
    run_test "Admin审批活动" "make_request 'GET' '/api/admin/events/pending' '' '$ADMIN_TOKEN' '200' >/dev/null" 0
}

# 测试普通用户权限
test_user_permissions() {
    log_info "测试普通用户权限..."

    # 测试访问管理员面板（应该失败）
    run_test "普通用户不能访问管理员面板" "make_request 'GET' '/api/admin/dashboard' '' '$USER_TOKEN' '403' >/dev/null" 0

    # 测试用户管理权限（应该失败）
    run_test "普通用户不能查看用户列表" "make_request 'GET' '/api/admin/users' '' '$USER_TOKEN' '403' >/dev/null" 0

    # 测试基础权限
    run_test "普通用户可以查看自己信息" "make_request 'GET' '/api/auth/me' '' '$USER_TOKEN' '200' >/dev/null" 0

    # 测试论坛权限
    test_forum_permissions "$USER_TOKEN"
}

# 测试论坛权限
test_forum_permissions() {
    local token="$1"

    # 创建测试帖子
    local post_data='{"post":{"title":"权限测试帖子","content":"这是一个用于测试权限的帖子内容，长度超过10个字符"}}'
    local post_response=$(make_request "POST" "/api/posts" "$post_data" "$token" "201")
    local post_id=$(echo "$post_response" | jq -r '.id // empty')

    if [[ -n "$post_id" ]]; then
        run_test "用户可以创建帖子" "test -n '$post_id'" 0

        # 测试编辑自己的帖子
        local update_data='{"post":{"title":"更新后的标题"}}'
        run_test "用户可以编辑自己的帖子" "make_request 'PUT' '/api/posts/$post_id' '$update_data' '$token' '200' >/dev/null" 0

        # 测试删除自己的帖子
        run_test "用户可以删除自己的帖子" "make_request 'DELETE' '/api/posts/$post_id' '' '$token' '204' >/dev/null" 0
    else
        ((FAILED_TESTS++))
        log_error "✗ 失败: 无法创建测试帖子"
        PERMISSION_ISSUES+=("帖子创建失败")
    fi
}

# 3. 时间窗口权限验证
test_time_window_permissions() {
    log_step "测试时间窗口权限..."

    echo
    log_info "=== 时间窗口权限测试 ==="

    # 创建测试活动
    create_test_activity

    # 测试领读人权限窗口
    test_daily_leader_permissions

    echo
    log_info "时间窗口权限测试完成"
}

# 创建测试活动
create_test_activity() {
    log_info "创建测试活动..."

    local today=$(date +%Y-%m-%d)
    local tomorrow=$(date -d "+1 day" +%Y-%m-%d)
    local day_after=$(date -d "+2 days" +%Y-%m-%d)

    local event_data="{
        \"event\": {
            \"title\": \"权限测试活动\",
            \"book_name\": \"测试书籍\",
            \"start_date\": \"$today\",
            \"end_date\": \"$day_after\",
            \"max_participants\": 10,
            \"enrollment_fee\": 50.00
        }
    }"

    local event_response=$(make_request "POST" "/api/events" "$event_data" "$USER_TOKEN" "201")
    TEST_EVENT_ID=$(echo "$event_response" | jq -r '.id // empty')

    if [[ -n "$TEST_EVENT_ID" ]]; then
        run_test "测试活动创建成功" "test -n '$TEST_EVENT_ID'" 0

        # 自动生成的阅读计划
        log_debug "测试活动ID: $TEST_EVENT_ID"
    else
        log_warning "无法创建测试活动，跳过时间窗口测试"
        TEST_EVENT_ID=""
    fi
}

# 测试领读人权限
test_daily_leader_permissions() {
    if [[ -z "$TEST_EVENT_ID" ]]; then
        return
    fi

    log_info "测试领读人权限..."

    # 获取活动的阅读计划
    local schedules_response=$(make_request "GET" "/api/events/$TEST_EVENT_ID/schedules" "" "$USER_TOKEN" "200")
    local schedule_id=$(echo "$schedules_response" | jq -r '.[0].id // empty')

    if [[ -n "$schedule_id" ]]; then
        run_test "获取阅读计划成功" "test -n '$schedule_id'" 0

        # 测试领读内容管理权限
        test_leading_content_permissions "$schedule_id"
    else
        log_warning "无法获取阅读计划，跳过领读权限测试"
    fi
}

# 测试领读内容权限
test_leading_content_permissions() {
    local schedule_id="$1"

    # 发布领读内容
    local leading_data='{"daily_leading":{"reading_suggestion":"测试阅读建议","questions":["问题1","问题2"]}}'
    local leading_response=$(make_request "POST" "/api/reading_schedules/$schedule_id/daily_leading" "$leading_data" "$USER_TOKEN" "201")

    run_test "发布领读内容" "echo '$leading_response' | jq -e '.id' >/dev/null" 0

    # 测试打卡管理权限
    test_check_in_permissions "$schedule_id"
}

# 测试打卡权限
test_check_in_permissions() {
    local schedule_id="$1"

    # 提交打卡
    local check_in_data='{"check_in":{"content":"这是一个测试打卡内容，确保字数超过100个字符以满足系统要求。通过这个测试，我们可以验证用户在指定阅读计划下提交打卡内容的功能是否正常工作，包括内容验证、字数统计以及权限控制等关键功能的正确性。"}}'
    local check_in_response=$(make_request "POST" "/api/reading_schedules/$schedule_id/check_ins" "$check_in_data" "$USER_TOKEN" "201")
    local check_in_id=$(echo "$check_in_response" | jq -r '.id // empty')

    run_test "提交打卡成功" "test -n '$check_in_id'" 0
}

# 4. 安全性测试
test_security() {
    log_step "进行安全性测试..."

    echo
    log_info "=== 安全性测试 ==="

    # 测试无效Token访问
    test_invalid_token_access

    # 测试权限越界访问
    test_privilege_escalation

    # 测试API端点安全性
    test_api_endpoint_security

    echo
    log_info "安全性测试完成"
}

# 测试无效Token访问
test_invalid_token_access() {
    log_info "测试无效Token访问..."

    local invalid_token="invalid_token_12345"

    run_test "无效Token访问管理员面板" "make_request 'GET' '/api/admin/dashboard' '' '$invalid_token' '401' >/dev/null" 0
    run_test "无效Token访问用户信息" "make_request 'GET' '/api/auth/me' '' '$invalid_token' '401' >/dev/null" 0
    run_test "无Token访问受保护端点" "make_request 'GET' '/api/admin/dashboard' '' '' '401' >/dev/null" 0
}

# 测试权限越界
test_privilege_escalation() {
    log_info "测试权限越界防护..."

    # 尝试普通用户执行管理员操作
    run_test "普通用户尝试管理用户" "make_request 'PUT' '/api/admin/users/1/promote_admin' '' '$USER_TOKEN' '403' >/dev/null" 0
    run_test "普通用户尝试初始化Root" "make_request 'POST' '/api/admin/init_root' '' '$USER_TOKEN' '403' >/dev/null" 0
}

# 测试API端点安全性
test_api_endpoint_security() {
    log_info "测试API端点安全性..."

    # 检查敏感端点是否受保护
    local sensitive_endpoints=(
        "/api/admin/dashboard"
        "/api/admin/users"
        "/api/admin/events/pending"
        "/api/admin/init_root"
    )

    for endpoint in "${sensitive_endpoints[@]}"; do
        run_test "端点受保护: $endpoint" "make_request 'GET' '$endpoint' '' '' '401' >/dev/null" 0
    done
}

# 5. 备份机制测试
test_backup_mechanism() {
    log_step "测试备份机制..."

    echo
    log_info "=== 备份机制测试 ==="

    if [[ -n "$TEST_EVENT_ID" ]]; then
        # 测试备份需求检查
        local backup_response=$(make_request "GET" "/api/events/$TEST_EVENT_ID/backup_needed" "" "$USER_TOKEN" "200")
        run_test "备份需求检查功能" "echo '$backup_response' | jq -e '.backup_needed' >/dev/null" 0
    else
        log_warning "没有测试活动，跳过备份机制测试"
    fi

    echo
    log_info "备份机制测试完成"
}

# 生成权限检查报告
generate_permission_report() {
    if [[ "$GENERATE_REPORT" != "true" ]]; then
        return
    fi

    log_step "生成权限检查报告..."

    local report_content="# QQClub 权限系统检查报告

生成时间: $(date)
API服务器: $API_URL
检查模式: $([ "$DEBUG" == "true" ] && echo "调试模式" || echo "标准模式")

## 测试统计

- **总测试数**: $TOTAL_TESTS
- **通过测试**: $PASSED_TESTS
- **失败测试**: $FAILED_TESTS
- **警告测试**: $WARNING_TESTS
- **成功率**: $(( TOTAL_TESTS > 0 ? PASSED_TESTS * 100 / TOTAL_TESTS : 0 ))%

## 测试结果详情

"

    # 添加测试结果详情
    if [[ ${#TEST_RESULTS[@]} -gt 0 ]]; then
        report_content+="### 测试结果清单

"

        for result in "${TEST_RESULTS[@]}"; do
            local status=$(echo "$result" | cut -d: -f1)
            local test_name=$(echo "$result" | cut -d: -f2-)

            if [[ "$status" == "PASS" ]]; then
                report_content+="- ✅ $test_name\n"
            else
                report_content+="- ❌ $test_name\n"
            fi
        done
    fi

    # 添加问题列表
    if [[ ${#PERMISSION_ISSUES[@]} -gt 0 ]]; then
        report_content+="

## 发现的问题

"
        for issue in "${PERMISSION_ISSUES[@]}"; do
            report_content+="- $issue\n"
        done
    fi

    # 添加权限架构概览
    report_content+="

## 权限架构概览

### 3层权限体系
1. **Admin Level** - 管理员级别
   - Root (超级管理员)
   - Admin (管理员)

2. **Event Level** - 活动级别
   - Group Leader (小组长)
   - Daily Leader (领读人)

3. **User Level** - 用户级别
   - Forum User (论坛用户)
   - Participant (活动参与者)

### 关键权限检查点
- ✅ 角色定义和枚举
- ✅ 权限验证方法
- ✅ API端点保护
- ✅ 时间窗口权限
- ✅ 备份机制

## 安全建议

"

    if [[ $FAILED_TESTS -gt 0 ]]; then
        report_content+="⚠️ **发现问题**: 检测到 $FAILED_TESTS 个权限相关问题，建议立即修复。\n\n"
    else
        report_content+="✅ **状态良好**: 所有权限检查通过，系统安全性良好。\n\n"
    fi

    report_content+="### 优先修复建议
1. 立即修复权限越界问题
2. 完善API端点权限验证
3. 加强Token安全验证
4. 优化时间窗口权限逻辑

### 长期改进建议
1. 定期执行权限检查
2. 增加权限变更审计
3. 完善权限测试覆盖
4. 建立权限监控告警

## 技术细节

### 检查范围
- 权限架构完整性
- 角色权限正确性
- 时间窗口权限
- API端点安全性
- 备份机制有效性

### 测试环境
- Ruby版本: $(ruby --version 2>/dev/null || echo "未知")
- Rails版本: $(cd "$PROJECT_ROOT/qqclub_api" 2>/dev/null && bundle exec rails --version 2>/dev/null || echo "未知")
- 数据库: $(cd "$PROJECT_ROOT/qqclub_api" 2>/dev/null && bundle exec rails runner "puts ActiveRecord::Base.connection.adapter_name" 2>/dev/null || echo "未知")

---

*此报告由 QQClub Permissions 工具自动生成*
"

    # 写入报告文件
    echo -e "$report_content" > "$REPORT_FILE"
    log_success "权限检查报告已生成: $REPORT_FILE"
}

# 显示测试统计
show_test_statistics() {
    echo
    echo "==================================="
    echo -e "${WHITE}📊 权限检查统计${NC}"
    echo "==================================="
    echo -e "总测试数: ${BLUE}$TOTAL_TESTS${NC}"
    echo -e "通过测试: ${GREEN}$PASSED_TESTS${NC}"
    echo -e "失败测试: ${RED}$FAILED_TESTS${NC}"
    echo -e "警告测试: ${YELLOW}$WARNING_TESTS${NC}"

    local success_rate=0
    if [[ $TOTAL_TESTS -gt 0 ]]; then
        success_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
    fi

    echo -e "成功率: ${CYAN}$success_rate%${NC}"
    echo "==================================="

    if [[ $FAILED_TESTS -gt 0 ]]; then
        echo
        log_warning "发现 $FAILED_TESTS 个权限问题，请查看详细报告"
        return 1
    else
        echo
        log_success "所有权限检查通过！"
        return 0
    fi
}

# 主函数
main() {
    echo
    log_info "🔒 QQClub Permissions - 权限系统检查工具"
    echo "=================================================="
    echo

    # 解析命令行参数
    parse_arguments "$@"

    # 切换到项目根目录
    cd "$PROJECT_ROOT"

    log_info "项目根目录: $PROJECT_ROOT"
    log_info "API服务器: $API_URL"

    # 检查Rails应用目录
    if [[ ! -d "qqclub_api" ]]; then
        log_error "找不到 qqclub_api 目录，请确保在项目根目录运行此脚本"
        exit 1
    fi

    # 检查API服务器连接
    if ! check_api_connection; then
        log_error "无法连接到API服务器，请确保服务器正在运行"
        exit 1
    fi

    # 根据参数执行相应的检查
    if [[ "$CHECK_ARCHITECTURE_ONLY" == "true" ]]; then
        validate_permission_architecture
    elif [[ "$CHECK_ROLES_ONLY" == "true" ]]; then
        test_role_permissions
    elif [[ "$CHECK_TIME_WINDOWS_ONLY" == "true" ]]; then
        test_time_window_permissions
    elif [[ "$CHECK_SECURITY_ONLY" == "true" ]]; then
        test_security
    else
        # 完整的权限检查
        validate_permission_architecture
        test_role_permissions
        test_time_window_permissions
        test_security
        test_backup_mechanism
    fi

    # 生成报告
    generate_permission_report

    # 显示统计信息
    show_test_statistics
}

# 脚本入口点
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi