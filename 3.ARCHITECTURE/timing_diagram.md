# H03 · Giản đồ thời gian (Timing Diagram)

> Charter mục 2 câu 1 và Charter mục 9 đều yêu cầu chứng minh bằng waveform có chú thích.
> Tài liệu này cung cấp giản đồ đầy đủ một giao dịch SPI, có đánh số chu kỳ, đọc từ RTL thật.

---

## 0. Quy ước đọc giản đồ

| Điều | Nội dung |
|---|---|
| **Nguồn** | Vẽ từ `04_IMPLEMENTATION/rtl/h03_spi_master.sv`, cấu hình **đúng như testbench thật**: `HALF_CYCLES = 2`, `MSB_FIRST = 1`, clock **10 ns**, `tx_data = 0x96`. |
| **Đánh số chu kỳ** | `E(n)` = cạnh lên clock thứ `n`, `E(0)` tại `t = 5 ns`, `E(n)` tại `t = 5 + 10n` ns. |
| **Ngữ nghĩa cột** | Giá trị ghi trong cột `E(n)` là giá trị **sau** cạnh `E(n)` (mọi đầu ra đều là gán không chặn). |
| **Chu kỳ SCLK** | `2 × HALF_CYCLES = 4` chu kỳ clock = **40 ns** ⟹ `f_sclk = f_clk / 4`. |
| ⚠️ **Giới hạn** | Waveform **mô phỏng hành vi (zero-delay)**: không có clk→Q của `dfxtp_1`, không có độ trễ cổng, không có **skew giữa ba pad** `sclk`/`mosi`/`cs_n`, không có RC. Độ trễ thật chỉ có ở L4/L5 — **cả hai chưa chạy**. Với một khối SPI, **skew tại pad là rủi ro vật lý lớn nhất** và giản đồ này **không** minh hoạ được nó. |

`0x96 = 1001_0110` ⟹ MSB-first: `b7=1, b6=0, b5=0, b4=1, b3=0, b2=1, b1=1, b0=0`.

---

## 1. Giản đồ dạng sóng — MỘT GIAO DỊCH SPI TRỌN VẸN

### 1.1 Nửa đầu (`E0` … `E19`)

```
 chu kỳ  E0 E1 │E2 E3 E4 E5 E6 E7 │E8 E9 10 11 12 13 14 15 │16 17 18 19
 t (ns)   5 15 │25 35 45 55 65 75 │85 95 …             165 │165 …    205
        ───────┼──────────────────┼────────────────────────┼────────────
 start    0  0 │ 1  0  0  0  0  0 │ 0  0  0  0  0  0  0  0 │ 0  0  0  0
        ───────┼──────────────────┼────────────────────────┼────────────
 state   IDLE  │      T R A N S F E R                                  →
 half_cnt 0  0 │ 0  1  0  1  0  1 │ 0  1  0  1  0  1  0  1 │ 0  1  0  1
 edge_cnt 0  0 │ 0  0  1  1  1  1 │ 2  2  2  2  3  3  3  3 │ 4  4  4  4
        ───────┼──────────────────┼────────────────────────┼────────────
 cs_n     1  1 │ 0  0  0  0  0  0 │ 0  0  0  0  0  0  0  0 │ 0  0  0  0
          ▔▔▔▔▔│▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁
        ───────┼──────────────────┼────────────────────────┼────────────
 sclk     0  0 │ 0  0  1  1  0  0 │ 1  1  0  0  1  1  0  0 │ 1  1  0  0
          ▁▁▁▁▁│▁▁▁▁▁┌────┐▁▁▁▁▁┌────┐▁▁▁▁▁┌────┐▁▁▁▁▁┌────┐▁▁▁▁▁┌────┐
                     │    │     │    │     │    │     │    │     │
                    ▲R1   ▼F1  ▲R2  ▼F2  ▲R3  ▼F3  ▲R4  ▼F4  ▲R5
        ───────┼──────────────────┼────────────────────────┼────────────
 mosi     0  0 │ 1  1  1  1  0  0 │ 0  0  0  0  1  1  1  1 │ 0  0  0  0
          ▁▁▁▁▁│▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▔▔▔▔▔▔▔▔▔▔▔▁▁▁▁▁▁▁
               │   b7 = 1        │   b6=0 │  b5=0  │  b4=1  │  b3=0
        ───────┼──────────────────┼────────────────────────┼────────────
 miso     ?  ? │ (do chip tớ lái — đổi ở SƯỜN XUỐNG, ổn định trước SƯỜN LÊN)
 rx_shift 00 00│ 00 00 s7 s7 s7 s7│ …
        ───────┼──────────────────┼────────────────────────┼────────────
 busy     0  0 │ 1  1  1  1  1  1 │ 1  1  1  1  1  1  1  1 │ 1  1  1  1
 done     0  0 │ 0  0  0  0  0  0 │ 0  0  0  0  0  0  0  0 │ 0  0  0  0
```

### 1.2 Nửa sau (`E20` … `E36`)

```
 chu kỳ  20 21 22 23 │24 25 26 27 │28 29 30 31 │32 33 34 │35 │36
 t (ns) 205 …    245 │245 …   285 │285 …   325 │325 345  │355│365
        ─────────────┼────────────┼────────────┼─────────┼───┼───
 state        T R A N S F E R                            │FIN│IDLE
 edge_cnt 5  5  5  5 │ 6  6  6  6 │ 7  7  7  7 │ 8  8  8 │ 8 │ 0
        ─────────────┼────────────┼────────────┼─────────┼───┼───
 cs_n     0  0  0  0 │ 0  0  0  0 │ 0  0  0  0 │ 0  0  0 │ 1 │ 1
          ▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁│▔▔▔▔▔▔▔
        ─────────────┼────────────┼────────────┼─────────┼───┼───
 sclk     1  1  0  0 │ 1  1  0  0 │ 1  1  0  0 │ 1  1  0 │ 0 │ 0
          ┌────┐▁▁▁▁▁┌────┐▁▁▁▁▁┌────┐▁▁▁▁▁┌────┐▁▁▁▁▁▁▁▁▁▁▁▁▁▁
          │    │     │    │     │    │     │    │
         ▲R5  ▼F5   ▲R6  ▼F6   ▲R7  ▼F7   ▲R8  ▼F8
        ─────────────┼────────────┼────────────┼─────────┼───┼───
 mosi     0  0  1  1 │ 1  1  1  1 │ 1  0  0  0 │ 0  0  0 │ 0 │ 0
          ▁▁▁▁▁▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁
            b3=0 │ b2=1  │  b1=1  │  b0=0 ────────▶ giữ nguyên
        ─────────────┼────────────┼────────────┼─────────┼───┼───
 rx_data  00 00 00 00│00 00 00 00 │00 00 00 00 │00 00 00 │ s │ s
        ─────────────┼────────────┼────────────┼─────────┼───┼───
 busy     1  1  1  1 │ 1  1  1  1 │ 1  1  1  1 │ 1  1  1 │ 0 │ 0
 done     0  0  0  0 │ 0  0  0  0 │ 0  0  0  0 │ 0  0  0 │ 1 │ 0
                                                         ▔▔▔▔▔│▁▁▁
                                                    XUNG 1 CHU KỲ
```

## 2. Bảng mốc sự kiện (đánh số chu kỳ)

| Chu kỳ | `t` (ns) | Sự kiện | Dòng RTL |
|:-:|---:|---|:-:|
| `E0`–`E1` | 5–15 | `rst_n = 0` rồi nhả; `sclk = 0`, `cs_n = 1` | 31–42 |
| **`E2`** | **25** | `start` ⟹ `cs_n ← 0`, `busy ← 1`, `tx_shift ← 0x96`, `rx_shift ← 0`, **`mosi ← b7 = 1`**, `state ← TRANSFER` | 54–62 |
| `E3` | 35 | `half_count` 0→1 | 95 |
| **`E4`** | **45** | **SƯỜN LÊN #1** — `sclk ← 1`, **lấy mẫu `miso`**, `edge_count ← 1` | 71–77 |
| **`E6`** | **65** | **SƯỜN XUỐNG #1** — `sclk ← 0`, `tx_shift << 1`, **`mosi ← b6 = 0`** | 78–92 |
| `E8` | 85 | SƯỜN LÊN #2 — `edge_count ← 2` | |
| `E10` | 105 | SƯỜN XUỐNG #2 — `mosi ← b5 = 0` | |
| `E12` / `E14` | 125 / 145 | LÊN #3 / XUỐNG #3 — `mosi ← b4 = 1` | |
| `E16` / `E18` | 165 / 185 | LÊN #4 / XUỐNG #4 — `mosi ← b3 = 0` | |
| `E20` / `E22` | 205 / 225 | LÊN #5 / XUỐNG #5 — `mosi ← b2 = 1` | |
| `E24` / `E26` | 245 / 265 | LÊN #6 / XUỐNG #6 — `mosi ← b1 = 1` | |
| `E28` / `E30` | 285 / 305 | LÊN #7 / XUỐNG #7 — `mosi ← b0 = 0` | |
| **`E32`** | **325** | **SƯỜN LÊN #8** — lấy mẫu `miso` lần cuối, `edge_count ← 8` | |
| **`E34`** | **345** | **SƯỜN XUỐNG #8** — `sclk ← 0`; `edge_count == 8` ⟹ `state ← FINISH`. **`mosi` KHÔNG đổi** | 82–83 |
| **`E35`** | **355** | `FINISH`: `cs_n ← 1`, `busy ← 0`, **`rx_data ← rx_shift`**, **`done ← 1`**, `state ← IDLE` | 99–106 |
| `E36` | 365 | `IDLE`: `done ← 0` (xung kết thúc). Sớm nhất mới nhận `start` mới | 44, 47–53 |

**Kiểm chứng với mô phỏng thật:** testbench dùng `wait(done)` rồi `$finish`. `done` lên sau
cạnh `E35` = `t = 355 ns`. `simulation.log` ghi `$finish called at 355` ✅ — **khớp chính xác**.

**Kiểm chứng MOSI:** chuỗi đọc từ giản đồ `1,0,0,1,0,1,1,0` trùng với mô hình chuẩn Python
`tx_sequence(0x96, True) == [1,0,0,1,0,1,1,0]` (`reference_model.py`, `test_tx_order`).
⚠️ **Nhưng testbench KHÔNG kiểm `mosi`** — xác nhận này đến từ **đọc mã**, không từ mô phỏng.

## 3. Đếm xung — trả lời Charter mục 8 ("kiểm CS bao trọn 8 xung SCLK")

| Xung | Sườn LÊN tại | Sườn XUỐNG tại |
|:-:|:-:|:-:|
| 1 | `E4` (45 ns) | `E6` (65 ns) |
| 2 | `E8` (85) | `E10` (105) |
| 3 | `E12` (125) | `E14` (145) |
| 4 | `E16` (165) | `E18` (185) |
| 5 | `E20` (205) | `E22` (225) |
| 6 | `E24` (245) | `E26` (265) |
| 7 | `E28` (285) | `E30` (305) |
| **8** | **`E32`** (325) | **`E34`** (345) |

**Đúng 8 sườn lên và 8 sườn xuống.** Công thức tổng quát: sườn lên thứ `k` tại
`E(s + (2k−1)·HC)`, sườn xuống thứ `k` tại `E(s + 2k·HC)`, với `E(s)` = cạnh nhận `start`.

Testbench kiểm `assert(rise_count == 8)` ✅ và `assert(fall_count >= 8)` ✅.

## 4. CS bao trọn 8 xung — trả lời Charter mục 2 câu 1 ("chỉ vào hai mốc")

> **Hai mốc cần chỉ:**

```
        MỐC 1                                              MỐC 2
          │                                                   │
          ▼                                                   ▼
 cs_n ────┐E2                                          E35    ┌────
          └───────────────────────────────────────────────────┘
          │◀─ 2 ck ─▶│                            │◀─ 1 ck ─▶│
          │          │                            │          │
 sclk ────┴──────────┌──┐  ┌──┐ … ┌──┐  ┌──────┐──┴──────────┴────
                     E4                          E34
                     ▲                            ▲
                SƯỜN LÊN #1                 SƯỜN XUỐNG #8
```

| Mốc | Sự kiện | Thời điểm | Khoảng cách |
|:-:|---|---|---|
| **1** | `cs_n` xuống **trước** sườn lên #1 | `E2` (25 ns) vs `E4` (45 ns) | **20 ns = 2 chu kỳ clock = `HALF_CYCLES`** |
| **2** | `cs_n` lên **sau** sườn xuống #8 | `E35` (355 ns) vs `E34` (345 ns) | **10 ns = 1 chu kỳ clock** |

**Kết luận: CS bao trọn 8 xung SCLK.** Khoảng CS thấp là `[25 ns, 355 ns]` = **330 ns**, chứa
trọn cả 8 sườn lên (45…325 ns) và 8 sườn xuống (65…345 ns).

### ⚠️ Biên CS **bất đối xứng** — một phát hiện quan trọng

| Biên | Công thức | Phụ thuộc `HALF_CYCLES`? |
|---|---|:-:|
| `t_CS_setup` (CS xuống → sườn lên #1) | **`HALF_CYCLES × T_clk`** | ✅ **có** |
| `t_CS_hold` (sườn xuống #8 → CS lên) | **`1 × T_clk`** | ❌ **KHÔNG** |

Biên sau là **hằng số một chu kỳ clock hệ thống**, bất kể `HALF_CYCLES` đặt bằng bao nhiêu.
Nếu datasheet của chip cảm biến yêu cầu `t_CS_hold` lớn hơn một chu kỳ clock, **H03 không đáp
ứng và không có tham số nào chỉnh được**. Cách khắc phục sẽ là kéo dài `FINISH` thành vài chu
kỳ. ⬜ **Chưa kiểm** với datasheet cảm biến đích.

## 5. Trả lời Charter mục 9 — khoảng setup mà bên tớ được hưởng

> *"SPI mode 0 quy định dữ liệu đổi ở sườn xuống và lấy mẫu ở sườn lên. Chứng minh thiết kế
> của mình làm đúng bằng waveform có chú thích — nêu rõ khoảng thiết lập (setup) mà bên tớ
> được hưởng."*

### 5.1 Chứng minh "đổi ở sườn xuống, lấy mẫu ở sườn lên"

| Khẳng định | Bằng chứng trên waveform | Bằng chứng trong RTL |
|---|---|---|
| MOSI **chỉ** đổi ở sườn **xuống** | `mosi` đổi tại `E6, E10, E14, E18, E22, E26, E30` — **đúng 7 sườn xuống đầu**; **không** đổi tại `E4, E8, …, E32` (các sườn lên) | `mosi <= tx_shift[6]` nằm trong nhánh `else` (`sclk == 1`), dòng 87 |
| MISO **chỉ** được lấy mẫu ở sườn **lên** | `rx_shift` đổi tại `E4, E8, E12, …, E32` — đúng 8 sườn lên | `rx_shift <= {rx_shift[6:0],miso}` nằm trong nhánh `sclk == 1'b0`, dòng 74 |
| Bit đầu có mặt **trước** sườn lên #1 (**CPHA = 0**) | `mosi = b7 = 1` từ `E2`, sườn lên #1 ở `E4` | `mosi <= tx_data[7]` cùng lúc `cs_n <= 0`, dòng 56 + 60 |

### 5.2 Khoảng setup — số liệu

```
   mosi đổi tại sườn XUỐNG #k          chip tớ lấy mẫu tại sườn LÊN #(k+1)
              │                                      │
              ▼                                      ▼
    ──────────┬──────────────────────────────────────┬────────
              │◀─────── t_setup = HALF_CYCLES × T_clk ───────▶│
                        = nửa chu kỳ SCLK
```

| Đoạn | `HALF_CYCLES = 2` (testbench) | `HALF_CYCLES = 4` (mặc định) | Công thức |
|---|---:|---:|---|
| Bit đầu (`E2 → E4`) | **20 ns** | **40 ns** | `HALF_CYCLES × T_clk` |
| Mọi bit sau (`E6 → E8` …) | **20 ns** | **40 ns** | `HALF_CYCLES × T_clk` |
| Nửa chu kỳ SCLK | 20 ns | 40 ns | như trên |
| Chu kỳ SCLK | 40 ns | 80 ns | `2 × HALF_CYCLES × T_clk` |
| `f_sclk` | 25 MHz | 12,5 MHz | `f_clk / (2·HALF_CYCLES)` |

> **Khoảng setup của bên tớ = đúng NỬA chu kỳ SCLK, đồng đều cho MỌI bit, kể cả bit đầu.**
> Đây là tính chất **INV-11** và là điều đáng khen nhất của thiết kế: bit đầu tiên không bị
> "hẹp hơn" như một số hiện thực sai.

⚠️ **Con số `T_clk = 10 ns` là GIẢ ĐỊNH** của `04_IMPLEMENTATION/constraints/design.sdc`,
**không** phải khẳng định H03 chạy được ở 100 MHz. Các giá trị ns ở trên là **tỉ lệ theo chu
kỳ clock**, không phải cam kết tần số.

### 5.3 Khoảng setup cho chiều ngược lại (MISO → H03)

Bên tớ đổi MISO ở sườn xuống; H03 lấy mẫu tại cạnh clock nâng `sclk` lên. Vì
`sclk <= 1'b1` là gán không chặn, H03 bắt giá trị `miso` đã **ổn định suốt toàn bộ pha SCLK
thấp** ⟹ cũng được **nửa chu kỳ SCLK**.

**Nhưng** ngân sách thật phải trừ đi độ trễ vòng: `t_clk→Q của tớ` + `độ trễ pad và dây` × 2.
H03 **không có bộ đồng bộ** trên `miso` (`datapath.md` §5), nên nếu tổng đó vượt
`HALF_CYCLES × T_clk`, việc lấy mẫu sẽ sai. ⬜ **Chưa phân tích định lượng** — cần số liệu bo
mạch đích.

## 6. Chu kỳ lặp khi truyền liên tục

```
 …E32 E33 E34 │ E35 │ E36 │ E37 …
   R8      F8 │ FIN │IDLE │START mới sớm nhất
 cs_n ▁▁▁▁▁▁▁▁│▔▔▔▔▔│▔▔▔▔▔│▁▁▁▁▁
 done ▁▁▁▁▁▁▁▁│▔▔▔▔▔│▁▁▁▁▁│▁▁▁▁▁
                     ▲
                     └─ 1 chu kỳ IDLE BẮT BUỘC
```

Tại `E35` (`FINISH`), RTL chỉ gán `state <= IDLE`; việc lấy mẫu `start` thuộc nhánh `IDLE`,
chỉ chạy ở **cạnh sau đó** (`E36`).

```
 chu kỳ/byte khi truyền liên tục = 16 × HALF_CYCLES + 2
```

| `HALF_CYCLES` | Lý tưởng (`16·HC`) | Thực tế | Chênh |
|---:|---:|---:|---:|
| 2 (testbench) | 32 ck | **34 ck** | +6,25 % |
| **4 (mặc định)** | 64 ck | **66 ck** | **+3,13 %** |
| 8 | 128 ck | **130 ck** | +1,56 % |

Hai chu kỳ thừa (`FINISH` + `IDLE`) là **độ trễ cố định**, không gây trôi nhịp — xem
`fsm.md` §6.

## 7. Ca xấu nhất / tốt nhất về lan truyền tổ hợp

H03 là mạch tuần tự; "ca xấu nhất" là đường tổ hợp dài nhất giữa hai cạnh clock.

| Ca | Đường | Arrival | Slack |
|---|---|---:|---:|
| **Xấu nhất** | `start → _137_ (nor3b_1, fanout 10, slew 0,77) → _138_ (a22oi_1) → _139_ (a21boi_0) → _241_/D` | **1,90 ns** | **+8,02 ns** |
| Gần xấu nhất | `start → _137_ → _195_ (a22oi_1) → _196_ (a21boi_0) → _260_/D` | 1,90 ns | +8,02 ns |

Nguồn: `06_GDSII/sta/timing_report_max.txt`. Hai đường có arrival **bằng nhau tới từng phần
trăm ns** — dấu hiệu của một **nhóm bit song song** (đường nạp `tx_shift <= tx_data`).
**1,00 ns trong 1,90 ns là input delay GIẢ ĐỊNH**; logic thật chỉ **0,90 ns**.

**Vùng glitch:** ở mức RTL/zero-delay **không** có glitch nào, vì `sclk`, `mosi`, `cs_n` đều
là **đầu ra thanh ghi**. Ở mức gate-level, glitch có thể xuất hiện trên các nút tổ hợp nội bộ
(`_036_`, `_037_`, `_018_`) trong khoảng `0…1,90 ns` sau mỗi cạnh clock nhưng bị flip-flop
chặn lại.

> ⚠️ **Rủi ro vật lý lớn nhất của H03 KHÔNG nằm trong giản đồ này: skew giữa ba pad.**
> `sclk`, `mosi` và `cs_n` đi ra **ba pad khác nhau**. Ở RTL chúng đổi "cùng lúc"; sau P&R
> chúng lệch nhau vài trăm ps. Nếu `mosi` tới pad **muộn hơn** `sclk`, khoảng setup của chip
> tớ bị ăn mòn; nếu một glitch xuất hiện trên `sclk`, chip tớ đếm **thừa một xung** và lệch cả
> byte. Cả hai chỉ kiểm được ở **L5 (post-layout + SDF)** — **chưa chạy**. Xem
> `corner_cases.md` §6.

## 8. Một chi tiết nhỏ: `mosi` sau khi giao dịch kết thúc

Từ `E30` trở đi, `mosi` giữ giá trị `b0 = 0` **vô hạn** — `FINISH` và `IDLE` đều **không** gán
`mosi`. Vô hại (vì `cs_n = 1`, chip tớ không nghe), nhưng đáng biết: **`mosi` không có giá trị
rỗi xác định**. Nếu cần một mức rỗi cố định (ví dụ để giảm dòng rò trên dây, hoặc để dễ đọc
waveform khi gỡ lỗi), có thể thêm `mosi <= 1'b0;` vào nhánh `IDLE`. Chi phí: 0 flip-flop.
**Chưa áp dụng** — cần thầy duyệt.

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
