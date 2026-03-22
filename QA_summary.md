# LLM 方案选型 — 九问九答总结

> Mac Studio M4 Max 36GB · 2026 年 3 月 · 用途：搭应用/Agent + 编程 + 日常问答

---

## 总体结论

**你现有的 LiteLLM hybrid 方案（本地 Ollama + 云端开源 API）是当前最优解。** 不需要推倒重来，只需微调：

1. **本地主力**：Qwen3 14B (日常) + Devstral 24B (编程) — 覆盖 70-80% 需求，$0
2. **云端兜底**：Qwen3 235B (Together) / DeepSeek V3 / Groq Llama 4 Scout — 按需自动 fallback
3. **路由层**：LiteLLM — 目前唯一满足开源+自部署+可商用+易操作的方案
4. **未来升级**：内存→64GB+ 跑 Qwen3 72B，流量大了再考虑 Bifrost

---

## 逐题回答

### Q1: GLM API vs Plan？
**结论：都不推荐。** GLM-4.7 定价 $0.39/$1.75，2026.2 涨价 30-60%。Plan 按 prompt 限量，性价比差。DeepSeek V3 ($0.14/$0.28) 质量相当但便宜 3 倍。

### Q2: 36GB 能跑什么最好的模型？
**结论：Qwen3 14B Q4 (日常最佳平衡) 或 Qwen3 32B Q4 (极限天花板)。**
- Qwen3 8B Q8 → 40+ tok/s（极快）
- Qwen3 14B Q4 → 25-30 tok/s（推荐主力）
- Qwen3 32B Q4 → 15-22 tok/s（质量更高，速度牺牲一些）
- Devstral 24B Q4 → 18-22 tok/s（编程专用）

### Q3: 本地 vs 云端最强开源的差距？
- **质量差距**：本地 14B ≈ 云端最强的 85-87%；本地 32B ≈ 90-92%
- **vs 闭源前沿**：本地 14B ≈ 78-82%；本地 32B ≈ 85-88%
- **速度**：本地 25-30 tok/s vs Groq 500+ tok/s（云端快 15-20 倍）
- **成本**：本地 $0 vs 云端 $0.11-0.90/M tokens
- 详见 `model_comparison_chart.html`

### Q4: 如果调 API，怎么选？（质量>性价比>速度>中文）
**推荐分层：**
- 重型：Claude Sonnet 4.6 ($3/$15)
- 主力：**Qwen3 235B via Together ($0.26/$0.90)** ← 最佳平衡
- 日常：DeepSeek V3 ($0.14/$0.28)
- 极速：Groq Llama 4 Scout ($0.11)

### Q5: DeepSeek 效果略差，有更好的？
DeepSeek V3 已是最便宜高质量选项。更好的选择不是找更便宜的 API，而是减少云端调用。方案：本地 Qwen3 覆盖 80% 需求 + Gemini Flash-Lite/Groq 免费额度兜底。

### Q6: 倾向开源 LLM + 本地部署，方向对吗？
**方向完全正确。** 但 36GB 是瓶颈，复杂 Agent 需云端补充。路线图：现在 hybrid → 升内存后 Qwen3 72B → 逐步减少云端依赖。

### Q7: 还有什么统一路由方案？
满足"开源+自部署+可商用+易操作"全部条件的 **只有 LiteLLM**。Bifrost 性能更强但闭源；OpenRouter 不可自部署；Portkey 需付费。

### Q8: 为什么不直接用 Bifrost？
Bifrost 性能确实强 54 倍，但：不开源（无法审计）、需企业授权、社区小。LiteLLM 在个人/小团队规模完全够用。未来真扛不住再迁移，只改一行 base_url。

### Q9: 需要新建 GitHub repo 吗？
**不需要。** `LLMGateways/analysis` 里的配置文件已经是可执行方案。直接 `git init` 当前项目即可。

---

## 你的方案文件清单

| 文件 | 作用 |
|------|------|
| `litellm_config.yaml` | LiteLLM 完整配置：3 层模型 + fallback + 缓存 |
| `.env.example` | API Key 模板 |
| `README.md` | 搭建指南：从安装到日常使用 |
| `model_comparison_chart.html` | 可视化对比图表（浏览器打开） |
| `QA_summary.md` | 本文件：九问九答总结 |

---

## 执行清单 (5 步上线)

1. `brew install ollama && ollama serve`
2. `ollama pull qwen3:14b && ollama pull qwen3:8b`
3. `pip install 'litellm[proxy]'`
4. `cp .env.example .env` → 填 Groq/DeepSeek/Together 的 key
5. `source .env && litellm --config litellm_config.yaml --port 4000`

完成。所有应用统一请求 `http://localhost:4000/v1`。
