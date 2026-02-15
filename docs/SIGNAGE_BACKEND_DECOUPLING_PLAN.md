# Signage Backend Decoupling Plan

目標：讓 Signage 後端（目前為 Anthias）可替換，未來能接 Xibo、Screenly OSE 或其他 CMS 而不需大幅改動。

---

## 現狀耦合分析

### Yardmaster（耦合較強）

| 項目 | 位置 | 說明 |
|------|------|------|
| 環境變數 | `ANTHIAS_BASE_URL` | 綁定 Anthias 專屬 URL |
| 專用欄位 | `asset["skip_asset_check"]` | Anthias API 專用 |
| API 結構 | `POST /`, `PATCH /{id}`, `DELETE /{id}`, `POST /order` | 依 Anthias 設計 |
| 回傳格式 | `out["asset_id"] = out["id"]` | 各後端回傳欄位不同 |
| 函式命名 | `_anthias_resp()` | 暗示單一後端 |

### Odoo

| 項目 | 位置 | 說明 |
|------|------|------|
| 欄位名 | `anthias_id` | 需 migration 才能改名 |
| 使用者文案 | UserError、help、Troubleshooting | 寫死 "Anthias" |

### 已具泛用性（保留）

- FIWARE 命令名：`createAsset`, `updateAssetPatch`, `deleteAsset`, `updatePlaylistOrder`
- Odoo 的 `asset_vals`：`name`, `uri`, `duration`, `start_date`, `end_date`, `play_order`, `mimetype`, `is_enabled`

---

## 代辦事項

### Phase 1：快速解耦（低風險）

- [ ] **Y-1** 將 `_anthias_resp()` 更名為 `_signage_http_resp()`（或 `_parse_backend_resp`）
- [ ] **Y-2** 環境變數 `ANTHIAS_BASE_URL` → `SIGNAGE_BACKEND_URL`（保留 `ANTHIAS_BASE_URL` 作為 alias 向後相容）
- [ ] **O-1** Odoo 文案：Troubleshooting / UserError / help 改為「signage backend」或「display system」，移除 Anthias 字樣
- [ ] **Y-3** `skip_asset_check` 由 backend 實作決定是否加入，從共用的 payload 組裝邏輯中移出

### Phase 2：Yardmaster 抽象層（核心重構）

- [ ] **Y-4** 新增 `gateway/backends/signage_base.py`：定義抽象介面
  ```python
  # 介面：create_asset(asset_vals) -> {asset_id}, update_asset(id, vals), delete_asset(id), list_assets(), update_playlist_order(ids)
  ```
- [ ] **Y-5** 新增 `gateway/backends/anthias.py`：將現有 Anthias 邏輯遷移至此（含 `skip_asset_check`、`id`→`asset_id`  mapping）
- [ ] **Y-6** `app.py` 依 `SIGNAGE_BACKEND=anthias` 選擇 backend，呼叫抽象介面
- [ ] **Y-7** Config：`SIGNAGE_BACKEND=anthias`， Anthias 專用 URL 改為 `SIGNAGE_ANTHIAS_BASE_URL`（僅 anthias backend 讀取）

### Phase 3：Odoo 欄位（可選）

- [ ] **O-2** 評估 `anthias_id` 更名為 `external_asset_id`
  - 選項 A：維持 `anthias_id`，僅在註解說明為「外部 asset ID」
  - 選項 B：新增 `external_asset_id`，deprecate `anthias_id`，需 migration

### Phase 4：新增 Backend 範例（驗證設計）

- [ ] **Y-8** 新增 stub `gateway/backends/xibo.py` 或 `placeholder.py` 作為第二個 backend 範例，驗證抽象是否足夠

---

## 實作順序建議

1. Phase 1 全部（Y-1, Y-2, O-1, Y-3）— 改 naming 與文案，風險低
2. Phase 2 的 Y-4 → Y-5 → Y-6 → Y-7 — 一次完成或分批
3. Phase 3（O-2）依 migration 成本決定
4. Phase 4（Y-8）作為驗證與範例

---

## 相依關係

```
Y-4 (抽象介面) ──┬── Y-5 (Anthias 實作)
                └── Y-8 (stub backend)
Y-6, Y-7 依賴 Y-4, Y-5
Y-3 可合併進 Y-5
```

---

## 備註

- FIWARE 命令名與 Odoo payload 結構保持不變，僅 Yardmaster 內部重構
- 未來新增 backend 時，只需實作 `signage_base` 介面並在 config 指定
