# QQClub 读书社群 - 业务分析文档

## 一、核心角色与权限

### 1. 小组长（Group Leader）
**权限：**
- 创建和管理共读活动
- 规划阅读进度
- 召集和安排领读人
- 统计打卡数据
- 发放小红花奖励
- 管理押金退还

**收益：**
- 当期 20% 报名费

### 2. 领读人（Daily Leader）
**权限：**
- 根据阅读进度提出 2-3 个问题
- 浏览所有打卡作业
- 选出当日 1-3 朵小红花

**规则：**
- 每日轮换，可自主报名
- 领读可代替缺卡（每期建议不超过 3 次）

### 3. 共读人（Participant）
**权限：**
- 参与共读活动
- 每日笔记打卡
- 查看他人作业
- 获得小红花奖励

**规则：**
- 报名费 100 元（20% 服务费 + 80% 押金）
- 打卡要求：100 字以上，与主题相关
- 截止时间：每日 24 点，可补卡
- 押金退还 = 完成率 × 80%

---

## 二、核心业务流程

### 流程 1：活动创建
```
1. 小组长确定书目
2. 规划日程和阅读进度（建议 20-30 页/天）
3. 发布活动，开放报名（15-30 人）
4. 收集报名费（100 元/人）
5. 召集领读人占位
6. 活动正式开始
```

### 流程 2：每日共读循环
```
1. 当日领读人发布领读内容（使用模板）：
   - 阅读进度建议
   - 2-3 个领读问题
   - 打卡要求和截止时间

2. 共读人在 24 点前完成打卡：
   - 笔记内容 ≥ 100 字
   - 与主题相关，不得复制粘贴

3. 次日领读人浏览打卡作业：
   - 选出 1-3 朵小红花
   - 转发到微信群

4. 轮换到下一位领读人
```

### 流程 3：活动结束
```
1. 小组长统计打卡完成情况
2. 统计小红花获得者（前 3 名）
3. 发放奖品/50 元红包给小红花得主
4. 按比例退还押金给参与者
5. 多余押金进入书友群资金池
```

---

## 三、核心数据模型（初步设计）

### 用户（User）
- 基础信息：姓名、微信 ID、头像等
- 角色：可以是小组长、领读人、共读人（同一用户可承担多个角色）

### 共读活动（ReadingEvent）
- 书籍信息：书名、作者、封面
- 时间：开始日期、结束日期、周期（14-21 天）
- 人数：最小/最大人数（建议 15-30）
- 费用：报名费（默认 100 元）、服务费比例（20%）、押金比例（80%）
- 状态：筹备中、报名中、进行中、已结束
- 小组长：User（创建者）

### 活动报名（Enrollment）
- 关联：User + ReadingEvent
- 角色：共读人（默认）、领读人（可多次）
- 费用：已支付金额、押金状态
- 状态：已报名、进行中、已完成、已退款

### 阅读计划（ReadingSchedule）
- 关联：ReadingEvent
- 日期：第 X 天
- 阅读进度：建议阅读章节/页数
- 领读人：User（可为空，由小组长补位）

### 领读内容（DailyLeading）
- 关联：ReadingSchedule + User（领读人）
- 阅读进度建议：文本
- 领读问题：2-3 个问题（数组或关联表）
- 发布时间

### 打卡记录（CheckIn）
- 关联：User + ReadingSchedule
- 内容：笔记正文（≥ 100 字）
- 提交时间
- 状态：正常打卡、补卡、缺卡
- 是否获得小红花：Boolean

### 小红花（Badge/Flower）
- 关联：CheckIn + User（领读人选出）
- 日期：第 X 天
- 备注：领读人评语（可选）

### 最终统计（EventSummary）
- 关联：ReadingEvent
- 用户打卡统计：总打卡数、完成率
- 小红花统计：各用户获得数量
- 押金退还：计算结果
- 奖励发放：前 3 名小红花得主

---

## 四、技术挑战与考虑

### 1. 权限管理（Authorization）
- 小组长可以管理自己创建的活动
- 领读人可以选小红花（仅限自己领读的那天）
- 用户只能编辑自己的打卡

### 2. 时间相关功能
- 每日 24 点打卡截止（需要时区处理）
- 补卡功能（共读期间可补，需要标记）
- 领读人提前发布（建议前一天晚上或当天早上）

### 3. 统计与计算
- 实时显示打卡完成率
- 自动计算押金退还金额
- 小红花排行榜

### 4. 通知系统（后期功能）
- 每日领读发布提醒
- 打卡截止前提醒
- 小红花获得通知
- 活动结束统计通知

### 5. 支付集成（MVP 可暂时手动）
- 报名费收取
- 押金退还
- 奖品/红包发放
- 小组长服务费结算

---

## 五、MVP（最小可行产品）功能范围

### Phase 1 核心功能（必须有）
1. **用户认证**：注册、登录
2. **活动管理**：
   - 创建活动（小组长）
   - 设置阅读计划
   - 报名参与
3. **领读功能**：
   - 发布领读内容
   - 提出问题
4. **打卡功能**：
   - 提交笔记打卡
   - 查看他人打卡
   - 补卡功能
5. **小红花**：
   - 领读人选出小红花
   - 小红花统计
6. **活动统计**：
   - 打卡完成情况
   - 小红花排行榜

### Phase 2 增强功能（后续迭代）
1. 支付集成（微信支付/支付宝）
2. 邮件/站内通知
3. 社交功能（评论、点赞）
4. 笔记模板（131 笔记法、ABC 目标法）
5. 用户个人资料页（历史参与、小红花墙）
6. 活动历史存档
7. 移动端优化

---

## 六、Rails 技术映射

### Active Record 关联关系
```ruby
User
  has_many :created_events (class_name: 'ReadingEvent', foreign_key: 'leader_id')
  has_many :enrollments
  has_many :reading_events, through: :enrollments
  has_many :check_ins
  has_many :flowers_received (class_name: 'Flower', foreign_key: 'recipient_id')
  has_many :flowers_given (class_name: 'Flower', foreign_key: 'giver_id')

ReadingEvent
  belongs_to :leader, class_name: 'User'
  has_many :enrollments
  has_many :participants, through: :enrollments, source: :user
  has_many :reading_schedules
  has_many :check_ins, through: :reading_schedules

Enrollment
  belongs_to :user
  belongs_to :reading_event
  # 可以追踪：领读次数、打卡完成率、押金状态

ReadingSchedule (每日阅读计划)
  belongs_to :reading_event
  belongs_to :daily_leader, class_name: 'User', optional: true
  has_one :daily_leading
  has_many :check_ins

DailyLeading (领读内容)
  belongs_to :reading_schedule
  belongs_to :leader, class_name: 'User'

CheckIn (打卡记录)
  belongs_to :user
  belongs_to :reading_schedule
  has_one :flower, optional: true

Flower (小红花)
  belongs_to :check_in
  belongs_to :giver, class_name: 'User'  # 领读人
  belongs_to :recipient, class_name: 'User'  # 打卡人
```

### 关键业务逻辑（Service Objects）
- `EventCreationService`：创建活动和阅读计划
- `CheckInService`：验证打卡规则（字数、时间、补卡）
- `FlowerAwardService`：小红花发放
- `EventSummaryService`：活动结束后统计和结算
- `RefundCalculationService`：押金退还计算

---

## 七、下一步行动

现在我们有了清晰的业务逻辑，可以开始构建了！

**建议路径：**
1. ✅ 创建 Rails 项目
2. ✅ 设置用户认证（Rails 8 Authentication Generator）
3. ✅ 创建核心模型（User, ReadingEvent, Enrollment, CheckIn 等）
4. ✅ 实现活动管理功能
5. ✅ 实现领读和打卡功能
6. ✅ 实现小红花和统计功能

你准备好开始了吗？我们从 Phase 1.1 开始！🚀
