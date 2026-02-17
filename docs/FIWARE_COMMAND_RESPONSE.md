# FIWARE IoT Agent JSON — Command Response 規格

## 官方說法

根據 [FIWARE Tutorial](https://github.com/FIWARE/tutorials.IoT-Agent-JSON)：

> HTTP commands posted to a well-known URL — **response is in the reply**  
> The Smart Lamp switches on the lamp and **returns the result of the command to the IoT Agent in JSON syntax**

**流程**：IOTA POST command → Device 執行 → Device 回傳 200 + JSON body → IOTA 用此更新 Orion。

## 預期格式

從 [iotagent-json commandHandler.js](https://github.com/telefonicaid/iotagent-json/blob/master/lib/commandHandler.js)：

```javascript
// updateCommand(apiKey, deviceId, device, messageObj)
// messageObj 的每個 key 會當成 command name，value 當成 result
const commandList = Object.keys(messageObj);  // 必須是 Object，不能是 string！
```

**正確格式**：`{ "commandName": "resultString" }`

例如 createAsset：`{"createAsset": "asset_id:xxx"}`

**注意**：Orion 禁止 `=` 等字元，結果字串用 `:` 取代 `=`（如 `asset_id:xxx`）。

**重點**：
1. 必須是 JSON Object（IOTA 會 `Object.keys()`）
2. 每個 key 要是 provisioned command 的名稱
3. value 要是字串（不能是空字串或純空白）

## 實作注意

- **只用 HTTP response**：Device 回 200 + JSON 即足夠，IOTA 會 parse 並呼叫 `updateCommand`。
- **不要**額外 POST 到 `/iot/json`：該端點是給 measure（屬性上報）用的，不是 command response。若送 `createAsset_status`/`createAsset_info` 會得到 400 且格式不符。

## 可能問題

| 問題 | 說明 |
|------|------|
| Body 未 parse | Node `request` 若未設 `json: true`，body 可能是 string，`Object.keys("...")` 會得到字元 index |
| protocol 不匹配 | provision 用 `PDI-IoTA-JSON`，標準為 `HTTP`，可能影響 binding 選擇 |
| 非 provisioned key | 多餘的 key（asset_id, name 等）會讓 IOTA 對非 command 呼叫 setCommandResult |

## 建議驗證

1. **查 IOTA log**（`IOTA_LOG_LEVEL=DEBUG`）：確認 `updateCommand` 是否被呼叫，以及是否有 `COMMANDS-002` 錯誤
2. **protocol**：先改成 `"transport": "HTTP"`、移除或調整 `protocol` 再測
3. **回應格式**：只回傳 `{"createAsset": "asset_id=xxx"}`，不要其他欄位
