"""基准对比模块 — 基准收益率计算、相对收益、配置读写。

按项目规范，不直接调用 st.* API，通过参数接收 session_state 字典。
"""


def load_benchmark_config(session_state: dict) -> dict:
    """从 session_state 加载基准配置，未配置时返回空默认值。"""
    return session_state.get(
        "benchmark_config",
        {"name": "", "start_value": None, "end_value": None},
    )


def save_benchmark_config(session_state: dict, name: str, start: float, end: float) -> dict:
    """保存基准配置到 session_state 并返回。"""
    session_state["benchmark_config"] = {
        "name": name,
        "start_value": float(start),
        "end_value": float(end),
    }
    return session_state["benchmark_config"]


def calc_benchmark_return(config: dict) -> float:
    """计算基准收益率 = (期末值 - 期初值) / 期初值。"""
    start = config.get("start_value")
    end = config.get("end_value")
    if start is None or end is None or start == 0:
        return 0.0
    return (float(end) - float(start)) / float(start)


def calc_relative_return(portfolio_return: float, benchmark_return: float) -> float:
    """相对收益 = 组合收益率 - 基准收益率。正值表示跑赢。"""
    return portfolio_return - benchmark_return
