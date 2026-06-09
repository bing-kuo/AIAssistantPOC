# 效能量測指南

> 語言 · Language：**繁體中文** ｜ English（規劃中 / planned）
>
> 上層導覽：[README](../README.md) ｜ [效能分析](../README.md#效能分析)

說明本專案**實際怎麼量延遲**、目前量到的 baseline，以及還能往下怎麼量。原則：指標起訖明確、輸入可重現、看 percentile、分冷熱。

---

## 1. 我們實際怎麼量

- **工具**：opt-in benchmark `AIAssistantPOCTests/PipelineBenchmarks.swift`，量 STT 往返與 LLM TTFT/全文，用 `ContinuousClock`（單調時鐘）計時、輸出 p50/p90/p95。
- **環境**：**iPhone 17 模擬器** → **本機 server**（`127.0.0.1`，loopback）。⚠️ 這**不是實機數字**——模擬器跑在 Mac 上、走 loopback，實機 + Wi-Fi 會不同（見 [§5](#5-可延伸的量測尚未做)）。
- **輸入**：**一段 4.69s 的真實 16kHz mono 錄音**（手機錄音以 `afconvert` 轉成 16k 單聲道）。app 在進 pipeline 前就把音訊降到 16kHz mono 才送 STT，所以用 16kHz 最具代表性。
- **次數**：n=20；第一次呼叫含 warmup（faster-whisper 載模型、provider 連線），先丟一次暖機再開始計。
- **記錄的條件**：模擬器型號、`WHISPER_MODEL=small`（CPU、beam_size=5）、`LLM_MODEL`。

> 💡 **核心概念：為什麼看 percentile、看 RTF**
> 
> 延遲是長尾分布，平均會被偶發慢值拉歪，所以看 **p50/p90/p95**。**RTF（Real-Time Factor）＝處理時間 ÷ 音訊長度**，< 1 代表比即時快；STT 看 RTF 比看絕對毫秒更能跨不同長度比較。

---

## 2. 重現 baseline（跑 benchmark）

benchmark 預設**跳過**，需要**伺服器在線**才跑：

```bash
TEST_RUNNER_VOICE_BENCH=1 \
TEST_RUNNER_VOICE_BENCH_URL=http://127.0.0.1:8000 \
TEST_RUNNER_VOICE_BENCH_WAV=/abs/path/utterance.wav \
TEST_RUNNER_VOICE_BENCH_N=20 \
xcodebuild test -scheme AIAssistantPOC \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:AIAssistantPOCTests/PipelineBenchmarks \
  -parallel-testing-enabled NO
```

| 環境變數 | 預設 | 說明 |
| --- | --- | --- |
| `VOICE_BENCH` | （未設則跳過） | 設任意值即啟用 benchmark |
| `VOICE_BENCH_URL` | `http://192.168.0.35:8000` | 伺服器位址（模擬器連本機用 `127.0.0.1`）|
| `VOICE_BENCH_WAV` | （未設則用合成音） | STT 輸入用的 16kHz mono WAV 絕對路徑 |
| `VOICE_BENCH_N` | `20` | 每項迭代次數 |

> ⚠️ 兩個踩過的坑：
> 1. **`TEST_RUNNER_` 前綴**：測試在模擬器的另一個 process 跑，host 的環境變數不會自動傳入；xcodebuild 只會把 `TEST_RUNNER_` 開頭的變數（去掉前綴後）轉發進測試 process。少了前綴 → benchmark 會被當成未啟用而 skip。
> 2. **`-parallel-testing-enabled NO`**：否則 Swift Testing 會開多台模擬器 clone、請求量翻倍，撞到 server 的 rate limit（`LLM_RATE_LIMIT` 預設 30 次/60s）導致 LLM 測試失敗。N 也別超過該上限。
>
> 未設 `VOICE_BENCH_WAV` 時退回合成正弦音——延遲是真的，但辨識內容無意義；要代表性 STT 數字就餵真實錄音。模擬器可直接讀 Mac 上的絕對路徑。

---

## 3. 量得的 baseline（2026-06）

條件：iPhone 17 模擬器、faster-whisper `small`（CPU、beam_size=5）、4.69s 真實語料、LLM proxy 走 loopback、n=20。

```
[bench] STT round-trip (n=20): p50=1915ms p90=2015ms p95=2041ms RTF(p50)=0.41
[bench] LLM TTFT (n=20):       p50=677ms  p90=862ms  p95=1161ms
[bench] LLM full (n=20):       p50=825ms  p90=1130ms p95=1452ms
```

| 區段 | p50 | p90 | p95 |
| --- | --- | --- | --- |
| STT 往返（4.7s 語料） | 1915ms | 2015ms | 2041ms（RTF 0.41）|
| LLM 首字（TTFT） | 677ms | 862ms | 1161ms |
| LLM 全文 | 825ms | 1130ms | 1452ms |

- **STT 是主要瓶頸**（~1.9s）：RTF 0.41，比即時快但絕對值高，受 CPU Whisper + 音檔長度影響。
- **LLM 很快**：TTFT ~0.68s、短回覆全文 ~0.83s。

---

## 4. 各階段量測點對照

benchmark 量的是 STT 往返與 LLM 兩段（上表）。其餘階段的量測點整理如下；其中 signpost 已埋好，供日後在實機用 Instruments 讀（見 [§5](#5-可延伸的量測尚未做)）：

| 階段 | 指標 | 量測來源 |
| --- | --- | --- |
| 斷句延遲 | 多為設計值 `minSilenceDurationMs`(700ms) + window 粒度 | 設計常數，非量測 |
| STT 往返 | `transcribe()` 進出 | **benchmark（已量）**；signpost `VoiceTurn` 起點 → `STT.done` |
| LLM 首字（TTFT） | 送出 → 第一個 delta | **benchmark（已量）**；signpost `STT.done` → `LLM.firstToken` |
| LLM 全文 | 首字 → 末字 | **benchmark（已量）**；signpost `LLM.firstToken` → `LLM.complete` |
| TTS 起播 | `speak()` → 出聲 | signpost `TTS.begin`（更精細的 first-audio 需在 `AVUtteranceSpeaker` 加 `didStart`）|
| VAD 打分 | 每個 512-window 的 `score()` | Instruments **Time Profiler**（每 32ms 一次，太頻繁不適合 signpost）|
| **E2E** | 說完 → 第一聲 | signpost `VoiceTurn` interval 全長 |

> `ProcessVoiceTurnInteractor` 已用 `OSSignposter` 埋點（subsystem `AIAssistantPOC` / category `Performance`）：一輪對話 = 一個 `VoiceTurn` interval，內含事件 `STT.done` / `LLM.firstToken` / `LLM.complete` / `TTS.begin`。

---

## 5. 可延伸的量測（尚未做）

目前 baseline 只涵蓋「模擬器 + 一段語料 + benchmark」。要更完整可再做：

- **實機 + Wi-Fi**：目前是模擬器走 loopback；實機的網路與 CPU 條件不同，數字會變。
- **用 Instruments 讀 signpost（實機 E2E）**：Xcode → Profile（⌘I）→ os_signpost 模板 → 操作一輪對話 → 展開 `VoiceTurn` interval，interval 全長即 E2E、相鄰事件距離即各段耗時。這能量到 benchmark 沒涵蓋的 TTS 起播與整輪 E2E。
- **多段語料長度**（短/中/長 ≈ 2s / 5s / 10s）：目前只量一段 4.7s，看不出 STT 隨長度的變化。
- **伺服器端拆分**：在 `server/server.py` 的 `model.transcribe(...)` 與 LLM stream 前後加時間戳，或對端點打固定 payload 計時（`curl -w "%{time_total}"` / `hyperfine`），區分瓶頸在「模型」還是「網路」。
- **VAD 每窗 `score()`**：用 Time Profiler 確認遠低於即時預算（每 32ms window 的處理要 ≪ 32ms）。

---

## 6. 目標值與下一步

- **E2E（說完→出聲）**：< ~1.5–2s 才有「在對話」的感覺；> 3s 明顯卡。
- **「說完→第一聲」的組成**：目前 `ProcessVoiceTurnInteractor` 等 LLM **全文**完成才開始 TTS（`.replyCompleted` → `.speaking` → `speak(整段)`），所以這段 ≈ `STT + LLM 全文 + TTS 起播`。SSE 串流只先讓**字幕**長出（`STT + LLM TTFT`），**不**加速聲音。
- 依 baseline，**先打 STT**（~1.9s，最大宗）：較小的 Whisper 模型 / GPU / on-device STT。
- 其次 **逐句 TTS**：把 `speak(整段)` 改成「LLM 串流時逐句送進 TTS」，可把「說完→第一聲」從 `STT + LLM 全文` 降到約 `STT + LLM 首句`，長回覆收益最大。

---

## 相關文件

- [音訊處理流程](Audio_Pipeline.md)（VAD / 降採樣的 CPU 工作）
- [API 整合方式](API_Integration.md)（伺服器端點與 SSE）
- [狀態機設計](State_Machine.md)
