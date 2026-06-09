# 模組：WhisperSTT

> 語言 · Language：**繁體中文** ｜ English（規劃中 / planned）
>
> 上層導覽：[README](../README.md) ｜ [API 整合方式](API_Integration.md)

## 職責

語音轉文字（STT）的 **client 端 networking**。實作 `SpeechRecognizing`，把一段語句樣本封成 WAV、上傳到自架 Whisper 服務、把回應映射成 `Transcription`。**純無狀態網路層**：不碰 UI、不碰 `AVFoundation`。

> 💡 **核心概念：為什麼 STT 與 LLM 分成兩個模組？**
> 
> 兩者都是 networking，但職責不同、可各自替換（SRP）。STT 之後可能換成 on-device 辨識，LLM 可能換 provider，分開後互不牽連——這也是 `WhisperSTT` 與 [`ProxyLLM`](Module_ProxyLLM.md) 各自獨立的原因。

---

## 對外 protocol

實作 `VoiceAgentDomain.SpeechRecognizing`：

```swift
func transcribe(_ audio: [Float], sampleRate: Int) async throws -> Transcription
```

`WhisperSpeechRecognizer` 是 `struct`、`Sendable`，可自由跨並行邊界複製使用。

---

## 流程

1. 空音訊 → 直接拋 `emptyAudio`。
2. `WAVEncoder.encode`：Float32 樣本 → 16-bit PCM WAV（44-byte header + little-endian Int16）。
3. 組 `multipart/form-data`（欄位名預設 `file`），`POST /api/v1/stt`。
4. 檢查 HTTP 狀態，解碼 `STTResponseDTO` → `toDomain()` → `Transcription`。

> 💡 **核心概念：WAV 容器與 PCM 量化**
> 
> WAV 是最簡單的音檔格式：固定 44 bytes 標頭描述取樣率/聲道/位元深度，後面接原始 PCM 樣本。`WAVEncoder` 把 `-1.0~1.0` 的 Float 乘上 32767 轉成 16-bit 整數（量化），並 clamp 防止溢位。用純 Foundation 自寫，避免把 `AVFoundation` 帶進網路層。

---

## 設定

`WhisperConfiguration`：

| 欄位 | 預設 |
| --- | --- |
| `baseURL` | 注入（demo `http://192.168.0.35:8000`） |
| `path` | `/api/v1/stt` |
| `fileFieldName` | `file` |
| `timeout` | 30s |

`baseURL` 注入式設計讓端點可從 Mac 區網位址改指到遠端伺服器，無需改碼。

---

## 錯誤

`SpeechRecognitionError`：`emptyAudio`、`transport`、`server(status:)`、`invalidResponse`、`decoding`。分流邏輯見 [錯誤處理](Error_Handling.md#網路錯誤的分流)。

---

## 伺服器端

`server.py` 以 `faster-whisper`（`small`、`int8`、CPU、`beam_size=5`、`vad_filter=True`）轉寫。端點合約見 [API 整合方式](API_Integration.md#stt-端點-post-apiv1stt)。

> 💡 **核心概念：int8 量化**
> 
> 把模型權重從 32-bit 浮點壓到 8-bit 整數，模型更小、CPU 推論更快，代價是極小的精度損失。適合在沒有 GPU 的伺服器上跑 Whisper。

---

## 並行 / 測試

Swift 6 strict concurrency；無狀態 `struct`。`WhisperSTTTests` 涵蓋 WAV 編碼正確性、multipart body 組裝與回應映射。

---

## 相關文件

- [API 整合方式](API_Integration.md)
- [ProxyLLM 模組](Module_ProxyLLM.md)
- [錯誤處理](Error_Handling.md)
