// FundLens Sample Data — 2026Q1 snapshot (8 products across Alipay + Tonghuashun)
// Based on the design document's example data table (§13.4)

const SAMPLE_DATA = [
  {
    statistic_date: '2026-03-31',
    platform: '支付宝',
    account_name: '主账户',
    asset_class: '固收类',
    product_type: '纯债基金',
    market_region: '中国内地',
    product_name: 'XX纯债债券A',
    product_code: '000001',
    currency: 'CNY',
    current_value: 12000,
    cost_amount: 11500,
    shares: null,
    current_price: null,
    cost_price: null,
    risk_level: '中低',
    usage_purpose: '稳健',
    annual_fee_rate: 0.008,
    underlying_equity_pct: 0,
    top3_industries: '',
    liquidity: '高',
    remark: '长期持有'
  },
  {
    statistic_date: '2026-03-31',
    platform: '支付宝',
    account_name: '主账户',
    asset_class: '固收增强类',
    product_type: '固收+',
    market_region: '中国内地',
    product_name: 'XX稳健收益混合',
    product_code: '000002',
    currency: 'CNY',
    current_value: 8000,
    cost_amount: 7900,
    shares: null,
    current_price: null,
    cost_price: null,
    risk_level: '中',
    usage_purpose: '稳健',
    annual_fee_rate: 0.012,
    underlying_equity_pct: 15,
    top3_industries: '金融, 消费',
    liquidity: '中',
    remark: ''
  },
  {
    statistic_date: '2026-03-31',
    platform: '支付宝',
    account_name: '主账户',
    asset_class: '跨境类',
    product_type: 'QDII',
    market_region: '美国',
    product_name: 'XX海外收益基金',
    product_code: '000003',
    currency: 'CNY',
    current_value: 5000,
    cost_amount: 4800,
    shares: null,
    current_price: null,
    cost_price: null,
    risk_level: '中高',
    usage_purpose: '长期',
    annual_fee_rate: 0.015,
    underlying_equity_pct: 80,
    top3_industries: '科技, 消费, 医疗',
    liquidity: '中',
    remark: ''
  },
  {
    statistic_date: '2026-03-31',
    platform: '支付宝',
    account_name: '主账户',
    asset_class: '权益类',
    product_type: '行业基金',
    market_region: '中国内地',
    product_name: 'XX新能源基金',
    product_code: '000004',
    currency: 'CNY',
    current_value: 6000,
    cost_amount: 7000,
    shares: null,
    current_price: null,
    cost_price: null,
    risk_level: '高',
    usage_purpose: '长期',
    annual_fee_rate: 0.015,
    underlying_equity_pct: 95,
    top3_industries: '电力设备, 有色, 化工',
    liquidity: '高',
    remark: ''
  },
  {
    statistic_date: '2026-03-31',
    platform: '支付宝',
    account_name: '主账户',
    asset_class: '现金类',
    product_type: '余利宝',
    market_region: '中国内地',
    product_name: '余利宝',
    product_code: '',
    currency: 'CNY',
    current_value: 10000,
    cost_amount: null,
    shares: null,
    current_price: null,
    cost_price: null,
    risk_level: '低',
    usage_purpose: '活钱',
    annual_fee_rate: 0,
    underlying_equity_pct: 0,
    top3_industries: '',
    liquidity: '高',
    remark: ''
  },
  {
    statistic_date: '2026-03-31',
    platform: '同花顺',
    account_name: '主账户',
    asset_class: '权益类',
    product_type: '宽基 ETF',
    market_region: '中国内地',
    product_name: '沪深300ETF',
    product_code: '510300',
    currency: 'CNY',
    current_value: 15000,
    cost_amount: 14000,
    shares: 3500,
    current_price: 4.2857,
    cost_price: 4.0,
    risk_level: '中高',
    usage_purpose: '长期',
    annual_fee_rate: 0.005,
    underlying_equity_pct: 100,
    top3_industries: '金融, 食品饮料, 电子',
    liquidity: '高',
    remark: ''
  },
  {
    statistic_date: '2026-03-31',
    platform: '同花顺',
    account_name: '主账户',
    asset_class: '权益类',
    product_type: '行业 ETF',
    market_region: '中国内地',
    product_name: '证券ETF',
    product_code: '512880',
    currency: 'CNY',
    current_value: 6000,
    cost_amount: 6500,
    shares: 5000,
    current_price: 1.2,
    cost_price: 1.3,
    risk_level: '高',
    usage_purpose: '长期',
    annual_fee_rate: 0.005,
    underlying_equity_pct: 100,
    top3_industries: '非银金融',
    liquidity: '高',
    remark: ''
  },
  {
    statistic_date: '2026-03-31',
    platform: '同花顺',
    account_name: '主账户',
    asset_class: '跨境类',
    product_type: '跨境 ETF',
    market_region: '美国',
    product_name: '纳指ETF',
    product_code: '513100',
    currency: 'CNY',
    current_value: 9000,
    cost_amount: 8000,
    shares: 2000,
    current_price: 4.5,
    cost_price: 4.0,
    risk_level: '中高',
    usage_purpose: '长期',
    annual_fee_rate: 0.006,
    underlying_equity_pct: 100,
    top3_industries: '科技, 通信, 消费',
    liquidity: '高',
    remark: ''
  }
];

// ─── Computed fields (added at load time) ──────────────────

SAMPLE_DATA.forEach(row => {
  if (row.cost_amount != null && row.cost_amount > 0) {
    row.holding_profit = row.current_value - row.cost_amount;
    row.holding_return = row.holding_profit / row.cost_amount;
  } else {
    row.holding_profit = null;
    row.holding_return = null;
  }
});

// ─── Aggregate metrics ─────────────────────────────────────

function computeMetrics(data) {
  const totalAssets = data.reduce((s, r) => s + r.current_value, 0);
  const withCost = data.filter(r => r.cost_amount != null && r.cost_amount > 0);
  const totalCost = withCost.reduce((s, r) => s + r.cost_amount, 0);
  const totalProfit = withCost.reduce((s, r) => s + (r.holding_profit || 0), 0);
  const totalReturn = totalCost > 0 ? totalProfit / totalCost : 0;
  const coveredAmount = withCost.reduce((s, r) => s + r.current_value, 0);
  const coverage = totalAssets > 0 ? coveredAmount / totalAssets : 0;

  const platforms = [...new Set(data.map(r => r.platform))];
  const productCount = data.length;
  const maxSingle = Math.max(...data.map(r => r.current_value / totalAssets));

  const byClass = {};
  data.forEach(r => {
    byClass[r.asset_class] = (byClass[r.asset_class] || 0) + r.current_value;
  });
  const equityRatio = (byClass['权益类'] || 0) / totalAssets;

  return {
    totalAssets,
    totalCost,
    totalProfit,
    totalReturn,
    coverage,
    coveredAmount,
    platformCount: platforms.length,
    productCount,
    maxSingle,
    maxSingleName: data.reduce((a, b) => a.current_value > b.current_value ? a : b).product_name,
    equityRatio,
    byClass,
    platforms
  };
}

// ─── Benchmark config ──────────────────────────────────────

const BENCHMARK_CONFIG = {
  name: '沪深300',
  start_value: 3500,
  end_value: 3850,
  get return_rate() {
    return (this.end_value - this.start_value) / this.start_value;
  }
};

// ─── Target allocation config ──────────────────────────────

const TARGET_ALLOCATION = {
  '现金类': 0.10,
  '固收类': 0.40,
  '固收增强类': 0.10,
  '权益类': 0.30,
  '跨境类': 0.10
  // '其他类' not set
};

// ─── Grouping helpers ──────────────────────────────────────

function groupBy(data, key) {
  const groups = {};
  data.forEach(row => {
    const k = row[key] || '未分类';
    if (!groups[k]) groups[k] = { current_value: 0, cost_amount: 0, holding_profit: 0, count: 0, items: [] };
    groups[k].current_value += row.current_value;
    groups[k].cost_amount += (row.cost_amount || 0);
    groups[k].holding_profit += (row.holding_profit || 0);
    groups[k].count++;
    groups[k].items.push(row);
  });
  return groups;
}

function sortGroups(groups, byField = 'current_value') {
  return Object.entries(groups)
    .map(([name, data]) => ({ name, ...data }))
    .sort((a, b) => b[byField] - a[byField]);
}
