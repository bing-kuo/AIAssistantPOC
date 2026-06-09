# 模組：AVAudioCapture

> 語言 · Language：**繁體中文** ｜ English（規劃中 / planned）
>
> 上層導覽：[README](../README.md) ｜ [音訊處理流程](Audio_Pipeline.md)

## 職責

麥克風擷取。實作 `AudioRecording`，把硬體的類比輸入變成下游統一吃的 **16kHz mono Float32** `AudioFrame` 串流。這是唯一擁有音訊硬體依賴（`AVFoundation`、`AVAudioEngine`、`Accelerate`）的擷取模組。

---

## 對外 protocol

實作 `VoiceAgentDomain.AudioRecording`：

```swift
func requestPermission() async -> Bool
func start() async throws -> AsyncStream<AudioFrame>
func stop() async
```

---

## 內部結構

| 檔案 | 角色 |
| --- | --- |
| `Recording/AudioEngineRecorder` | `actor`，管 `AVAudioEngine`、session、tap 生命週期 |
| `Audio/AudioDownsampler` | 選路：整數倍走 FIR，否則 `AVAudioConverter` |
| `Audio/FIRDecimator` | `vDSP` 加速的 FIR 低通＋抽取 |
| `Audio/AudioMath` | RMS 等訊號工具 |
| `Diagnostics/DiagnosticCaptureSink` | DEBUG 下擷取原始/降採樣音訊比對 |

> 💡 **核心概念：為什麼錄音器要是 `actor`？**
> 
> 音訊 tap 的回呼在獨立的即時執行緒上跑，而 `start()`/`stop()` 從別處呼叫——這是典型的 data race 溫床。把狀態（engine、continuation、state）包進 `actor`，編譯器保證同一時間只有一個任務碰它。

---

## 擷取流程

1. `configureSession()`：`.playAndRecord` / `.voiceChat`，開 `allowBluetooth`、`defaultToSpeaker`、`duckOthers`。
2. `setVoiceProcessingEnabled(true)`：啟用系統的回聲消除與降噪，利於遠場與未來全雙工。
3. 在 input node `installTap`，每個 buffer：降採樣 → 算 RMS → `yield` 一個 `AudioFrame`。
4. `stop()`：移除 tap、停 engine、結束串流、停用 session。

> 💡 **核心概念：voice processing（語音處理）**
> 
> `setVoiceProcessingEnabled(true)` 開啟 Apple 的語音前處理鏈，含 AEC（回聲消除）、噪音抑制與自動增益。這也是未來[插話打斷](../README.md#3-插話打斷機制barge-in)能在播放時收音的硬體基礎。

---

## 降採樣策略

詳細的 anti-aliasing / FIR / Nyquist 核心概念見 [音訊處理流程](Audio_Pipeline.md#2-降採樣downsampling到-16khz)。重點：

- 整數倍（48k→16k）：`FIRDecimator`，127 taps、sinc×Hamming、截止 `16k×0.45`、`vDSP_desamp`。
- 非整數倍：`AVAudioConverter`，`.max` 品質 + mastering 演算法。
- 跨 buffer 連續性靠 `FIRDecimator.history` 保留尾端樣本。

---

## 並行

Swift 6 strict concurrency。`actor` 隔離硬體狀態；`AudioDownsampler` / `FIRDecimator` 在 tap 回呼內同步使用，不跨界。

## 測試

`AVAudioCaptureTests` 涵蓋 RMS 計算、FIR 降採樣正確性與下取樣輸出長度。

---

## 相關文件

- [音訊處理流程](Audio_Pipeline.md)
- [VoiceAgentDomain 模組](Module_VoiceAgentDomain.md)
