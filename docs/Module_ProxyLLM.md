# 模組：ProxyLLM

> 語言 · Language：**繁體中文** ｜ English（規劃中 / planned）
>
> 上層導覽：[README](../README.md) ｜ [API 整合方式](API_Integration.md)

## 職責

LLM 對話的 **client 端 networking**，走 **Server-Sent Events（SSE）串流**。實作 `LLMResponding`，把對話 POST 給自架 proxy，逐行消費 `text/event-stream`，把每個文字 delta 即時往上吐。**純無狀態網路層**：不碰 UI、不碰 `AVFoundation`。

> 💡 **核心概念：「Proxy」之名**
> 
> client 不直接打 OpenAI，而是打自家 proxy。provider 金鑰與模型選型留在伺服器，App 不持有任何金鑰，也能在不改版的情況下換 provider。

---

## 對外 protocol

實作 `VoiceAgentDomain.LLMResponding`：

```swift
func stream(_ messages: [LLMMessage]) -> AsyncThrowingStream<String, Error>
```

`ProxyLLMResponder` 是 `struct`、`Sendable`。回傳的串流逐字 `yield` delta，完成即 `finish`，失敗則 `finish(throwing:)`。

---

## 流程

1. 空對話 → 拋 `emptyConversation`。
2. `ChatRequestDTO.fromDomain` 編碼為 JSON，`POST /api/v1/chat`，`Accept: text/event-stream`（可選 `Bearer` token）。
3. 用 `URLSession.bytes(for:).lines` 逐行讀。
4. 每行交給 `SSELineParser.parse` → `.delta` / `.done` / `.failure`：
   - `.delta(text)` → `yield`
   - `.done` → 結束
   - `.failure(msg)` → 拋 `LLMError.stream`

> 💡 **核心概念：背壓與逐行讀取**
> 
> `URLSession.AsyncBytes.lines` 讓我們不必等整個回應下載完，而是「來一行處理一行」。配合 `AsyncThrowingStream`，使用者能在模型還在生成時就看到字、聽到聲，這是即時語音助理體感的關鍵。

---

## SSE 解析

`SSELineParser`（純函式、可單測、不含 networking）規則：

- 忽略空行與 `:` keep-alive 註解行。
- 只認 `data:` 開頭；payload 為 `[DONE]` → 結束。
- 否則解 `ChatChunkDTO`（`{ "delta" }` 或 `{ "error" }`）；解析失敗回 `.failure("malformed event payload")`。

SSE 的整體背景與伺服器格式見 [API 整合方式](API_Integration.md#llm-端點-post-apiv1chat)。

---

## 設定

`LLMConfiguration`：

| 欄位 | 預設 |
| --- | --- |
| `baseURL` | 注入 |
| `path` | `/api/v1/chat` |
| `timeout` | 60s |
| `accessToken` | `nil`（預留：低價值、可輪替的內部 token，非 provider key） |

---

## 取消

`stream(_:)` 內的 `Task` 綁定 `continuation.onTermination`：上游不再需要結果（例如使用者按停、被打斷）時即 `task.cancel()`，迴圈內 `Task.isCancelled` 提早返回，停止讀取。為未來[插話打斷](../README.md#3-插話打斷機制barge-in)預留了乾淨的中止路徑。

---

## 錯誤

`LLMError`：`emptyConversation`、`transport`、`server(status:)`、`invalidResponse`、`stream`、`decoding`。分流見 [錯誤處理](Error_Handling.md#網路錯誤的分流)。

---

## 並行 / 測試

Swift 6 strict concurrency；無狀態 `struct`。`ProxyLLMTests` 涵蓋 SSE 行解析（delta / done / 註解 / 壞 payload）與請求編碼。

> 注意：對話歷史與滑動視窗截斷由 App 的 `ConversationRepository` 保存，組 system prompt + 歷史 + user turn 則由 `GenerateReplyUseCase` 負責（見 [README](../README.md#app-的-domain-層use-cases-與-repository)）；本模組只管「把這批訊息送出去、串流回來」。

---

## 相關文件

- [API 整合方式](API_Integration.md)
- [WhisperSTT 模組](Module_WhisperSTT.md)
- [錯誤處理](Error_Handling.md)
