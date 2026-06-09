# 模組：SileroVAD

> 語言 · Language：**繁體中文** ｜ English（規劃中 / planned）
>
> 上層導覽：[README](../README.md) ｜ [音訊處理流程](Audio_Pipeline.md)

## 職責

語音機率打分器。實作 `SpeechProbabilityScoring`，用 **Silero VAD v5** 神經網路模型，對每個固定大小的音訊窗回一個「是語音的機率」（0~1）。它是 [VoiceActivityDetection](Module_VoiceActivityDetection.md) 斷句引擎的「耳朵」，可被任何其他打分器替換。

> 💡 **核心概念：神經網路 VAD vs. 能量門檻**
> 
> 最樸素的 VAD 只看音量（RMS）夠不夠大，但這樣會把關門聲、鍵盤聲都當成語音。Silero 是訓練過的小型神經網路，學過「人聲的頻譜長相」，在吵雜環境下遠比單純能量門檻準。

---

## 對外 protocol

實作 `VoiceAgentDomain.SpeechProbabilityScoring`：

```swift
func score(_ window: [Float]) async throws -> Float   // 回 0...1
func reset() async
```

`window` 必須剛好是 `windowSize`（512）個 16kHz Float32 樣本，否則拋 `invalidWindowSize`。

---

## 實作重點

`SileroVAD` 是 `actor`，封裝 ONNX Runtime session 與模型的**遞迴狀態**：

- 啟動時從 `Bundle.module` 載入打包的 `silero_vad.onnx`（`Resources/`）。
- 每次推論餵三個輸入：`input`（context + 當前窗）、`state`（遞迴隱藏狀態）、`sr`（取樣率）。
- 取回 `output`（機率）與 `stateN`（更新後狀態），並保留尾端 `context`（64 樣本）接到下一窗前面。

> 💡 **核心概念：為什麼要保留 state 與 context？**
> 
> Silero 是有記憶的（recurrent）模型——判斷「現在是不是語音」會參考前文。`state` 是它的隱藏記憶，`context` 是上一窗的尾巴。所以每句話開始前必須 `reset()` 清掉記憶，否則前一句的尾音會污染下一句的判斷。

> 💡 **核心概念：ONNX Runtime**
> 
> Silero 以 `.onnx` 格式發布權重；ONNX Runtime（Microsoft）是跨平台推論引擎，透過 `onnxruntime-swift-package-manager` 在 iOS 上載入並執行，不需把模型轉成 Core ML 或綁定訓練框架。

---

## 錯誤

`SileroVADError`：`modelNotFound`、`sessionCreationFailed`、`invalidWindowSize`、`inferenceFailed`。模型載入失敗時，Composition Root 會降級為 `SilentScorer`（見 [錯誤處理](Error_Handling.md#優雅降級graceful-degradation)），App 仍可啟動。

---

## 並行

Swift 6 strict concurrency。`actor` 把非執行緒安全的 ONNX session 與遞迴狀態序列化，確保串流推論不交錯。

## 測試

`SileroVADTests` 驗證模型載入、窗大小檢查與 `reset()` 後狀態清空。

---

## 依賴

- `VoiceAgentDomain`
- `onnxruntime`（外部 SPM 套件）— **唯一**綁 ONNX 的 target

---

## 相關文件

- [VoiceActivityDetection 模組](Module_VoiceActivityDetection.md)（消費此打分器）
- [音訊處理流程](Audio_Pipeline.md)
