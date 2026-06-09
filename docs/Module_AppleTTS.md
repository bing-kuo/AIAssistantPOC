# 模組：AppleTTS

> 語言 · Language：**繁體中文** ｜ English（規劃中 / planned）
>
> 上層導覽：[README](../README.md)

## 職責

文字轉語音（TTS）。實作 `SpeechSynthesizing`，用 Apple **on-device** `AVSpeechSynthesizer` 把回覆念出來，並自動依文字語言挑選最合適的嗓音。`AVFoundation` 被隔離在單一 speaker 包裝檔內。

> 💡 **核心概念：為什麼選 on-device TTS？**
> 
> 雲端 TTS 要等音檔下載才能播，增加感知延遲也耗流量。Apple 內建合成在裝置上即時發聲、免費、離線可用、支援中英嗓音，對「即時對話」最划算。protocol 化後，未來要換雲端高品質嗓音也只動這個 target。

---

## 對外 protocol

實作 `VoiceAgentDomain.SpeechSynthesizing`：

```swift
func speak(_ text: String) async throws   // 念完才返回
func stop() async                          // 立即停止
```

`AppleSpeechSynthesizer` 是 `actor`。`speak` 是 async 並在播放結束才返回，讓 ViewModel 能準確銜接 `playing → listening`。

---

## 內部結構

| 檔案 | 角色 |
| --- | --- |
| `AppleSpeechSynthesizer` | `actor`，編排：偵測語言 → 選嗓音 → 播放 |
| `AVUtteranceSpeaker` | `AVSpeechSynthesizer` 實際包裝（唯一碰 `AVFoundation`） |
| `UtteranceSpeaking` | speaker 抽象 protocol，方便注入 mock 測試 |
| `Language/DominantLanguageDetector` | 數 Han 字 vs. 拉丁字母判主語言 |
| `Voice/VoiceSelector` | 在符合語言的嗓音中挑最佳品質 |
| `Voice/VoiceOption` | 嗓音中立描述（id / language / quality） |

> 💡 **核心概念：用 protocol 包住 `AVSpeechSynthesizer`**
> 
> `AppleSpeechSynthesizer` 不直接 new `AVSpeechSynthesizer`，而是依賴 `UtteranceSpeaking` protocol。於是語言偵測、選嗓音、錯誤映射等邏輯能在不發出真實聲音的情況下被單元測試。`AVFoundation` 只活在 `AVUtteranceSpeaker` 一個檔案裡。

---

## 語言偵測與選嗓音

1. `DominantLanguageDetector.detect`：掃 Unicode scalar，數中日韓漢字（Han）與拉丁字母，多者為主語言（`zh-TW` 或 `en-US`）。
2. `VoiceSelector.select`：在語言前綴相符的嗓音中，優先**品質高**（premium/enhanced）、再偏好精確 locale 相符。
3. 整段回覆用**單一嗓音**念；句中夾雜的外語詞由該嗓音概括處理（[已知限制](../README.md#已知限制)）。

> 💡 **核心概念：為什麼用「字數比例」判語言？**
> 
> 對「今天的 weather 如何」這種混語句，與其呼叫重量級語言辨識，不如直接數哪種字多——簡單、快、夠用。中文以漢字 Unicode 區段判定，英文以 A–Z 判定。此做法兼具效能與智能助理的情境。

---

## 設定與錯誤

- `TTSConfiguration`：`rate`（0.5 自然）、`pitch`（1.0 原音）——中立值，跨 backend 通用。
- `TTSError`：`emptyText`、`cancelled`、`synthesisFailed`。

`stop()` 供使用者中止與未來[插話打斷](../README.md#3-插話打斷機制barge-in)即時截斷播放。

---

## 並行 / 測試

Swift 6 strict concurrency。`actor` 序列化合成請求；`live()` 工廠在 `@MainActor` 建立 `AVUtteranceSpeaker`。`AppleTTSTests` 以 mock speaker 驗證語言偵測、選嗓音與錯誤映射，不發出真實聲音。

---

## 相關文件

- [VoiceAgentDomain 模組](Module_VoiceAgentDomain.md)
- [狀態機設計](State_Machine.md)
