# H03 · Đường dữ liệu (Datapath)

---

## 1. H03 có **hai** đường dữ liệu chạy ngược pha nhau — đó là bản chất song công

H01 chỉ thu hẹp 8 → 1. H02 chỉ mở rộng 1 → 8. **H03 làm cả hai cùng lúc**, trên cùng một
chuỗi 8 chu kỳ SCLK.

```
   ĐƯỜNG RA (PISO)          dịch ở SƯỜN XUỐNG
   tx_data[7:0] ═8═▶ [tx_shift 7 FF] ─1─▶ [MUX] ─1─▶ [mosi FF] ──▶ mosi
                                            ▲
                                  tx_data[7] ┘ (bit đầu, lúc CS xuống)

   ĐƯỜNG VÀO (SIPO)         dịch ở SƯỜN LÊN
   miso ─1─▶ [rx_shift 8 FF] ═8═▶ [rx_data 8 FF] ═8═▶ rx_data[7:0]
                                        ▲
                            chỉ nạp tại FINISH
```

**Điểm mấu chốt — và đây chính là cơ chế của chế độ 0:**

```
   tx dịch ở SƯỜN XUỐNG  ──┐
                           ├── lệch nhau NỬA chu kỳ SCLK
   rx dịch ở SƯỜN LÊN    ──┘
```

Nửa chu kỳ lệch pha đó **chính là khoảng setup** mà mỗi bên được hưởng. Nó không phải là chi
tiết hiện thực — nó **là định nghĩa** của CPHA = 0.

## 2. Bảng các đường dữ liệu

| Đường | Độ rộng | Từ | Đến | Bản chất |
|---|---:|---|---|---|
| `tx_data[7:0]` | 8 | cổng vào | `tx_shift` **và** `mosi` | Dữ liệu — lấy mẫu **đúng 1 chu kỳ** (khi `IDLE ∧ start`) |
| `tx_shift[6:0]` | **7** | nội bộ | chính nó + MUX `mosi` | PISO — **bit [7] đã bị Yosys xoá**, xem `block_diagram.md` §2.1 |
| `tx_shift[6]` | 1 | `tx_shift` | MUX `mosi` | Bit kế tiếp gửi đi |
| `tx_data[7]` | 1 | cổng vào | MUX `mosi` | **Bit đầu tiên** — đi thẳng, không qua `tx_shift` |
| `mosi` | 1 | MUX | cổng ra | **Dữ liệu ra** — đầu ra thanh ghi |
| `miso` | 1 | cổng vào | `rx_shift` | **Dữ liệu vào** — ⚠️ **không** qua bộ đồng bộ |
| `rx_shift[7:0]` | 8 | `miso` nối tiếp | `rx_data` | SIPO |
| `rx_data[7:0]` | 8 | `rx_shift` | cổng ra | **Dữ liệu ra** — chỉ đổi khi `done` |
| `half_count[1:0]` | 2 | nội bộ | so sánh | Điều khiển thời gian |
| `edge_count[3:0]` | 4 | nội bộ | so sánh `== 8` | Điều khiển đếm bit |
| `state[1:0]` | 2 | nội bộ | giải mã | Điều khiển |
| `sclk`, `cs_n`, `busy`, `done` | 1 mỗi | FSM | cổng ra | Điều khiển / trạng thái ra ngoài |

**Tỉ lệ dữ liệu/điều khiển:** dữ liệu 24 bit (`tx_shift` 7 + `rx_shift` 8 + `rx_data` 8 +
`mosi` 1) so với điều khiển 8 bit (`half_count` 2 + `edge_count` 4 + `state` 2), cộng 4 bit
đầu ra trạng thái. **H03 là đề nặng dữ liệu nhất nhóm H** — hợp lý, vì nó phải giữ **ba** bản
của một byte cùng lúc.

## 3. Ba thanh ghi 8 bit — có lãng phí không?

| Thanh ghi | FF | Có bỏ được không? |
|---|:-:|---|
| `tx_shift` | 7 | **Không** — `tx_data` có thể đổi ngay sau `start` |
| `rx_shift` | 8 | **Không** — phải dồn 8 bit nối tiếp lại |
| `rx_data` | 8 | **Về kỹ thuật thì được**, nhưng **không nên** |

**Vì sao giữ `rx_data` riêng (8 FF, 22 % tổng FF):**

| Nếu xuất thẳng `rx_shift` | Hậu quả |
|---|---|
| Tầng ngoài thấy byte **đổi từng bit** suốt 8 chu kỳ SCLK | Không có thời điểm nào "byte hợp lệ" một cách hiển nhiên |
| Giao dịch bị `rst_n` cắt giữa chừng vẫn rò dữ liệu dở dang ra ngoài | Tầng ngoài có thể đọc nhầm |
| Tầng ngoài buộc phải tự chốt bằng `done` | **Chi phí 8 FF chuyển sang tầng ngoài** — tổng hệ thống không rẻ hơn |

⟹ 8 FF là giá của **ranh giới giao dịch** (INV-8), giống hệt lý lẽ của `byte_out` trong H02.
Đây là một **kiểu thiết kế nhất quán** giữa hai đề, rất đáng chỉ ra khi giảng.

## 4. Cơ chế dịch ra — vì sao `tx_shift[6]` chứ không phải `[7]`

```systemverilog
// Lúc nhận lệnh (dòng 57, 60):
tx_shift <= tx_data;
mosi     <= MSB_FIRST ? tx_data[7] : tx_data[0];   // ← bit đầu đi THẲNG

// Tại mỗi sườn xuống (dòng 85–91):
if (MSB_FIRST) begin
    tx_shift <= {tx_shift[6:0],1'b0};    // dịch TRÁI
    mosi     <= tx_shift[6];             // ← KHÔNG phải [7]
end
```

Cùng một cơ chế "nhìn trước một bit" như H01 nhưng **ngược chiều dịch**: vì `<=` là gán không
chặn, sau cạnh này `tx_shift` mới bằng `tx_shift << 1`, nên MSB mới là `tx_shift_cũ[6]`. Đọc
`tx_shift[7]` sẽ **lặp lại** bit vừa gửi.

Và chính vì `tx_shift[7]` **không bao giờ xuất hiện ở vế phải**, Yosys **xoá hẳn** nó — 37 bit
khai báo thành **36 `dfxtp_1`**.

**Kiểm chứng bằng số, `tx_data = 0x96 = 1001_0110`:**

| Sự kiện | `tx_shift` **trước** | `tx_shift[6]` | `mosi` mới | Bit đúng (MSB-first) |
|---|---|:-:|:-:|:-:|
| CS xuống | — | — (dùng `tx_data[7]`) | `1` | `b7 = 1` ✅ |
| sườn xuống #1 | `1001_0110` | `0` | `0` | `b6 = 0` ✅ |
| #2 | `0010_1100` | `0` | `0` | `b5 = 0` ✅ |
| #3 | `0101_1000` | `1` | `1` | `b4 = 1` ✅ |
| #4 | `1011_0000` | `0` | `0` | `b3 = 0` ✅ |
| #5 | `0110_0000` | `1` | `1` | `b2 = 1` ✅ |
| #6 | `1100_0000` | `1` | `1` | `b1 = 1` ✅ |
| #7 | `1000_0000` | `0` | `0` | `b0 = 0` ✅ |
| #8 | `0000_0000` | — | **không đổi** | hết bit ✅ |

Chuỗi MOSI: `1,0,0,1,0,1,1,0`. Mô hình chuẩn Python:
`tx_sequence(0x96, True) == [1,0,0,1,0,1,1,0]`
(`05_VERIFICATION/golden_model/reference_model.py`, `test_tx_order`) → **khớp hoàn toàn**.

> ⚠️ Nhưng **testbench KHÔNG kiểm `mosi`** — chuỗi trên được xác nhận bằng **đọc mã**, không
> bằng mô phỏng. Ca cần bổ sung: **CC-2** trong `corner_cases.md` §3.

## 5. Cơ chế dịch vào — điểm lấy mẫu MISO

```systemverilog
if (sclk == 1'b0) begin              // chu kỳ này sclk SẼ lên
    sclk     <= 1'b1;
    rx_shift <= {rx_shift[6:0],miso};   // ← lấy mẫu miso ngay tại đây
    edge_count <= edge_count + 1'b1;
end
```

**Chi tiết quan trọng:** `miso` được lấy mẫu tại **cùng cạnh clock** mà `sclk` được nâng lên.
Vì `sclk <= 1'b1` là gán không chặn, `sclk` chỉ thực sự lên **sau** cạnh đó. Nghĩa là:

> Chủ bắt giá trị `miso` đã **ổn định suốt toàn bộ pha SCLK thấp** — đúng bằng bit mà một chip
> tớ mode 0 trình ra để chờ sườn lên.

Đây là hành vi **đúng chuẩn**, và nó còn cho **khoảng setup lớn nhất có thể**: bên tớ có trọn
nửa chu kỳ SCLK kể từ sườn xuống trước đó.

### ⚠️ `miso` không qua bộ đồng bộ

| | H02 (`rx_async`) | **H03 (`miso`)** |
|---|---|---|
| Bộ đồng bộ | ✅ 2 tầng (`rx_meta`, `rx_sync`) | ❌ **không có** |
| Lý do có thể chấp nhận | — | `miso` do tớ lái theo **SCLK mà chính H03 phát**, nên tương quan với `clk` |
| Rủi ro còn lại | — | **Độ trễ vòng bo mạch không bị STA của H03 ràng buộc** |
| Biên hiện có | — | `HALF_CYCLES × T_clk` = **40 ns** (mặc định, `T_clk` giả định 10 ns) |

⬜ **Chưa phân tích định lượng.** Cần ngân sách độ trễ vòng của bo mạch đích, hoặc thêm 1–2
tầng đồng bộ (chi phí 1–2 FF) kèm giảm `f_sclk`. Xem `functional_spec.md` §8.1.

## 6. Đồ thị phụ thuộc và độ sâu logic

```
 ┌────────────── các đường tổ hợp GIỮA hai cạnh clock ──────────────────┐
 │                                                                      │
 │  start ──▶ AND (state==IDLE) ──┬──▶ D của tx_shift[6:0]  (nạp)       │ ← TỚI HẠN
 │            _137_ nor3b_1       ├──▶ D của rx_shift[7:0]  (xoá)       │   4 cell
 │            fanout 10           ├──▶ D của mosi, cs_n, busy           │   1,90 ns
 │                                └──▶ D của state[1:0]                 │
 │                                                                      │
 │  half_count[1:0] ──▶ so sánh == 3 (half_tick) ──┬──▶ D của sclk      │  (2 cổng)
 │                                                 ├──▶ D của tx_shift  │
 │                                                 ├──▶ D của rx_shift  │
 │                                                 └──▶ D của edge_count│
 │                                                                      │
 │  sclk (Q) ──▶ chọn nhánh sườn lên / sườn xuống ──▶ D của nhiều FF    │  (1–2 cổng)
 │                                                                      │
 │  edge_count[3:0] ──▶ so sánh == 8 ──▶ D của state                    │  (1–2 cổng)
 │                                                                      │
 │  miso ──▶ D của rx_shift[0]   (đường DỮ LIỆU — RẤT NÔNG, 1 MUX)      │
 │                                                                      │
 │  tx_shift[6] ──▶ MUX ──▶ D của mosi                                  │  (1–2 cổng)
 └──────────────────────────────────────────────────────────────────────┘
```

| Đích | Độ sâu | Arrival | Slack | Đường |
|---|:-:|---:|---:|---|
| `_241_/D` | **3 cell** | **1,90 ns** | **+8,02** | `start → nor3b_1 → a22oi_1 → a21boi_0` ← **tới hạn** |
| `_260_/D` | 3 cell | 1,90 ns | +8,02 | cùng cấu trúc, bit khác của cùng nhóm |

**Hai đường xấu nhất có arrival bằng nhau tới từng phần trăm ns** — dấu hiệu chắc chắn của
**một nhóm bit song song** được nạp cùng lúc, tức là đường `tx_shift <= tx_data`.

## 7. Dự đoán đường tới hạn từ RTL — rồi đối chiếu STA thật

### 7.1 Dự đoán trước khi xem STA

| Ứng viên | Lập luận |
|---|---|
| **(a)** Đường nạp `tx_shift <= tx_data` gate bởi `start ∧ (state == IDLE)` | Đi từ **cổng vào** ⟹ cộng input delay; fanout 8 bit |
| **(b)** So sánh `edge_count == 8` | Bộ so sánh 4 bit — rộng nhất |
| **(c)** MUX của `mosi` (chọn giữa `tx_data[7]`, `tx_shift[6]`, giữ nguyên) | Nhiều nguồn + giải mã trạng thái + giải mã sườn |

Dự đoán hợp lý nhất: **(a)**.

### 7.2 STA thật nói gì

```
Startpoint: start (input port clocked by clk)
Endpoint:   _241_ (dfxtp_1)
  1,00 ns  input external delay        ← GIẢ ĐỊNH của design.sdc
 +0,61 ns  _137_/Y  nor3b_1  (fanout 10, slew 0,77)
 +0,12 ns  _138_/Y  a22oi_1  (fanout 1)
 +0,18 ns  _139_/Y  a21boi_0 (fanout 1)
 ────────
  1,90 ns  data arrival · required 9,92 · slack +8,02 (MET)
```

**Dự đoán (a) ĐÚNG.** `_137_` (`nor3b_1`, fanout 10) chính là cổng `start ∧ (state == IDLE)`
lái nhóm thanh ghi nạp song song.

### 7.3 Ba điều STA cho biết mà RTL không cho biết

| Điều | Số liệu | Ý nghĩa |
|---|---|---|
| **53 % arrival là giả định** | 1,00 ns input delay / 1,90 ns tổng | Logic thật chỉ **0,90 ns** cho 3 cổng |
| **Fanout đắt hơn số tầng** | `_137_` fanout 10 tốn **0,61 ns**; `_138_` fanout 1 chỉ **0,12 ns** | Chênh **5×** cho cùng "một tầng cổng" |
| **Slew lan truyền** | slew ra của `_137_` là **0,77 ns** — ép `_138_` và `_139_` chậm theo | Hiệu ứng dây chuyền mà RTL hoàn toàn vô hình |

### 7.4 Vì sao dự đoán (b) sai — cơ chế

So sánh `edge_count == 8` = `edge_count == 4'b1000` rút gọn thành
`edge_count[3] ∧ ¬edge_count[2] ∧ ¬edge_count[1] ∧ ¬edge_count[0]` — **một** cổng 4 đầu vào,
một tầng. Netlist có `nor4_1 × 1`, `nor4b_1 × 1`, `o41a_1 × 1`, `or4b_1 × 1` — đúng dạng đó.
Không đường nào trong số chúng lọt vào hai đường xấu nhất.

> Cùng bài học với H01 và H02: *"bit rộng hơn = chậm hơn"* đúng với **chuỗi carry** (A01),
> **sai** với **so sánh bằng một hằng số**, vốn là cây AND song song một tầng.

### 7.5 Cell `a21boi_0 × 25` và `nand2_1 × 29` — dấu vân tay của thanh ghi dịch

`synth_stat.txt` cho thấy hai loại cell chiếm **54/156 = 35 %** toàn thiết kế:

| Cell | Số lượng | Vai trò suy ra |
|---|---:|---|
| `nand2_1` | 29 | Tầng cơ bản của các MUX 2:1 hồi tiếp (giữ / dịch) |
| `a21boi_0` | **25** | AND-OR-INVERT — **đúng dạng để dựng MUX 2:1 có enable** |

H03 có **23 flip-flop dữ liệu** (`tx_shift` 7 + `rx_shift` 8 + `rx_data` 8), mỗi bit cần một
MUX giữ/dịch/nạp. **25 ≈ 23** — con số khớp gần như một-một. Đây là bằng chứng cấu trúc rằng
phần lớn logic tổ hợp của H03 chỉ là **MUX hồi tiếp của các thanh ghi**, không phải phép toán
nào.

Tỉ lệ cổng tổ hợp/FF của H03 là **(156−36)/36 = 3,33** — **thấp nhất** trong ba đề nhóm H
(H01: 3,95; H02: 4,87). Nghĩa là H03 tuy nhiều flip-flop nhất nhưng **logic đơn giản nhất**.
Hợp lý: SPI **không** phải khôi phục nhịp, nên không cần bộ đếm rộng hay cây giải mã lớn.

## 8. Vì sao không có pipeline trong datapath

| Câu hỏi | Trả lời |
|---|---|
| Có nên chia nhỏ đường `start → tx_shift` không? | **Không** — slack +8,02 ns, dùng 19,2 % chu kỳ |
| Thông lượng bị giới hạn bởi logic không? | **Không** — bởi **giao thức**: `16 × HALF_CYCLES + 2` chu kỳ/byte, hoàn toàn do SPI và `f_sclk` của chip tớ quyết định |
| Nút thắt thật là gì? | (1) **`f_sclk_max` của chip cảm biến**; (2) **độ trễ vòng MISO**; (3) **skew tại pad** giữa `sclk`/`mosi`/`cs_n`. **Cả ba đều nằm NGOÀI chip** và **chưa được phân tích** |

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
