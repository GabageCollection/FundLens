# 阶段三: 首页资产总览 — 实现计划

> **For agentic workers:** 使用 superpowers:subagent-driven-development 按任务逐步执行。

**目标:** 构建核心看板页面，展示 10 个 KPI 指标卡片 + 6 个 Plotly 图表，一页看清资产全貌。

**架构:** 4 个新工具模块（analyzer / benchmarks / charts / ui_components）+ 1 个首页页面，依次依赖。analyzer 提供纯数据计算，benchmarks 处理基准对比，charts 封装 Plotly 图表，ui_components 提供 KPI 卡片组件，overview 页面将它们组装成完整看板。

**技术栈:** Python 3.10+ / Pandas / Plotly / Streamlit

**测试策略:** 每个模块写 pytest 单元测试，最后用 Playwright 端到端验证首页渲染和数值一致性。

---
