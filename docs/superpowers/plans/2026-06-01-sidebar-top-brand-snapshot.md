# 侧边栏顶部品牌与快照选择器实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让侧边栏顶部固定显示 FundLens、"多平台资产快照分析" 和快照 Excel 选择框，且它们位于页面导航之前。

**Architecture:** Streamlit 的 `st.navigation(..., position="sidebar")` 会渲染内置导航区域，可能出现在自定义 sidebar 内容之前。改为 `position="hidden"` 隐藏内置导航，并用 `st.sidebar.page_link` 在自定义顶部区域之后手动渲染导航链接，从而完全控制侧边栏顺序。

**Tech Stack:** Python 3.10+ / Streamlit 1.58 / `st.Page` / `st.navigation` / `st.sidebar.page_link`

---

### Task 1: 固定侧边栏顶部区域

**Files:**
- Modify: `app.py:70-152`

- [ ] **Step 1: 记录当前失败现象**

在浏览器中打开应用，观察侧边栏顺序。如果 `FundLens`、`多平台资产快照分析`、快照选择框出现在页面导航下方，则说明 Streamlit 内置导航优先渲染导致自定义 sidebar 内容没有位于最顶部。

- [ ] **Step 2: 隐藏内置导航**

将 `app.py` 入口中的导航从：

```python
pg = st.navigation(pages)
```

改为：

```python
pg = st.navigation(pages, position="hidden")
```

- [ ] **Step 3: 手动渲染页面导航**

在 `_render_sidebar()` 的快照选择器之后添加：

```python
    st.sidebar.markdown('<div style="height:var(--space-4);"></div>', unsafe_allow_html=True)
    st.sidebar.page_link("pages/1_🏠_首页概览.py", label="首页概览", icon="🏠", width="stretch")
    st.sidebar.page_link("pages/2_📊_资产配置.py", label="资产配置", icon="📊", width="stretch")
    st.sidebar.page_link("pages/3_📈_收益分析.py", label="收益分析", icon="📈", width="stretch")
    st.sidebar.page_link("pages/4_📋_产品明细.py", label="产品明细", icon="📋", width="stretch")
    st.sidebar.page_link("pages/5_📥_数据导入.py", label="数据导入", icon="📥", width="stretch")
    st.sidebar.page_link("pages/6_🔍_数据校验.py", label="数据校验", icon="🔍", width="stretch")
    st.sidebar.page_link("pages/7_⚙️_设置.py", label="设置", icon="⚙️", width="stretch")
```

- [ ] **Step 4: 确认代码顺序**

`__main__` 中保持：

```python
_inject_css_and_js()
_init_session_state()
_render_sidebar()
pg = st.navigation(pages, position="hidden")
pg.run()
```

这样 `_render_sidebar()` 的内容会先进入侧边栏，隐藏的 `st.navigation` 不再插入内置导航块。

### Task 2: 验证侧边栏布局

**Files:**
- Verify: `app.py`

- [ ] **Step 1: 启动应用**

Run:

```bash
streamlit run app.py --server.headless true
```

Expected: Streamlit 正常启动并监听 `http://localhost:8501`。

- [ ] **Step 2: 检查健康状态**

Run:

```bash
curl -s http://localhost:8501/_stcore/health
```

Expected:

```text
ok
```

- [ ] **Step 3: 浏览器人工确认**

打开 `http://localhost:8501`，侧边栏从上到下应为：

```text
FundLens
多平台资产快照分析
快照选择框
首页概览
资产配置
收益分析
产品明细
数据导入
数据校验
设置
所有数据仅在本地处理 / 不上传至任何外部服务器
```

- [ ] **Step 4: 确认 app 页面未恢复**

侧边栏导航中不应出现名为 `app` 的页面。

---

## Self-Review

- Spec coverage: 覆盖用户要求的三个顶部板块：`FundLens`、`多平台资产快照分析`、快照 Excel 选择框。
- Placeholder scan: 无 TBD/TODO/占位内容。
- Type/API consistency: `st.navigation(position="hidden")` 与本地 Streamlit 1.58 API 签名一致；`st.sidebar.page_link(..., width="stretch")` 与本地 API 签名一致。
