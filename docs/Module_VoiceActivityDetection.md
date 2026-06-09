# 模組：VoiceActivityDetection

> 語言 · Language：**繁體中文** ｜ English（規劃中 / planned）
>
> 上層導覽：[README](../README.md) ｜ [音訊處理流程](Audio_Pipeline.md)

## 職責

**斷句（endpointing）**：把連續的音訊樣本，切成「一句完整的話」並回報開始與結束事件。它是中立的純邏輯——只在 `[Float]` 窗上運算，**不含** `AVFoundation`、不綁任何特定 VAD 模型。

> 💡 **核心概念：VAD vs. endpointing**
> 
> VAD（Voice Activity Detection）廣義指「判斷這段有沒有語音」。endpointing 更進一步：找出語句的**起點與終點**，好讓 STT 拿到剛好一句、不多不少。本模組負責後者，前者的「逐窗打分」外包給注入的打分器。

---

## 對外 protocol

實作 `VoiceAgentDomain.VoiceActivityDetecting`：

```swift
func events(from samples: AsyncStream<[Float]>) -> AsyncStream<VADEvent>
func reset() async
```

輸出 `VADEvent`：`speechStarted` 或 `speechEnded(segment: [Float])`。

---

## 依賴注入：打分器

`SpeechEndpointDetector` 持有一個 `SpeechProbabilityScoring`，由外部注入：

```swift
SpeechEndpointDetector(scorer: try SileroVAD())          // 正式
SpeechEndpointDetector(scorer: SilentScorer())           // 模型缺失時降級
```

> 💡 **核心概念：依賴注入的價值**
> 
> 斷句邏輯（門檻、時長、pad）與打分模型（Silero）被拆開。測試時可注入一個「腳本化打分器」精準控制每一窗的機率，驗證 hysteresis 是否如預期觸發，完全不需載入真實 ONNX 模型。

---

## 斷句演算法

`SpeechEndpointDetector`（`actor`）對每一窗：

1. **累積成固定窗**：把進來的任意長度 chunk 累積到 `windowSize`（512）再評估。
2. **正規化打分**：`normalizedForScoring` 把偏小聲的乾淨訊號自適應放大到 Silero 慣用能量（只影響打分，輸出語句不放大）。
3. **打分**：交給注入的 scorer 取 0~1 機率。
4. **狀態機 + hysteresis**：

| 目前 | 條件 | 動作 |
| --- | --- | --- |
| 非語音 | `prob ≥ speechThreshold` 持續 ≥ `minSpeechDurationMs` | → 語音中，發 `speechStarted`，前綴接上 leading pad |
| 語音中 | `prob < silenceThreshold` 累積靜音 ≥ `minSilenceDurationMs` | → 結束，發 `speechEnded(segment)` |

預設參數（`VADConfiguration`）：窗 512、speech 0.5 / silence 0.35、最短語音 250ms、最短靜音 700ms、leading pad 150ms。

> 💡 **核心概念：leading pad（前綴緩衝）**
> 
> VAD 確認「開始說話」時，使用者其實已經吐出第一個音了。保留偵測點之前 150ms 的樣本接在語句前面，避免 STT 漏掉開頭的子音，辨識更完整。

hysteresis 與門檻調校的訊號處理背景見 [音訊處理流程](Audio_Pipeline.md#4-斷句endpointing)。

---

## 串流模型

`events(from:)` 是 `nonisolated`，內部開一個 `Task` 持續 `for await` 樣本 chunk，逐窗 `ingest`，邊算邊 `yield` 事件；上游結束或被取消時收尾。`reset()` 清空所有狀態（含呼叫 scorer 的 `reset()`），讓下一句從乾淨狀態開始。

---

## 並行

Swift 6 strict concurrency。`actor` 隔離所有斷句狀態變數（`isSpeaking`、`utterance`、`trailingSilenceMs`…）。

## 測試

`VoiceActivityDetectionTests` 以受控打分序列驗證起止判定、最短時長 debounce、leading pad 與 reset 行為。

---

## 相關文件

- [SileroVAD 模組](Module_SileroVAD.md)（打分器實作）
- [音訊處理流程](Audio_Pipeline.md)
- [VoiceAgentDomain 模組](Module_VoiceAgentDomain.md)
