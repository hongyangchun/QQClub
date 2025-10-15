# QQClub Permissions - QQClub 权限系统检查命令

这个命令专门用于验证 QQClub 项目的 3 层权限体系是否正确实现和运行。

## 执行流程

### 1. 权限架构验证
验证权限系统的基本架构：
- 检查 3 层权限结构是否完整
- 验证 6 种用户角色定义
- 确认权限矩阵的正确性

### 2. 角色权限测试
针对每种角色进行权限测试：

#### 2.1 Admin Level 测试
**Root 用户权限**：
- 创建和管理 Root 用户
- 系统管理功能访问
- 用户角色管理权限
- 系统配置管理

**Admin 用户权限**：
- 活动审批权限
- 论坛内容管理
- 用户信息查看
- 统计数据访问

#### 2.2 Event Level 测试
**Group Leader 权限**：
- 活动创建和管理
- 阅读计划制定
- 全程领读内容管理
- 参与者管理权限

**Daily Leader 权限**：
- 3 天时间窗口权限验证
  - 前一天：发布领读内容权限
  - 当天：打卡管理权限
  - 后一天：小红花评选权限
- 备份机制验证

#### 2.3 User Level 测试
**Forum User 权限**：
- 论坛发帖和评论
- 个人内容编辑
- 基础信息查看

**Participant 权限**：
- 活动报名和参与
- 个人打卡提交
- 小红花赠送

### 3. 时间窗口权限验证
重点验证领读人的时间窗口机制：

#### 3.1 权限窗口计算
```ruby
# 验证权限窗口逻辑
def can_manage_event_content?(event, schedule)
  permission_window = 1.day
  schedule_date = schedule.date

  # 检查前一天、当天、后一天的权限
  return true if Date.current >= (schedule_date - permission_window)
  return true if Date.current <= (schedule_date + permission_window)
end
```

#### 3.2 边界条件测试
- 权限窗口边界的精确性
- 跨日期权限处理
- 时区相关的权限计算

### 4. 备份机制测试
验证 Group Leader 的补位功能：
- 领读内容缺失检测
- 自动补位权限验证
- 权限优先级确认

### 5. 安全性测试
测试权限系统的安全性：

#### 5.1 权限越界测试
- 普通用户尝试管理员操作
- 跨角色权限访问尝试
- 无效权限提升尝试

#### 5.2 Token 安全测试
- Token 过期处理
- 无效 Token 拒绝
- 权限刷新机制

## 测试用例

### 基础权限验证
```bash
#!/bin/bash
# 创建不同角色的测试用户
echo "创建测试用户..."

# Root 用户
ROOT_TOKEN=$(curl -s -X POST http://localhost:3000/api/admin/init_root \
  -H "Content-Type: application/json" \
  -d '{"root":{"nickname":"Root用户","wx_openid":"root_test_001"}}' | jq -r '.token')

# Admin 用户
ADMIN_TOKEN=$(curl -s -X POST http://localhost:3000/api/auth/mock_login \
  -H "Content-Type: application/json" \
  -d '{"nickname":"Admin用户","wx_openid":"admin_test_001"}' | jq -r '.token')

# 普通用户
USER_TOKEN=$(curl -s -X POST http://localhost:3000/api/auth/mock_login \
  -H "Content-Type: application/json" \
  -d '{"nickname":"普通用户","wx_openid":"user_test_001"}' | jq -r '.token')

echo "测试用户创建完成"
```

### 权限矩阵验证
```bash
# 测试管理员权限
curl -X GET http://localhost:3000/api/admin/dashboard \
  -H "Authorization: Bearer $ROOT_TOKEN"  # 应该成功

curl -X GET http://localhost:3000/api/admin/dashboard \
  -H "Authorization: Bearer $USER_TOKEN"   # 应该失败

# 测试论坛管理权限
curl -X POST http://localhost:3000/api/posts/1/pin \
  -H "Authorization: Bearer $ADMIN_TOKEN"  # 应该成功

curl -X POST http://localhost:3000/api/posts/1/pin \
  -H "Authorization: Bearer $USER_TOKEN"   # 应该失败
```

### 时间窗口权限测试
```bash
# 创建测试活动和阅读计划
EVENT_ID=$(curl -s -X POST http://localhost:3000/api/events \
  -H "Authorization: Bearer $USER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"event":{"title":"权限测试活动","book_name":"测试书籍","start_date":"2025-10-20","end_date":"2025-10-25"}}' | jq -r '.id')

# 创建不同日期的阅读计划
# 测试领读人在不同日期的权限
```

## 权限检查清单

### Admin Level 权限检查
- [ ] Root 用户可以创建和管理其他用户
- [ ] Admin 用户可以审批活动
- [ ] Admin 用户可以管理论坛内容
- [ ] Admin 用户不能管理系统配置（Root专有）

### Event Level 权限检查
- [ ] Group Leader 可以创建和管理自己的活动
- [ ] Group Leader 可以全程管理领读内容
- [ ] Daily Leader 只有 3 天权限窗口
- [ ] 时间窗口权限计算正确
- [ ] 备份机制正常工作

### User Level 权限检查
- [ ] Forum User 可以发帖和评论
- [ ] Participant 可以报名和打卡
- [ ] 用户只能编辑自己的内容
- [ ] 权限边界清晰不可越界

### 安全性检查
- [ ] Token 验证机制正常
- [ ] 权限拒绝处理正确
- [ ] 错误信息不泄露敏感信息
- [ ] 日志记录完整

## 问题诊断

### 常见权限问题
1. **权限检查逻辑错误**
   - 权限验证方法实现错误
   - 角色判断逻辑有误
   - 时间窗口计算错误

2. **数据库权限配置错误**
   - 用户角色字段值错误
   - 权限相关索引缺失
   - 外键约束配置问题

3. **API 权限控制遗漏**
   - 某些端点缺少权限验证
   - 权限检查顺序错误
   - 错误处理不完整

### 调试方法
```ruby
# 在 Rails console 中调试权限
user = User.find_by(wx_openid: "test_user_001")
user.role
user.can_approve_events?
user.can_manage_users?

# 检查具体权限逻辑
event = ReadingEvent.first
user.can_manage_event_content?(event, event.reading_schedules.first)
```

## 权限报告生成

生成权限系统检查报告：
- **权限架构概览**: 当前权限体系结构
- **角色权限矩阵**: 各角色的具体权限
- **测试结果汇总**: 权限测试的通过情况
- **安全评估**: 权限系统的安全性分析
- **改进建议**: 权限系统的优化建议

## 最佳实践

### 权限设计原则
1. **最小权限原则**: 每个角色只拥有必要的权限
2. **权限分离**: 不同权限职责分离
3. **可审计性**: 权限操作有完整日志
4. **易于理解**: 权限逻辑清晰易懂

### 代码实现建议
1. **使用 Concerns**: 权限验证逻辑模块化
2. **统一权限检查**: 避免权限验证代码分散
3. **测试覆盖**: 确保所有权限路径都有测试
4. **文档同步**: 权限变更及时更新文档

---

这个命令确保 QQClub 的权限系统始终安全、可靠、符合设计要求，是保障系统安全性的重要工具。