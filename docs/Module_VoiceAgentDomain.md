# 模組：VoiceAgentDomain

> 語言 · Language：**繁體中文** ｜ English（規劃中 / planned）
>
> 上層導覽：[README](../README.md) ｜ [系統架構](Architecture.md)

## 職責

VoiceAgentKit 的**抽象邊界層：Ports + Entities**。它定義語音基礎設施的所有 Entity 與抽象 ports（gateway 介面），讓各 vendor 實作與上層 Use Case 都依賴它。只 `import Foundation`——**沒有** `AVFoundation`、networking、UI。其他每個 target 都依賴它，它不依賴任何人。

> 💡 **核心概念：這是「Ports + Entities」，不是完整的 Domain 層**
> 
> 注意它**只有抽象與資料，沒有任何 Use Case 或業務邏輯**——它是 Use Case 所依賴的 gateway 抽象（ports），刻意設計成可重用的基礎設施。應用自身的 **Domain 層（Use Cases + Repository）住在 App target**（`Features/Live/Domain/`，見 [README](../README.md#app-的-domain-層use-cases-與-repository)）。把「可重用的語音 ports」與「應用專屬的業務邏輯」分開，正是這套模組化的關鍵：換 vendor 不動業務、改業務不動 Kit。

> 💡 **核心概念：為什麼這層要「零框架」？**
> 
> 一旦抽象型別綁了 `AVFoundation` 或某個網路庫，就再也換不掉那個庫了。保持純 Swift，這些契約能在任何環境（含純命令列測試）編譯與驗證，也讓「換 vendor」變成只動外圈。

---

## 對外 Entity

| 型別 | 用途 |
| --- | --- |
| `AudioFrame` | 一塊擷取到的音訊快照：`samples` / `frameCount` / `rms` / `timestamp` |
| `Transcription` | STT 結果：`text` + 可選 `language` |
| `LLMMessage` / `LLMRole` | 一則對話訊息與其角色（system/user/assistant） |
| `VADEvent` | 斷句事件：`speechStarted` / `speechEnded(segment:)` |
| `VADConfiguration` | 斷句的所有可調參數（門檻、時長、正規化…） |
| `TTSConfiguration` | 合成參數：`rate` / `pitch`（中立值，跨 backend 通用） |
| `AudioRecorderState` | 錄音生命週期：idle/recording/stopped/failed |

全部 `Sendable`，多數 `Equatable`，可安全跨並行邊界傳遞、可在測試直接斷言。

---

## 對外 protocol（抽象邊界）

| protocol | 由誰實作 | 契約 |
| --- | --- | --- |
| `AudioRecording` | [AVAudioCapture](Module_AVAudioCapture.md) | 請求權限、`start() → AsyncStream<AudioFrame>`、`stop()` |
| `VoiceActivityDetecting` | [VoiceActivityDetection](Module_VoiceActivityDetection.md) | `events(from:) → AsyncStream<VADEvent>`、`reset()` |
| `SpeechProbabilityScoring` | [SileroVAD](Module_SileroVAD.md) | `score(window) → Float`、`reset()` |
| `SpeechRecognizing` | [WhisperSTT](Module_WhisperSTT.md) | `transcribe(audio, sampleRate) → Transcription` |
| `LLMResponding` | [ProxyLLM](Module_ProxyLLM.md) | `stream(messages) → AsyncThrowingStream<String>` |
| `SpeechSynthesizing` | [AppleTTS](Module_AppleTTS.md) | `speak(text)`、`stop()` |

> 💡 **核心概念：ISP（介面隔離原則）**
> 
> 注意打分（`SpeechProbabilityScoring`）與斷句（`VoiceActivityDetecting`）是**兩個**小 protocol，而非一個大 VAD protocol。斷句引擎只依賴「打分」這個小介面，於是 Silero 可被任何打分器替換，互不牽連。

---

## 錯誤型別

`AudioRecorderError`、`SpeechRecognitionError`、`LLMError`、`TTSError`——皆 `Sendable & Equatable`，列舉各邊界所有可預期的失敗。詳見 [錯誤處理](Error_Handling.md)。

---

## 其他

- `Diagnostics/AudioProbe`：DEBUG 下的音訊統計與 WAV dump 探針（gated），供開發期核對送進 STT 的音檔品質。

---

## 並行

採 Swift 6 strict concurrency。此 target 多為 value type 與 protocol，本身不持有可變狀態。

## 測試

`VoiceAgentDomainTests` 驗證 Entity 與設定型別的行為（如 `VADConfiguration.windowDurationMs` 計算）。

---

## 相關文件

- [系統架構與模組依賴](Architecture.md)
- [錯誤處理](Error_Handling.md)
