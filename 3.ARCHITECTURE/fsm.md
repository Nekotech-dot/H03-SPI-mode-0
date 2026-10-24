# H03 · Máy trạng thái (FSM)

---

## 1. Có FSM không? — CÓ, và nó đơn giản nhất trong ba đề nhóm H

Bằng chứng trực tiếp (`04_IMPLEMENTATION/rtl/h03_spi_master.sv`, dòng 25–26):

```systemverilog
typedef enum logic [1:0] {IDLE, TRANSFER, FINISH} state_t;
state_t state;
```

| Bằng chứng | Giá trị |
|---|---|
| Netlist có `\state[0] ;`, `\state[1] ;` | `06_GDSII/synthesis/netlist.v` |
| Số flip-flop | **36** > 0 ⟹ mạch **Tuần tự** |
| Công suất nhóm Sequential | **94,0 %** (`power/power_report.txt`) |

| Đề | Trạng thái | Bit mã hoá | Mã có thể | Mã thừa | Có `default`? | Đúng? |
|---|:-:|:-:|:-:|:-:|:-:|:-:|
| H01 | 4 | 2 | 4 | **0** | Không | ✅ **đúng** (không cần) |
| H02 | 7 | 3 | 8 | **1** | **Có** | ✅ **đúng** |
| **H03** | **3** | **2** | **4** | **1** | **KHÔNG** | ❌ **SAI — thiếu** |

> **Đây là bảng dạy học giá trị nhất của cả ba đề nhóm H.** Ba đề, ba tình huống khác nhau,
> và chỉ H03 làm sai. Nó chứng minh rằng quy tắc *"luôn phải có `default`"* và quy tắc
> *"không cần `default`"* đều sai nếu học thuộc lòng — phải **đếm mã thừa**.

## 2. Sơ đồ trạng thái

```
                          rst_n = 0 (đồng bộ)
                                │
                                ▼
        ┌───────────────────────────────────────────────────────────┐
        │              start = 0                                    │
        │            ┌──────────┐                                   │
        │            │          ▼                                   │
        │         ┌──┴─────────────────────┐                        │
        └────────▶│         IDLE           │  sclk=0 · cs_n=1       │
                  │      (mã 2'b00)        │  busy=0                │
                  └───────────┬────────────┘  half_count←0          │
                              │                edge_count←0         │
                  start = 1   │  ⟹ tx_shift ← tx_data               │
                              │     rx_shift ← 0                    │
                              │     mosi ← tx_data[7]   ◀ CPHA=0!   │
                              │     cs_n ← 0 · busy ← 1             │
                              ▼                                     │
        ┌──────────────────────────────────────────┐                │
        │              TRANSFER                    │                │
        │            (mã 2'b01)                    │                │
        │                                          │                │
        │  ┌─── half_tick = 0 ──▶ half_count + 1 ──┼──┐             │
        │  │                                       │  │ tự lặp      │
        │  └───────────────────────────────────────┼──┘             │
        │                                          │                │
        │  half_tick ∧ (sclk = 0)   ── SƯỜN LÊN ───┼──┐             │
        │    ⟹ sclk ← 1                            │  │             │
        │      rx_shift ← {rx_shift[6:0], miso}    │  │ tự lặp      │
        │      edge_count + 1                      │  │ (8 lần)     │
        │                                          │  │             │
        │  half_tick ∧ (sclk = 1) ∧ (edge_cnt ≠ 8) │  │             │
        │    ── SƯỜN XUỐNG ──                      │  │             │
        │    ⟹ sclk ← 0                            │  │             │
        │      tx_shift ← tx_shift << 1            │  │             │
        │      mosi ← tx_shift[6]                  │──┘             │
        │                                          │                │
        │  half_tick ∧ (sclk = 1) ∧ (edge_cnt = 8) │                │
        │    ⟹ sclk ← 0  (hoàn tất xung thứ 8!)    │                │
        └──────────────────┬───────────────────────┘                │
                           ▼                                        │
                  ┌────────────────────────┐                        │
                  │        FINISH          │  sclk ← 0 · cs_n ← 1   │
                  │      (mã 2'b10)        │  busy ← 0 · done ← 1   │
                  │      đúng 1 chu kỳ     │  rx_data ← rx_shift    │
                  └───────────┬────────────┘                        │
                              └─────────────────────────────────────┘

        ┌────────────────────────┐
        │   mã 2'b11 — MÃ THỪA   │──▶ ❌ KHÔNG CÓ NHÁNH ⟹ KẸT VĨNH VIỄN
        └────────────────────────┘
```

## 3. Bảng chuyển trạng thái đầy đủ

`HC = HALF_CYCLES`. `tick ≡ (HC ≤ 1) ∨ (half_count == HC−1)`. `last ≡ (edge_count == 8)`.

| # | `state` | `rst_n` | `start` | `tick` | `sclk` | `last` | `state` kế | Tác động |
|:-:|---|:-:|:-:|:-:|:-:|:-:|---|---|
| 1 | bất kỳ | `0` | × | × | × | × | `IDLE` | reset 36 FF; `sclk←0`, `cs_n←1`, `busy←0`, `done←0` |
| 2 | `IDLE` | `1` | `0` | × | × | × | `IDLE` | `sclk←0`, `cs_n←1`, `busy←0`, `half_count←0`, `edge_count←0` |
| 3 | `IDLE` | `1` | `1` | × | × | × | **`TRANSFER`** | `busy←1`, `cs_n←0`, `tx_shift←tx_data`, `rx_shift←0`, `edge_count←0`, **`mosi←tx_data[7]`** |
| 4 | `TRANSFER` | `1` | × | `0` | × | × | `TRANSFER` | `half_count+1`; **datapath đóng băng** |
| 5 | `TRANSFER` | `1` | × | `1` | `0` | × | `TRANSFER` | **SƯỜN LÊN**: `sclk←1`, `rx_shift←{rx_shift[6:0],miso}`, `edge_count+1`, `half_count←0` |
| 6 | `TRANSFER` | `1` | × | `1` | `1` | `0` | `TRANSFER` | **SƯỜN XUỐNG**: `sclk←0`, `tx_shift←tx_shift<<1`, `mosi←tx_shift[6]`, `half_count←0` |
| 7 | `TRANSFER` | `1` | × | `1` | `1` | `1` | **`FINISH`** | **SƯỜN XUỐNG thứ 8**: `sclk←0`, `half_count←0`; **không** dịch, **không** đổi `mosi` |
| 8 | `FINISH` | `1` | × | × | × | × | `IDLE` | `sclk←0`, `cs_n←1`, `busy←0`, **`rx_data←rx_shift`**, **`done←1`** |
| **9** | **`2'b11`** | `1` | × | × | × | × | **`2'b11`** | ❌ **KHÔNG CÓ NHÁNH — mọi FF giữ nguyên — KẸT VĨNH VIỄN** |

Ngoài ra `done <= 1'b0;` (dòng 44) chạy **trước** `case` ở mọi chu kỳ có `rst_n = 1` — đó là
cơ chế bảo đảm `done` là xung 1 chu kỳ.

**Dòng 9 là khiếm khuyết** — xem §5.2.

## 4. Mealy hay Moore — bằng chứng

**H03 là FSM Moore đối với mọi đầu ra; cung `IDLE → TRANSFER` là cung Mealy.**

| Đầu ra | Loại | Bằng chứng |
|---|---|---|
| `sclk` | **Moore** | FF riêng; giá trị chỉ phụ thuộc lịch sử tới cạnh trước. Trong `TRANSFER`, `sclk` giữ nguyên bất kể `start` hay `miso` đổi thế nào. |
| `mosi` | **Moore** | FF riêng |
| `cs_n`, `busy`, `done` | **Moore** | FF riêng |
| `rx_data[7:0]` | **Moore** | FF; chỉ đổi tại cung `FINISH → IDLE` |

| Cung có tính Mealy | Đầu vào quyết định |
|---|---|
| `IDLE → TRANSFER` | `start` **cùng cạnh** quyết định trạng thái kế **và** giá trị nạp (`tx_shift ← tx_data`, `mosi ← tx_data[7]`, `cs_n ← 0`) |
| bên trong `TRANSFER` (sườn lên) | `miso` được ghi vào `rx_shift` ngay trong cạnh đó |

> **Cách nói chính xác:** *H03 là FSM có **đầu ra thanh ghi (Moore outputs)**; cung
> `IDLE → TRANSFER` là cung Mealy.*
>
> **Vì sao đầu ra Moore là bắt buộc ở đây — quan trọng hơn cả H01/H02:** `sclk`, `mosi` và
> `cs_n` đi **thẳng ra ba pad** tới một chip khác. Nếu chúng là đầu ra tổ hợp, mọi glitch của
> logic bên trong sẽ xuất hiện trên bus SPI. Một glitch trên `sclk` bị chip tớ đếm là **một
> xung clock thừa** ⟹ lệch toàn bộ byte. Đây là dạng hỏng nghiêm trọng nhất có thể có ở một
> chủ SPI, và nó **không** xuất hiện trong mô phỏng zero-delay.

## 5. Mã hoá trạng thái và trạng thái bất hợp lệ

### 5.1 Mã hoá

| Trạng thái | Mã |
|---|:-:|
| `IDLE` | `2'b00` |
| `TRANSFER` | `2'b01` |
| `FINISH` | `2'b10` |
| **`2'b11`** | **MÃ THỪA — không thuộc trạng thái nào** |

Yosys giữ đúng mã nhị phân 2 bit (netlist có `\state[0]`, `\state[1]`, không one-hot). Với 3
trạng thái, nhị phân là lựa chọn đúng: tiết kiệm 1 FF so với one-hot, và slack +8,02 ns cho
phép thêm một tầng giải mã thoải mái.

### 5.2 ⛔ Trạng thái bất hợp lệ — **CÓ, và RTL KHÔNG xử lý**

```
 Số mã có thể của state[1:0] = 2² = 4
 Số trạng thái được định nghĩa   = 3
 ⟹ CÓ ĐÚNG 1 MÃ THỪA: 2'b11
```

Và `case (state)` ở dòng 46 **không có nhánh `default`**:

```systemverilog
case (state)
    IDLE:     begin … end
    TRANSFER: begin … end
    FINISH:   begin … end
endcase          // ← KHÔNG CÓ default
```

**Hậu quả khi `state = 2'b11`:** không lệnh gán nào trong `case` được thực thi ⟹ mọi thanh
ghi **giữ nguyên giá trị** ⟹ `state` mãi là `2'b11`. **FSM kẹt vĩnh viễn.**

| Hậu quả cụ thể | Mức nghiêm trọng |
|---|---|
| `busy` kẹt ở giá trị cuối | Tầng ngoài có thể chờ mãi |
| **`cs_n` có thể kẹt ở `0`** | ⚠️ **Nghiêm trọng** — chip tớ bị giữ ở trạng thái được chọn, không nhả bus |
| `sclk` kẹt ở giá trị cuối | Có thể vi phạm CPOL = 0 |
| Chỉ `rst_n = 0` mới thoát | Cần reset toàn hệ thống |

### 5.3 Khi nào `state = 2'b11` có thể xảy ra?

| Nguyên nhân | Khả năng |
|---|---|
| Từ một trạng thái hợp lệ | **Không** — không có đường tới. Mọi cung đều tới `IDLE`/`TRANSFER`/`FINISH` |
| **Nhiễu hạt alpha / SEU** lật một bit `state` | **Có thể** — `2'b01 → 2'b11` hoặc `2'b10 → 2'b11` chỉ cần lật **một** bit |
| **X-propagation lúc cấp nguồn** | **Có thể** — `dfxtp_1` **không có chân reset**; trước cạnh clock đầu tiên `state` là `X`. Nếu chuỗi reset không đúng, `state` có thể ổn định về `2'b11` |

> Nguyên nhân thứ ba **không phải giả thuyết xa vời**: cả 36 flip-flop đều là `dfxtp_1` trần,
> reset được tổng hợp thành logic tổ hợp trước chân `D`. Ca kiểm tương ứng
> (**X-propagation gate-level**) **chưa chạy** — xem `corner_cases.md` §6.

### 5.4 Bản vá — **CHƯA ÁP DỤNG**

> ⚠️ Bản vá dưới đây **chưa được áp dụng**. RTL giữ nguyên bản gốc của thầy. **Cần thầy duyệt**,
> và sau đó nên chạy lại tổng hợp để xác nhận chi phí.

```diff
                 FINISH: begin
                     …
                     state <= IDLE;
                 end
+
+                default: begin          // mã 2'b11 — bắt buộc vì 3 trạng thái / 4 mã
+                    sclk  <= 1'b0;
+                    cs_n  <= 1'b1;      // NHẢ BUS — quan trọng nhất
+                    busy  <= 1'b0;
+                    state <= IDLE;
+                end
             endcase
```

| Hạng mục | Đánh giá |
|---|---|
| Chi phí flip-flop | **0** — chỉ thêm logic tổ hợp |
| Chi phí diện tích | ⬜ **chưa đo** — cần chạy lại `02_run_synth.sh`. Dự kiến vài cell, vì cây giải mã đã tồn tại |
| Chi phí timing | Dự kiến không đáng kể (slack +8,02 ns) |
| Có làm đổi hành vi hợp lệ không? | **Không** — nhánh này không có đường tới từ trạng thái hợp lệ |
| Kiểm chứng | Ca **CC-7** (`corner_cases.md` §3): ép `state = 2'b11` bằng `force`, xác nhận FSM về `IDLE` |

### 5.5 Vì sao mô phỏng hiện tại **không** phát hiện được lỗi này

`simulation.log` báo **PASS**. Lý do: `2'b11` **không có đường tới** từ trạng thái hợp lệ,
nên không kích thích thông thường nào chạm được nó. Chỉ **fault injection** (ép giá trị) mới
phủ được.

> 📚 **Bài học:** *"Mô phỏng PASS"* chỉ chứng minh các đường **có thể đi tới**. Lỗi trạng thái
> bất hợp lệ thuộc loại **không thể phát hiện bằng mô phỏng chức năng** — phải phát hiện bằng
> **đọc mã và đếm mã trạng thái**. Đây chính là giá trị của việc rà soát kiến trúc bên cạnh
> kiểm chứng.

## 6. Số chu kỳ cho một giao dịch — suy trực tiếp từ FSM

| Giai đoạn | Số cạnh clock |
|---|---|
| `IDLE` → `TRANSFER` (nhận lệnh) | 0 (cùng cạnh) |
| `TRANSFER`: 16 lần `half_tick` (8 sườn lên + 8 sườn xuống) | **`16 × HALF_CYCLES`** |
| `FINISH` | **1** |
| **Tổng từ `start` tới `done`** | **`16 × HALF_CYCLES + 1`** |
| Chu kỳ `IDLE` bắt buộc trước giao dịch kế | **+1** |
| **Chu kỳ lặp khi truyền liên tục** | **`16 × HALF_CYCLES + 2`** |

| `HALF_CYCLES` | `start → done` | Chu kỳ/byte liên tục |
|---:|---:|---:|
| 2 (testbench) | 33 ck | 34 ck |
| **4 (mặc định)** | **65 ck** | **66 ck** |
| 8 | 129 ck | 130 ck |

**Kiểm chứng với mô phỏng thật:** testbench dùng `HALF_CYCLES = 2`, `start` được lấy mẫu tại
`t = 25 ns` (cạnh `E2`); `33` chu kỳ sau là cạnh `E35` = `t = 355 ns`. `simulation.log` ghi:
`$finish called at 355` ✅ — **khớp chính xác**.

### `FINISH` tốn 1 chu kỳ — có đáng không?

**Có.** Xem `control.md` §4: `FINISH` nằm **ngoài** vòng lặp bit, nên nó chỉ là **độ trễ**
(+1,5 % ở `HALF_CYCLES = 4`), **không** gây trôi nhịp. Đối lập hoàn toàn với `S_DATA_SAMPLE`
của H02, vốn nằm **trong** vòng lặp 8 bit và gây trôi tích luỹ 1 chu kỳ mỗi bit.

> **Quy tắc rút ra, áp dụng cho mọi FSM giao thức:**
> *Một trạng thái "dọn dẹp" **ngoài** vòng lặp là **độ trễ**;
> một trạng thái "làm việc" **trong** vòng lặp là **TRÔI NHỊP**.*

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
