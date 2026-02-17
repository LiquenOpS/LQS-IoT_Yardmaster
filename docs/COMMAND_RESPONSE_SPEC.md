# LQS-IoT Command Response Spec

## 1. 研究結論

### 1.1 業界現狀

- **FIWARE Orion**：[forbidden characters](https://fiware-orion.readthedocs.io/en/3.2.0/user/forbidden_characters/) 明確禁止 `) ( ; = ' " > <`，否則 400 Bad Request。
- **官方建議**：URL encode，或使用 `TextUnrestricted` type（有安全風險）。
- **iotagent-json**：Command 回傳格式僅規定 `{ "commandName": "resultString" }`，value 必須是字串；無針對「複雜 JSON  payload」的標準作法。
- **Base64 慣例**：AWS API Gateway、Oracle 等常見做法是把 binary/opaque payload 用 base64 包在 JSON 裡傳輸；但 **FIWARE 生態未定義** 此類 command response 編碼規範。

**結論：沒有通用標準。本專案自訂規格。**

---

## 2. 規格定義

### 2.1 適用範圍

- **Yardmaster**：回應 IOTA 發出的 command 時，依本 spec 產出 HTTP 回應。
- **Odoo**：透過 Orion 取得 command 結果時，依本 spec 解析。

### 2.2 HTTP 狀態碼

使用標準 HTTP status，表示此次 request 層級結果：

| 狀態碼 | 意義 |
|--------|------|
| 200 | 成功 |
| 400 | 無效 request（未知 command、參數錯誤等） |
| 500 | 內部錯誤 |
| 501 | 該 command 未啟用（如 Signage 關閉時呼叫 signage command） |

### 2.3 Response Body 格式

IOTA 需要 `{ "commandName": "resultString" }`，且 `resultString` 會被寫入 Orion。Orion 禁止 `) ( ; = ' " > <`。

**統一規則**：所有 command 結果一律為 `b64:<base64url(JSON)>`，不區分簡單/複雜。

- **內容**：dict 或 list，先 `json.dumps` 成 JSON 字串，再 base64url encode。
- **前綴**：`b64:`，consumer 一律解碼後使用。

#### Base64url 細節

- **編碼**：RFC 4648 base64url（`-`、`_` 取代 `+`、`/`），**去掉 padding `=`**（Orion 禁止 `=`）。

範例（Python）：

```python
import base64
import json

def encode_payload(obj):
    raw = json.dumps(obj, ensure_ascii=False)
    b64 = base64.urlsafe_b64encode(raw.encode("utf-8")).decode("ascii").rstrip("=")
    return f"b64:{b64}"

def decode_payload(s: str):
    if not (isinstance(s, str) and s.startswith("b64:")):
        return s
    b64 = s[4:]
    pad = 4 - len(b64) % 4
    if pad != 4:
        b64 += "=" * pad
    return json.loads(base64.urlsafe_b64decode(b64).decode("utf-8"))
```

---

## 3. Yardmaster 實作

- 所有 command 回傳：`jsonify({ cmd_name: encode_payload(result) })`，HTTP status 依 2.2。
- `result` 為 list 或 dict，一律經 `encode_payload` 成 `b64:<base64url>`。

---

## 4. Odoo 實作

- 從 Orion 取回任一 command 的 `*_info` / `value` 後，一律為 `b64:` 格式，`decode_payload(value)` 取得 list/dict 後使用。

---

## 5. 參考

- [FIWARE Orion Forbidden Characters](https://fiware-orion.readthedocs.io/en/3.2.0/user/forbidden_characters/)
- [RFC 4648 Base64 Encoding](https://datatracker.ietf.org/doc/html/rfc4648#section-5)
- [FIWARE_COMMAND_RESPONSE.md](./FIWARE_COMMAND_RESPONSE.md) — IOTA 基本格式
