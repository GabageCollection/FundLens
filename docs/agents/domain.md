# 领域文档

工程技能探索代码库时，应如何消费本仓库的领域文档。

## 探索前先读

- 仓库根目录的 **`CONTEXT.md`**，或
- 若存在根目录的 **`CONTEXT-MAP.md`**——它指向每个上下文各自的 `CONTEXT.md`，按主题读取相关的每一份。
- **`docs/adr/`**——读取将要工作区域的 ADR。多上下文仓库中，还要检查 `src/<context>/docs/adr/` 下的上下文级决策。

若以上文件不存在，**静默继续**。不要标记缺失，也不要主动建议现在创建。（`/domain-modeling` 技能，经由 `/grill-with-docs` 和 `/improve-codebase-architecture` 触达，会在术语或决策真正落地时懒创建它们。）

## 文件结构

单一上下文仓库（大多数仓库）：

```
/
├── CONTEXT.md
├── docs/adr/
│   ├── 0001-event-sourced-orders.md
│   └── 0002-postgres-for-write-model.md
└── src/
```

多上下文仓库（根目录存在 `CONTEXT-MAP.md`）：

```
/
├── CONTEXT-MAP.md
├── docs/adr/                          ← 系统级决策
└── src/
    ├── ordering/
    │   ├── CONTEXT.md
    │   └── docs/adr/                  ← 上下文级决策
    └── billing/
        ├── CONTEXT.md
        └── docs/adr/
```

## 使用词表的词汇

当输出中出现领域概念时（issue 标题、重构提案、假设、测试名），使用 `CONTEXT.md` 中定义的术语，不要漂移到词表明确避开的同义词。

如果需要的概念尚未在词表中，那是一个信号——要么你在发明项目不用的语言（重新考虑），要么存在真实缺口（记下来交给 `/domain-modeling`）。

## 标注 ADR 冲突

如果输出与既有 ADR 矛盾，显式提出而非静默覆盖：

> _与 ADR-0007（event-sourced orders）矛盾——但值得重开，因为……_
