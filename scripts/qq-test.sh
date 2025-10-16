#!/bin/bash

# QQClub Test - 项目测试执行工具
# 版本: 1.0.0
# 作者: Claude Code Assistant
# 描述: 对 QQClub 项目进行全面的测试，包括单元测试、集成测试和API测试

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
API_ROOT="$PROJECT_ROOT/qqclub_api"
API_URL="${API_URL:-http://localhost:3000}"
DEBUG="${DEBUG:-false}"
VERBOSE="${VERBOSE:-false}"
COVERAGE="${COVERAGE:-true}"
GENERATE_REPORT="${GENERATE_REPORT:-true}"
REPORT_FILE="test_report_$(date +%Y%m%d_%H%M%S).md"
PARALLEL="${PARALLEL:-false}"
PERFORMANCE_TEST="${PERFORMANCE_TEST:-false}"

# 测试结果统计
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0
COVERAGE_PERCENT=0

# 测试结果存储
declare -a TEST_RESULTS=()
declare -a FAILED_TEST_NAMES=()
declare -a PERFORMANCE_RESULTS=()

# 显示帮助信息
show_help() {
    cat << EOF
QQClub Test - 项目测试执行工具

用法: $0 [选项] [测试类型]

测试类型:
  models                  运行模型测试 (核心业务逻辑)
  api                     运行API功能测试 (端到端验证)
  permissions             运行权限系统测试 (安全验证)
  controllers             运行控制器测试 (详细测试)
  quick                   快速功能检查 (2-3分钟)
  diagnose                详细诊断测试 (15-20分钟)
  all                     运行所有测试 (默认)

选项:
  --api-url <url>         API 服务器地址 (默认: http://localhost:3000)
  --debug                 显示调试信息
  --verbose               详细输出
  --no-coverage           跳过覆盖率测试
  --no-report             不生成测试报告
  --report-file <file>    指定报告文件名
  --parallel              并行执行测试
  --performance           包含性能测试
  --fix-issues            尝试修复发现的问题
  --env <environment>     指定测试环境 (development/test/production)
  --timeout <seconds>     设置测试超时时间
  --rails                 优先使用Rails测试框架
  --help                  显示此帮助信息

示例:
  $0                                    # 运行所有测试
  $0 models                             # 运行模型测试 (核心业务逻辑)
  $0 api --verbose                      # 详细API功能测试
  $0 permissions                        # 权限系统安全测试
  $0 all --coverage                     # 完整测试 + 覆盖率报告
  $0 --api-url https://api.qqclub.com  # 测试生产环境

EOF
}

# 解析命令行参数
parse_arguments() {
    local test_type="all"

    while [[ $# -gt 0 ]]; do
        case $1 in
            models|api|permissions|controllers|quick|diagnose|all)
                test_type="$1"
                shift
                ;;
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
            --no-coverage)
                COVERAGE=false
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
            --parallel)
                PARALLEL=true
                shift
                ;;
            --performance)
                PERFORMANCE_TEST=true
                shift
                ;;
            --fix-issues)
                FIX_ISSUES=true
                shift
                ;;
            --env)
                RAILS_ENV="$2"
                export RAILS_ENV="$2"
                shift 2
                ;;
            --timeout)
                TEST_TIMEOUT="$2"
                shift 2
                ;;
            --rails)
                USE_RAILS_FRAMEWORK=true
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

    TEST_TYPE="$test_type"
}

# 执行测试函数
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_exit_code="${3:-0}"
    local timeout="${4:-$TEST_TIMEOUT}"

    log_test "执行: $test_name"

    if [[ "$VERBOSE" == "true" ]]; then
        log_debug "命令: $test_command"
        log_debug "期望退出码: $expected_exit_code"
        log_debug "超时时间: ${timeout:-默认}秒"
    fi

    local start_time=$(date +%s)
    local exit_code
    local output

    # 执行测试命令
    if [[ -n "$timeout" && "$timeout" != "0" ]]; then
        output=$(timeout "$timeout" bash -c "$test_command" 2>&1)
        exit_code=$?
    else
        output=$(bash -c "$test_command" 2>&1)
        exit_code=$?
    fi

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    if [[ "$exit_code" == "$expected_exit_code" ]]; then
        ((PASSED_TESTS++))
        log_success "✓ 通过: $test_name (${duration}s)"
        TEST_RESULTS+=("PASS:$test_name:$duration")
    else
        ((FAILED_TESTS++))
        log_error "✗ 失败: $test_name (${duration}s) - 退出码: $exit_code"
        if [[ "$VERBOSE" == "true" ]]; then
            echo "输出:"
            echo "$output" | head -20
        fi
        TEST_RESULTS+=("FAIL:$test_name:$duration:$exit_code")
        FAILED_TEST_NAMES+=("$test_name")
    fi

    ((TOTAL_TESTS++))
}

# 检查测试环境
check_test_environment() {
    log_step "检查测试环境..."

    # 检查项目目录
    if [[ ! -d "$API_ROOT" ]]; then
        log_error "找不到 API 目录: $API_ROOT"
        return 1
    fi

    # 检查 Ruby 版本
    if ! command -v ruby &> /dev/null; then
        log_error "Ruby 未安装或不在 PATH 中"
        return 1
    fi

    local ruby_version=$(ruby --version)
    log_info "Ruby 版本: $ruby_version"

    # 检查 Bundler
    if ! command -v bundle &> /dev/null; then
        log_error "Bundler 未安装"
        return 1
    fi

    # 检查依赖
    cd "$API_ROOT"
    if ! bundle check > /dev/null 2>&1; then
        log_info "安装依赖..."
        bundle install
    fi

    # 检查数据库
    check_database_connection

    log_success "测试环境检查完成"
}

# 检查数据库连接
check_database_connection() {
    log_info "检查数据库连接..."

    # 检查测试数据库是否存在
    if ! bundle exec rails runner "ActiveRecord::Base.connection.execute('SELECT 1')" > /dev/null 2>&1; then
        log_info "准备测试数据库..."
        bundle exec rails db:test:prepare
    fi

    # 验证数据库连接
    if bundle exec rails runner "puts ActiveRecord::Base.connection.execute('SELECT 1').first['?column?']" > /dev/null 2>&1; then
        log_success "数据库连接正常"
    else
        log_error "数据库连接失败"
        return 1
    fi
}

# 运行单元测试
run_unit_tests() {
    log_step "运行单元测试..."

    cd "$API_ROOT"

    # 运行模型测试
    local coverage_flag=""
    if [[ "$COVERAGE" == "true" ]]; then
        coverage_flag="COVERAGE=true"
    fi

    if [[ "$PARALLEL" == "true" ]]; then
        run_test "模型测试 (并行)" "$coverage_flag bundle exec rails test test/models --parallel"
    else
        run_test "模型测试" "$coverage_flag bundle exec rails test test/models"
    fi

    # 运行邮件测试
    if [[ -d "test/mailers" ]]; then
        run_test "邮件测试" "$coverage_flag bundle exec rails test test/mailers"
    fi

    # 运行作业测试
    if [[ -d "test/jobs" ]]; then
        run_test "作业测试" "$coverage_flag bundle exec rails test test/jobs"
    fi

    log_success "单元测试完成"
}

# 运行集成测试
run_integration_tests() {
    log_step "运行集成测试..."

    cd "$API_ROOT"

    # 运行控制器测试
    local coverage_flag=""
    if [[ "$COVERAGE" == "true" ]]; then
        coverage_flag="COVERAGE=true"
    fi

    if [[ "$PARALLEL" == "true" ]]; then
        run_test "控制器测试 (并行)" "$coverage_flag bundle exec rails test test/controllers --parallel"
    else
        run_test "控制器测试" "$coverage_flag bundle exec rails test test/controllers"
    fi

    # 运行系统集成测试
    if [[ -d "test/integration" ]]; then
        run_test "系统集成测试" "$coverage_flag bundle exec rails test test/integration"
    fi

    log_success "集成测试完成"
}

# 运行API测试
run_api_tests() {
    log_step "运行API测试..."

    # 检查API服务器状态
    if ! check_api_server; then
        log_error "API服务器未运行，请先启动服务器"
        return 1
    fi

    # 创建测试用户
    create_api_test_users

    # 运行API端点测试
    test_authentication_endpoints
    test_forum_endpoints
    test_event_endpoints
    test_permission_endpoints

    log_success "API测试完成"
}

# 检查API服务器状态
check_api_server() {
    log_info "检查API服务器状态..."

    local response
    if response=$(curl -s -w "%{http_code}" "$API_URL/api/health" 2>/dev/null); then
        local status_code="${response: -3}"
        if [[ "$status_code" == "200" ]]; then
            log_success "API服务器运行正常"
            return 0
        fi
    fi

    return 1
}

# 创建API测试用户
create_api_test_users() {
    log_info "创建API测试用户..."

    local test_users=(
        "api_test_root:Root测试用户:root"
        "api_test_admin:Admin测试用户:admin"
        "api_test_user:普通测试用户:user"
    )

    for user_data in "${test_users[@]}"; do
        IFS=':' read -r openid nickname role <<< "$user_data"

        local user_json="{\"user\":{\"nickname\":\"$nickname\",\"wx_openid\":\"$openid\"}}"
        local response=$(curl -s -X POST "$API_URL/api/auth/mock_login" \
            -H "Content-Type: application/json" \
            -d "$user_json" 2>/dev/null)

        if echo "$response" | jq -e '.token' > /dev/null 2>&1; then
            log_debug "测试用户创建成功: $nickname"
        else
            log_warning "测试用户创建失败: $nickname"
        fi
    done
}

# 测试认证端点
test_authentication_endpoints() {
    log_info "测试认证端点..."

    # 获取测试用户token
    local root_token=$(get_user_token "api_test_root")
    local admin_token=$(get_user_token "api_test_admin")
    local user_token=$(get_user_token "api_test_user")

    # 测试登录端点
    run_test "模拟登录" "curl -s -X POST '$API_URL/api/auth/mock_login' \
        -H 'Content-Type: application/json' \
        -d '{\"user\":{\"nickname\":\"测试登录\",\"wx_openid\":\"test_login_001\"}}' \
        | jq -e '.token' > /dev/null"

    # 测试获取用户信息
    run_test "获取用户信息" "curl -s -X GET '$API_URL/api/auth/me' \
        -H 'Authorization: Bearer $user_token' \
        | jq -e '.user.id' > /dev/null"

    # 测试更新用户资料
    run_test "更新用户资料" "curl -s -X PUT '$API_URL/api/auth/profile' \
        -H 'Authorization: Bearer $user_token' \
        -H 'Content-Type: application/json' \
        -d '{\"user\":{\"nickname\":\"更新后的昵称\"}}' \
        | jq -e '.user.nickname' > /dev/null"
}

# 测试论坛端点
test_forum_endpoints() {
    log_info "测试论坛端点..."

    local user_token=$(get_user_token "api_test_user")

    # 创建测试帖子
    local post_response=$(curl -s -X POST "$API_URL/api/posts" \
        -H "Authorization: Bearer $user_token" \
        -H "Content-Type: application/json" \
        -d '{"post":{"title":"API测试帖子","content":"这是一个用于API测试的帖子内容，确保长度满足系统要求"}}')

    local post_id=$(echo "$post_response" | jq -r '.id // empty')

    if [[ -n "$post_id" ]]; then
        run_test "创建帖子" "test -n '$post_id'"

        # 测试获取帖子列表
        run_test "获取帖子列表" "curl -s -X GET '$API_URL/api/posts' \
            -H 'Authorization: Bearer $user_token' \
            | jq -e 'length > 0' > /dev/null"

        # 测试获取帖子详情
        run_test "获取帖子详情" "curl -s -X GET '$API_URL/api/posts/$post_id' \
            -H 'Authorization: Bearer $user_token' \
            | jq -e '.id' > /dev/null"

        # 测试更新帖子
        run_test "更新帖子" "curl -s -X PUT '$API_URL/api/posts/$post_id' \
            -H 'Authorization: Bearer $user_token' \
            -H 'Content-Type: application/json' \
            -d '{\"post\":{\"title\":\"更新后的标题\"}}' \
            | jq -e '.title' > /dev/null"

        # 测试删除帖子
        run_test "删除帖子" "curl -s -X DELETE '$API_URL/api/posts/$post_id' \
            -H 'Authorization: Bearer $user_token' \
            | test $(curl -s -o /dev/null -w '%{http_code}' "$API_URL/api/posts/$post_id" \
            -H 'Authorization: Bearer $user_token') = 404"
    else
        ((FAILED_TESTS++))
        log_error "✗ 失败: 无法创建测试帖子"
        FAILED_TEST_NAMES+=("创建帖子失败")
    fi
}

# 测试活动端点
test_event_endpoints() {
    log_info "测试活动端点..."

    local user_token=$(get_user_token "api_test_user")
    local today=$(date +%Y-%m-%d)
    local tomorrow=$(date -d "+1 day" +%Y-%m-%d)

    # 创建测试活动
    local event_response=$(curl -s -X POST "$API_URL/api/events" \
        -H "Authorization: Bearer $user_token" \
        -H "Content-Type: application/json" \
        -d "{\"event\":{\"title\":\"API测试活动\",\"book_name\":\"测试书籍\",\"start_date\":\"$today\",\"end_date\":\"$tomorrow\",\"max_participants\":10}}")

    local event_id=$(echo "$event_response" | jq -r '.id // empty')

    if [[ -n "$event_id" ]]; then
        run_test "创建活动" "test -n '$event_id'"

        # 测试获取活动列表
        run_test "获取活动列表" "curl -s -X GET '$API_URL/api/events' \
            -H 'Authorization: Bearer $user_token' \
            | jq -e 'length > 0' > /dev/null"

        # 测试获取活动详情
        run_test "获取活动详情" "curl -s -X GET '$API_URL/api/events/$event_id' \
            -H 'Authorization: Bearer $user_token' \
            | jq -e '.id' > /dev/null"

        # 测试活动报名
        run_test "活动报名" "curl -s -X POST '$API_URL/api/events/$event_id/enroll' \
            -H 'Authorization: Bearer $user_token' \
            | jq -e '.success' > /dev/null"

    else
        ((FAILED_TESTS++))
        log_error "✗ 失败: 无法创建测试活动"
        FAILED_TEST_NAMES+=("创建活动失败")
    fi
}

# 测试权限端点
test_permission_endpoints() {
    log_info "测试权限端点..."

    local user_token=$(get_user_token "api_test_user")
    local admin_token=$(get_user_token "api_test_admin")

    # 测试普通用户访问管理员面板（应该失败）
    run_test "普通用户访问管理员面板" "test \$(curl -s -o /dev/null -w '%{http_code}' '$API_URL/api/admin/dashboard' \
        -H 'Authorization: Bearer $user_token') = 403"

    # 测试管理员访问管理员面板（应该成功）
    run_test "管理员访问管理员面板" "test \$(curl -s -o /dev/null -w '%{http_code}' '$API_URL/api/admin/dashboard' \
        -H 'Authorization: Bearer $admin_token') = 200"
}

# 获取用户token
get_user_token() {
    local openid="$1"
    local response=$(curl -s -X POST "$API_URL/api/auth/mock_login" \
        -H "Content-Type: application/json" \
        -d "{\"user\":{\"wx_openid\":\"$openid\",\"nickname\":\"Token获取用户\"}}")
    echo "$response" | jq -r '.token // empty'
}

# 运行权限测试
run_permission_tests() {
    log_step "运行权限测试..."

    # 调用权限检查工具
    if [[ -f "$SCRIPT_DIR/qq-permissions.sh" ]]; then
        run_test "权限系统检查" "$SCRIPT_DIR/qq-permissions.sh --no-report" 0
    else
        log_warning "权限检查工具不存在，跳过权限测试"
    fi

    log_success "权限测试完成"
}

# 运行性能测试
run_performance_tests() {
    if [[ "$PERFORMANCE_TEST" != "true" ]]; then
        return
    fi

    log_step "运行性能测试..."

    # API响应时间测试
    test_api_response_time

    # 并发测试
    test_concurrent_requests

    log_success "性能测试完成"
}

# 测试API响应时间
test_api_response_time() {
    log_info "测试API响应时间..."

    local endpoints=(
        "$API_URL/api/health"
        "$API_URL/api/posts"
        "$API_URL/api/events"
    )

    for endpoint in "${endpoints[@]}"; do
        local response_time=$(curl -o /dev/null -s -w "%{time_total}" "$endpoint")
        local endpoint_name=$(basename "$endpoint")

        if (( $(echo "$response_time < 1.0" | bc -l) )); then
            ((PASSED_TESTS++))
            log_success "✓ $endpoint_name 响应时间: ${response_time}s (< 1.0s)"
            PERFORMANCE_RESULTS+=("$endpoint_name:$response_time:PASS")
        else
            ((FAILED_TESTS++))
            log_error "✗ $endpoint_name 响应时间: ${response_time}s (>= 1.0s)"
            PERFORMANCE_RESULTS+=("$endpoint_name:$response_time:FAIL")
        fi
        ((TOTAL_TESTS++))
    done
}

# 测试并发请求
test_concurrent_requests() {
    log_info "测试并发请求..."

    local concurrent_count=10
    local endpoint="$API_URL/api/posts"

    # 创建临时脚本来测试并发
    local temp_script="/tmp/concurrent_test_$$.sh"
    cat > "$temp_script" << EOF
#!/bin/bash
for i in {1..$concurrent_count}; do
    curl -s -o /dev/null -w "%{http_code}" "$endpoint" &
done
wait
EOF

    chmod +x "$temp_script"

    local start_time=$(date +%s.%N)
    local results=$("$temp_script")
    local end_time=$(date +%s.%N)
    local total_time=$(echo "$end_time - $start_time" | bc)

    local success_count=$(echo "$results" | grep -c "200")
    local total_count=$concurrent_count

    rm -f "$temp_script"

    if [[ $success_count -eq $total_count ]]; then
        ((PASSED_TESTS++))
        log_success "✓ 并发测试: $success_count/$total_count 成功 (${total_time}s)"
        PERFORMANCE_RESULTS+=("concurrent:$total_time:PASS")
    else
        ((FAILED_TESTS++))
        log_error "✗ 并发测试: $success_count/$total_count 成功 (${total_time}s)"
        PERFORMANCE_RESULTS+=("concurrent:$total_time:FAIL")
    fi
    ((TOTAL_TESTS++))
}

# 运行覆盖率测试
run_coverage_tests() {
    if [[ "$COVERAGE" != "true" ]]; then
        return
    fi

    log_step "运行覆盖率测试..."

    cd "$API_ROOT"

    # 设置环境变量启用覆盖率
    export COVERAGE=true

    # 运行测试并生成覆盖率报告
    if bundle exec rails test > /dev/null 2>&1; then
        # 尝试获取覆盖率数据
        if [[ -f "coverage/coverage.json" ]]; then
            COVERAGE_PERCENT=$(jq -r '.metrics.total.percent_covered' coverage/coverage.json 2>/dev/null || echo "0")
            log_success "测试覆盖率: ${COVERAGE_PERCENT}%"
        else
            # 尝试其他覆盖率文件格式
            if [[ -f "coverage/.last_run.json" ]]; then
                COVERAGE_PERCENT=$(jq -r '.RSpec.coverage_percent' coverage/.last_run.json 2>/dev/null || echo "0")
                log_success "测试覆盖率: ${COVERAGE_PERCENT}%"
            else
                log_warning "无法获取覆盖率数据"
            fi
        fi
    else
        log_warning "覆盖率测试失败，继续执行其他测试"
    fi

    log_success "覆盖率测试完成"
}

# 生成测试报告
generate_test_report() {
    if [[ "$GENERATE_REPORT" != "true" ]]; then
        return
    fi

    log_step "生成测试报告..."

    local success_rate=0
    if [[ $TOTAL_TESTS -gt 0 ]]; then
        success_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
    fi

    local report_content="# QQClub 测试报告

生成时间: $(date)
API服务器: $API_URL
测试环境: ${RAILS_ENV:-development}
测试模式: $([ "$DEBUG" == "true" ] && echo "调试模式" || echo "标准模式")

## 测试统计

- **总测试数**: $TOTAL_TESTS
- **通过测试**: $PASSED_TESTS
- **失败测试**: $FAILED_TESTS
- **跳过测试**: $SKIPPED_TESTS
- **成功率**: ${success_rate}%
- **测试覆盖率**: ${COVERAGE_PERCENT}%

## 测试结果详情

"

    # 添加测试结果详情
    if [[ ${#TEST_RESULTS[@]} -gt 0 ]]; then
        report_content+="### 测试结果清单

"

        for result in "${TEST_RESULTS[@]}"; do
            local status=$(echo "$result" | cut -d: -f1)
            local test_name=$(echo "$result" | cut -d: -f2)
            local duration=$(echo "$result" | cut -d: -f3)
            local exit_code=$(echo "$result" | cut -d: -f4)

            if [[ "$status" == "PASS" ]]; then
                report_content+="- ✅ $test_name (${duration}s)\n"
            else
                report_content+="- ❌ $test_name (${duration}s) - 退出码: $exit_code\n"
            fi
        done
    fi

    # 添加性能测试结果
    if [[ ${#PERFORMANCE_RESULTS[@]} -gt 0 ]]; then
        report_content+="
### 性能测试结果

"
        for result in "${PERFORMANCE_RESULTS[@]}"; do
            local test_name=$(echo "$result" | cut -d: -f1)
            local value=$(echo "$result" | cut -d: -f2)
            local status=$(echo "$result" | cut -d: -f3)

            if [[ "$status" == "PASS" ]]; then
                report_content+="- ✅ $test_name: ${value}s\n"
            else
                report_content+="- ❌ $test_name: ${value}s\n"
            fi
        done
    fi

    # 添加失败测试详情
    if [[ ${#FAILED_TEST_NAMES[@]} -gt 0 ]]; then
        report_content+="
## 失败的测试

"
        for failed_test in "${FAILED_TEST_NAMES[@]}"; do
            report_content+="- $failed_test\n"
        done
    fi

    # 添加建议
    report_content+="
## 测试建议

"

    if [[ $FAILED_TESTS -gt 0 ]]; then
        report_content+="⚠️ **发现问题**: 检测到 $FAILED_TESTS 个测试失败，建议立即修复。\n\n"
    fi

    if [[ ${COVERAGE_PERCENT} -lt 80 ]]; then
        report_content+="📊 **覆盖率不足**: 当前测试覆盖率为 ${COVERAGE_PERCENT}%，建议提高到 80% 以上。\n\n"
    fi

    if [[ $success_rate -lt 90 ]]; then
        report_content+="🎯 **成功率偏低**: 当前成功率为 ${success_rate}%，建议提高到 90% 以上。\n\n"
    fi

    report_content+="### 下一步行动
1. 修复所有失败的测试
2. 提高测试覆盖率
3. 添加更多边界条件测试
4. 定期运行回归测试
5. 集成到 CI/CD 流程

---

*此报告由 QQClub Test 工具自动生成*
"

    # 写入报告文件
    echo -e "$report_content" > "$REPORT_FILE"
    log_success "测试报告已生成: $REPORT_FILE"
}

# 显示测试统计
show_test_statistics() {
    echo
    echo "==================================="
    echo -e "${WHITE}🧪 测试统计${NC}"
    echo "==================================="
    echo -e "总测试数: ${BLUE}$TOTAL_TESTS${NC}"
    echo -e "通过测试: ${GREEN}$PASSED_TESTS${NC}"
    echo -e "失败测试: ${RED}$FAILED_TESTS${NC}"
    echo -e "跳过测试: ${YELLOW}$SKIPPED_TESTS${NC}"

    local success_rate=0
    if [[ $TOTAL_TESTS -gt 0 ]]; then
        success_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
    fi

    echo -e "成功率: ${CYAN}$success_rate%${NC}"

    if [[ "$COVERAGE" == "true" ]]; then
        echo -e "测试覆盖率: ${CYAN}${COVERAGE_PERCENT}%${NC}"
    fi

    echo "==================================="

    if [[ $FAILED_TESTS -gt 0 ]]; then
        echo
        log_warning "发现 $FAILED_TESTS 个测试失败，请查看详细报告"
        return 1
    else
        echo
        log_success "所有测试通过！"
        return 0
    fi
}

# 主函数
main() {
    echo
    log_info "🧪 QQClub Test - 项目测试执行工具"
    echo "=================================================="
    echo

    # 解析命令行参数
    parse_arguments "$@"

    log_info "项目根目录: $PROJECT_ROOT"
    log_info "API根目录: $API_ROOT"
    log_info "API服务器: $API_URL"
    log_info "测试类型: $TEST_TYPE"

    # 检查测试环境
    check_test_environment

    # 根据测试类型执行相应的测试
    case "$TEST_TYPE" in
        models)
            log_step "运行模型测试..."
            cd "$API_ROOT"
            local coverage_flag=""
            if [[ "$COVERAGE" == "true" ]]; then
                coverage_flag="COVERAGE=true"
            fi
            if [[ "$PARALLEL" == "true" ]]; then
                log_info "执行: $coverage_flag bundle exec rails test test/models --parallel"
                eval "$coverage_flag bundle exec rails test test/models --parallel"
            else
                log_info "执行: $coverage_flag bundle exec rails test test/models"
                eval "$coverage_flag bundle exec rails test test/models"
            fi
            if [[ $? -eq 0 ]]; then
                log_success "模型测试完成"
            else
                log_error "模型测试失败"
                ((FAILED_TESTS++))
            fi
            ;;
        api)
            run_api_tests
            ;;
        permissions)
            run_permission_tests
            ;;
        controllers)
            log_step "运行控制器测试..."
            cd "$API_ROOT"
            local coverage_flag=""
            if [[ "$COVERAGE" == "true" ]]; then
                coverage_flag="COVERAGE=true"
            fi
            if [[ "$PARALLEL" == "true" ]]; then
                log_info "执行: $coverage_flag bundle exec rails test test/controllers --parallel"
                eval "$coverage_flag bundle exec rails test test/controllers --parallel"
            else
                log_info "执行: $coverage_flag bundle exec rails test test/controllers"
                eval "$coverage_flag bundle exec rails test test/controllers"
            fi
            if [[ $? -eq 0 ]]; then
                log_success "控制器测试完成"
            else
                log_error "控制器测试失败"
                ((FAILED_TESTS++))
            fi
            ;;
        quick)
            log_info "执行快速功能检查..."
            if [[ -f "$SCRIPT_DIR/qq-test-quick.sh" ]]; then
                API_URL="$API_URL" "$SCRIPT_DIR/qq-test-quick.sh"
            else
                log_error "快速测试脚本不存在"
                ((FAILED_TESTS++))
            fi
            ;;
        diagnose)
            log_step "运行详细诊断测试..."
            # 运行完整测试集
            log_step "运行模型测试..."
            cd "$API_ROOT"
            local coverage_flag="COVERAGE=true"
            if [[ "$PARALLEL" == "true" ]]; then
                log_info "执行: $coverage_flag bundle exec rails test test/models --parallel"
                eval "$coverage_flag bundle exec rails test test/models --parallel"
            else
                log_info "执行: $coverage_flag bundle exec rails test test/models"
                eval "$coverage_flag bundle exec rails test test/models"
            fi

            log_step "运行控制器测试..."
            if [[ "$PARALLEL" == "true" ]]; then
                log_info "执行: $coverage_flag bundle exec rails test test/controllers --parallel"
                eval "$coverage_flag bundle exec rails test test/controllers --parallel"
            else
                log_info "执行: $coverage_flag bundle exec rails test test/controllers"
                eval "$coverage_flag bundle exec rails test test/controllers"
            fi

            log_step "运行完整API测试..."
            PERFORMANCE_TEST=true run_api_tests

            log_step "运行权限测试..."
            run_permission_tests

            log_step "运行性能测试..."
            PERFORMANCE_TEST=true run_performance_tests
            ;;
        all)
            log_step "运行模型测试..."
            cd "$API_ROOT"
            local coverage_flag=""
            if [[ "$COVERAGE" == "true" ]]; then
                coverage_flag="COVERAGE=true"
            fi
            log_info "执行: $coverage_flag bundle exec rails test test/models"
            eval "$coverage_flag bundle exec rails test test/models"

            log_step "运行API测试..."
            run_api_tests

            log_step "运行权限测试..."
            run_permission_tests
            ;;
    esac

    # 运行覆盖率测试
    run_coverage_tests

    # 生成报告
    generate_test_report

    # 显示统计信息
    show_test_statistics
}

# 脚本入口点
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi