/// Central registry of user-facing Chinese copy.
///
/// The copy boundary test scans this list (and all `lib/` sources) for
/// forbidden wording: allocation advice, transaction verbs and return
/// mislabeling are never allowed. Add new user-facing strings here when a
/// feature introduces them.
library;

const allChineseCopy = <String>[
  // Six fixed destinations.
  '资产总览',
  '资产分析',
  '全部持仓',
  '历史快照',
  '导入与识别',
  '设置与备份',
  // Common actions.
  '添加持仓',
  '编辑持仓',
  '删除持仓',
  '新建快照',
  '删除快照',
  '取消',
  '确定',
  '保存',
  '删除',
  '确认',
  '数据状态',
  '导入 CSV',
  '导入 Excel',
  '导入截图',
  '确认写入',
  '写入完成',
  // Holdings grid and editor.
  '产品名称',
  '当前金额',
  '搜索名称或代码',
  '组合',
  '交易',
  '平台',
  '暂无持仓',
  '添加第一项资产',
  '请输入产品名称',
  '请输入当前金额',
  '保存后该持仓标记为手工录入，字段来源记为你确认的值。',
  // Analysis and snapshots (factual wording only).
  '资产类别',
  '产品类型',
  '来源平台',
  '资产金额变化',
  '资产类别变化',
  '持仓变化',
  '至少需要两个快照才能比较',
  '还没有快照',
  '行情新鲜度：无自动行情持仓',
  // Import review.
  '支付宝截图',
  '同花顺截图',
  '部分持仓',
  '全量持仓',
  '确认全量写入',
  '置信度',
  // Settings.
  '结构阈值',
  '阈值完全可选；未设置时资产分析只显示实际值，不做判断。',
  '添加结构阈值',
  '由你设置，仅用于结构提示',
  '单一持仓占比上限',
  '单一类别占比上限',
  '现金及存款占比下限',
  '权益仓位占比上限',
  '行情与数据',
  '每日自动刷新',
  '手动刷新行情',
  '行情引擎不可用，显示的是最近一次估值',
  '隐私与安全',
  '所有数据仅在本机处理，不上传服务器。',
  '导入截图的临时副本在写入成功或取消后自动清除。',
  '日志中的路径与敏感信息经过脱敏处理。',
  '加密备份',
  '备份文件使用与数据库相同的密钥加密，仅保存在你选择的位置。此功能将在后续版本提供。',
];
