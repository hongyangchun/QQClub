#!/bin/bash

# QQClub Quick Test - 快速功能检查
# 用于开发过程中的快速验证

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# 项目路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
API_ROOT="$PROJECT_ROOT/qqclub_api"
API_URL="${API_URL:-http://localhost:3000}"

# 日志函数
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_test() { echo -e "${WHITE}[TEST]${NC} $1"; }

# 测试统计
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# 显示标题
echo -e "${CYAN}🛠️  QQClub 快速功能检查${NC}"
echo -e "${CYAN}========================${NC}"
echo

# 1. 检查项目环境
log_info "检查项目环境..."

if [[ ! -d "$API_ROOT" ]]; then
    log_error "找不到API目录: $API_ROOT"
    exit 1
fi

cd "$API_ROOT"

# 检查Ruby和Bundler
if ! command -v ruby &> /dev/null; then
    log_error "Ruby未安装"
    exit 1
fi

if ! command -v bundle &> /dev/null; then
    log_error "Bundler未安装"
    exit 1
fi

log_success "环境检查通过"

# 2. 检查依赖
log_info "检查依赖..."
if ! bundle check > /dev/null 2>&1; then
    log_warning "安装缺失的依赖..."
    bundle install --quiet
fi
log_success "依赖检查通过"

# 3. 检查数据库
log_info "检查数据库连接..."
if ! bundle exec rails runner "ActiveRecord::Base.connection.execute('SELECT 1')" > /dev/null 2>&1; then
    log_error "数据库连接失败"
    exit 1
fi
log_success "数据库连接正常"

# 4. 检查API服务器
log_info "检查API服务器状态..."
if ! curl -s "$API_URL/api/health" > /dev/null 2>&1; then
    log_warning "API服务器未运行，尝试启动..."

    # 检查端口占用
    if lsof -ti:3000 > /dev/null 2>&1; then
        log_info "端口3000已被占用，尝试停止现有服务..."
        pkill -f "rails server" || true
        sleep 2
    fi

    # 启动服务器
    bundle exec rails server -p 3000 -d > /dev/null 2>&1

    # 等待服务器启动
    local retries=10
    while [[ $retries -gt 0 ]]; do
        if curl -s "$API_URL/api/health" > /dev/null 2>&1; then
            break
        fi
        sleep 1
        ((retries--))
    done

    if [[ $retries -eq 0 ]]; then
        log_error "API服务器启动失败"
        exit 1
    fi
fi
log_success "API服务器运行正常"

# 5. 快速API功能测试
echo
log_info "执行快速API功能测试..."
echo

# 测试函数
run_quick_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_code="${3:-200}"

    log_test "$test_name"
    ((TOTAL_TESTS++))

    local response_code=$(eval "$test_command" -o /dev/null -w '%{http_code}')

    if [[ "$response_code" == "$expected_code" ]]; then
        log_success "✓ 通过"
        ((PASSED_TESTS++))
    else
        log_error "✗ 失败 (HTTP $response_code)"
        ((FAILED_TESTS++))
    fi
}

# 基础端点测试
run_quick_test "健康检查" "curl -s '$API_URL/api/health'"
run_quick_test "模拟登录" "curl -s -X POST '$API_URL/api/auth/mock_login' -H 'Content-Type: application/json' -d '{\"user\":{\"nickname\":\"快速测试\",\"wx_openid\":\"quick_test_001\"}}'"
run_quick_test "获取帖子列表" "curl -s '$API_URL/api/posts'" "401"  # 需要认证

# 使用测试用户token
local test_token=$(curl -s -X POST "$API_URL/api/auth/mock_login" \
    -H "Content-Type: application/json" \
    -d '{"user":{"wx_openid":"quick_test_user","nickname":"快速测试用户"}}' | \
    jq -r '.token // empty')

if [[ -n "$test_token" ]]; then
    run_quick_test "认证获取帖子列表" "curl -s '$API_URL/api/posts' -H 'Authorization: Bearer $test_token'"

    # 测试创建帖子
    run_quick_test "创建测试帖子" "curl -s -X POST '$API_URL/api/posts' \
        -H 'Authorization: Bearer $test_token' \
        -H 'Content-Type: application/json' \
        -d '{\"post\":{\"title\":\"快速测试帖子\",\"content\":\"这是一个快速测试创建的帖子，用于验证基础功能。\"}}'"
else
    log_error "无法获取测试token，跳过认证测试"
fi

# 6. 检查核心功能
echo
log_info "检查核心功能..."

# 检查模型
log_test "检查数据模型..."
if bundle exec rails runner "User.count; Post.count" > /dev/null 2>&1; then
    log_success "✓ 数据模型正常"
    ((PASSED_TESTS++))
else
    log_error "✗ 数据模型异常"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

# 7. 显示结果
echo
echo -e "${CYAN}========================${NC}"
echo -e "${WHITE}🧪 快速检查结果${NC}"
echo -e "${CYAN}========================${NC}"
echo -e "总测试数: ${BLUE}$TOTAL_TESTS${NC}"
echo -e "通过测试: ${GREEN}$PASSED_TESTS${NC}"
echo -e "失败测试: ${RED}$FAILED_TESTS${NC}"

local success_rate=0
if [[ $TOTAL_TESTS -gt 0 ]]; then
    success_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
fi

echo -e "成功率: ${CYAN}$success_rate%${NC}"
echo

if [[ $FAILED_TESTS -eq 0 ]]; then
    log_success "🎉 所有检查通过！系统运行正常。"
    exit 0
else
    log_warning "⚠️  发现 $FAILED_TESTS 个问题，建议进行详细测试。"
    echo
    echo -e "${YELLOW}建议操作：${NC}"
    echo "  - 运行完整测试: /qq-test api"
    echo "  - 查看详细日志: /qq-test api --verbose"
    echo "  - 尝试修复问题: /qq-test --fix-issues"
    exit 1
fi