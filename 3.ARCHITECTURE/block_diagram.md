# H03 · Sơ đồ khối bên trong (Block Diagram)

---

## 1. Sơ đồ vẽ theo **đúng** `h03_spi_master.sv`

Toàn bộ thiết kế nằm trong **một** `always_ff @(posedge clk)` (dòng 30–109), cộng **một** dây
tổ hợp: `wire half_tick = (HALF_CYCLES <= 1) || (half_count == HALF_CYCLES-1);` (dòng 28).

```
 ┌────────────────────────── h03_spi_master ─────────────────────────────────────┐
 │                                                                               │
 │  start ──┬──▶┌──────────────────────────────┐                                 │
 │          │   │   ĐIỀU KHIỂN (FSM)           │                                 │
 │          │   │   state[1:0] · 2 FF          │──┬──────┬──────┬──────┐         │
 │          │   │   IDLE · TRANSFER · FINISH   │  │      │      │      │         │
 │          │   │   ⚠ mã 2'b11 KHÔNG có default│  │      │      │      │         │
 │          │   └──────────┬───────────────────┘  │      │      │      │         │
 │          │              │                      │      │      │      │         │
 │          │   ┌──────────▼───────────────────┐  │      │      │      │         │
 │          │   │  BỘ CHIA SCLK                │  │      │      │      │         │
 │          │   │  half_count[1:0] · 2 FF      │  │      │      │      │         │
 │          │   │  half_tick ⟺ == HALF_CYCLES-1│  │      │      │      │         │
 │          │   └──────────┬───────────────────┘  │      │      │      │         │
 │          │       half_tick                     │      │      │      │         │
 │          │              │                      │      │      │      │         │
 │          │   ┌──────────▼────────┐    ┌────────▼──┐   │      │      │         │
 │          │   │ sclk · 1 FF (đảo) │───▶│sclk == 0 ?│   │      │      │         │
 │          │   └───────┬───────────┘    └──┬─────┬──┘   │      │      │         │
 │          │           │                   │     │      │      │      │         │
 │          │           └──────────▶ sclk   │SƯỜN │SƯỜN  │      │      │         │
 │          │                               │LÊN  │XUỐNG │      │      │         │
 │          │   ┌───────────────────────┐   │     │      │      │      │         │
 │          │   │ ĐẾM SƯỜN LÊN          │◀──┘     │      │      │      │         │
 │          │   │ edge_count[3:0]· 4 FF │         │      │      │      │         │
 │          │   │ so sánh == 8 ─────────┼─────────┘      │      │      │         │
 │          │   └───────────────────────┘                │      │      │         │
 │          │                                            │      │      │         │
 │ tx_data ═╪══▶┌──────────────────────────────────┐     │      │      │         │
 │ [7:0]    │   │ THANH GHI DỊCH RA (PISO)         │     │      │      │         │
 │          │   │ tx_shift[6:0] · 7 FF             │     │      │      │         │
 │          │   │ ⚠ bit [7] BỊ XOÁ — không bao giờ │     │      │      │         │
 │          │   │   được đọc khi MSB_FIRST = 1     │     │      │      │         │
 │          │   │ dịch TRÁI ở SƯỜN XUỐNG           │     │      │      │         │
 │          │   └──────────┬───────────────────────┘     │      │      │         │
 │          │              │ tx_shift[6]                 │      │      │         │
 │          │        ┌─────▼──────┐                      │      │      │         │
 │          └───────▶│MUX: tx_data│                      │      │      │         │
 │                   │[7] / shift │                      │      │      │         │
 │                   └─────┬──────┘                      │      │      │         │
 │                   ┌─────▼──────┐                      │      │      │         │
 │                   │mosi · 1 FF │──────────────────────┼──────┼──────┼──▶ mosi │
 │                   └────────────┘                      │      │      │         │
 │                                                       │      │      │         │
 │ miso ───────────▶┌──────────────────────────────┐     │      │      │         │
 │  ⚠ KHÔNG qua bộ  │ THANH GHI DỊCH VÀO (SIPO)    │◀────┘      │      │         │
 │    đồng bộ!      │ rx_shift[7:0] · 8 FF         │            │      │         │
 │                  │ {rx_shift[6:0], miso}        │            │      │         │
 │                  │ dịch ở SƯỜN LÊN              │            │      │         │
 │                  └──────────┬───────────────────┘            │      │         │
 │                             ▼ (chỉ tại FINISH)               │      │         │
 │                  ┌──────────────────────────────┐            │      │         │
 │                  │ rx_data[7:0] · 8 FF          │────────────┼──────┼──▶rx_data│
 │                  └──────────────────────────────┘            │      │         │
 │                  ┌──────────┐ ┌──────────┐ ┌──────────┐      │      │         │
 │                  │cs_n·1 FF │ │busy·1 FF │ │done·1 FF │◀─────┴──────┘         │
 │                  └────┬─────┘ └────┬─────┘ └────┬─────┘                       │
 │                       ▼            ▼            ▼                             │
 │                     cs_n         busy         done (xung 1 ck)                │
 └───────────────────────────────────────────────────────────────────────────────┘

 Khai báo: 2+2+4+8+8+8+1+1+1+1+1 = 37 bit
 Netlist:  dfxtp_1 × 36            ← tx_shift[7] BỊ XOÁ (mã chết, chứng minh được)
```

## 2. Bảng ánh xạ cấu trúc RTL → phần cứng sinh ra

| Mã RTL (dòng) | Phần cứng sinh ra | FF khai báo | FF trong netlist | Wire trong `netlist.v` |
|---|---|:-:|:-:|---|
| `enum logic [1:0] state` (25–26) | Thanh ghi trạng thái nhị phân | 2 | 2 | `\state[0..1]` |
| `logic [HCW-1:0] half_count`, `HCW = $clog2(4) = 2` | Bộ đếm lên 2 bit + so sánh hằng | 2 | 2 | `\half_count[0..1]` |
| `logic [3:0] edge_count` (21) | Bộ đếm lên 4 bit + so sánh `== 8` | 4 | 4 | `\edge_count[0..3]` |
| `logic [7:0] tx_shift` (22) | Thanh ghi dịch **trái** nạp song song | 8 | **7** | `\tx_shift[0..6]` ← **thiếu `[7]`** |
| `logic [7:0] rx_shift` (23) | Thanh ghi dịch **trái** nối tiếp vào | 8 | 8 | `\rx_shift[0..7]` |
| `output rx_data[7:0]` | Thanh ghi ra | 8 | 8 | `wire [7:0] rx_data;` |
| `output mosi` | 1 FF + MUX 2 nguồn | 1 | 1 | `wire mosi;` |
| `output sclk` | 1 FF, đảo tại `half_tick` | 1 | 1 | `wire sclk;` |
| `output cs_n`, `busy`, `done` | 3 FF đầu ra | 3 | 3 | `wire cs_n; wire busy; wire done;` |
| `wire half_tick` (28) | 1 cây so sánh (cổng, 0 FF) | 0 | 0 | — |
| **TỔNG** | | **37** | **36** | khớp `dfxtp_1 × 36` |

### 2.1 ⭐ Phát hiện: `tx_shift[7]` là **mã chết chứng minh được**

`netlist.v` liệt kê `\tx_shift[0] ;` … `\tx_shift[6] ;` — **không có `\tx_shift[7] ;`**.
Lý do đọc thẳng từ RTL:

| Lúc nào `tx_shift[7]` được **GHI** | Lúc nào nó được **ĐỌC** |
|---|---|
| `tx_shift <= tx_data;` (dòng 57) — nhận `tx_data[7]` | **Không bao giờ** |
| `tx_shift <= {tx_shift[6:0],1'b0};` (dòng 86) — nhận `tx_shift[6]` | **Không bao giờ** |

Với `MSB_FIRST = 1`, bit MSB được gửi đi lấy **trực tiếp** từ `tx_data[7]` (dòng 60), và mọi
bit sau lấy từ `tx_shift[6]` (dòng 87). `tx_shift[7]` **không xuất hiện ở vế phải của bất kỳ
biểu thức nào**. Yosys chứng minh được điều đó bằng phân tích đơn giản (khác hẳn trường hợp
`bit_index[3]` của H01, vốn cần phân tích khả đạt mà Yosys **không** làm).

| Hệ quả | Giá trị |
|---|---|
| Tiết kiệm | **1 flip-flop = 2,8 %** tổng FF |
| Có phải lỗi không? | **Không** — hành vi hoàn toàn đúng |
| Có nên sửa RTL không? | ❌ **Không cần** — công cụ đã xử lý. Nhưng **nên biết**, vì nếu ai đó đổi `MSB_FIRST = 0`, `tx_shift[7]` sẽ **sống lại** (nhánh LSB-first đọc `tx_shift[1]` và dịch phải) ⟹ số FF thành **37** và mọi con số diện tích/công suất đổi theo. |

> 📚 **So sánh ba đề về "flip-flop bị xoá":**
>
> | Đề | FF khai báo | FF netlist | Chênh | Giải thích |
> |---|:-:|:-:|:-:|---|
> | H01 | 20 | **20** | 0 | `bit_index[3]` hằng `0` nhưng Yosys **không** chứng minh được (cần phân tích khả đạt) ⟹ **giữ lại, lãng phí** |
> | H02 | 31 | **31** | 0 | Mọi bit đều được đọc |
> | **H03** | **37** | **36** | **−1** | `tx_shift[7]` **không bao giờ được đọc** ⟹ Yosys **chứng minh được** ⟹ **xoá** |
>
> Hai trường hợp H01 và H03 minh hoạ **ranh giới năng lực của công cụ tổng hợp**: nó xoá được
> mã chết *cấu trúc* (không ai đọc) nhưng không xoá được mã chết *ngữ nghĩa* (đọc nhưng giá
> trị luôn hằng). Đây là một bài học rất đáng dạy.

### 2.2 Đối chiếu Charter mục 10 — "dấu hiệu làm đúng"

> *"8 (dịch ra) + 8 (dịch vào) + 4 (đếm bit) + chia SCLK ≈ **24–28 ô nhớ**"*

| Hạng mục Charter | Charter đoán | Đo được | Chênh |
|---|:-:|:-:|:-:|
| Dịch ra (`tx_shift`) | 8 | **7** | −1 (bị xoá, §2.1) |
| Dịch vào (`rx_shift`) | 8 | 8 | 0 |
| Đếm bit (`edge_count`) | 4 | 4 | 0 |
| Chia SCLK (`half_count`) | "…" | 2 | — |
| *(Charter bỏ quên)* `rx_data` | — | **+8** | +8 |
| *(Charter bỏ quên)* `sclk`, `mosi`, `cs_n`, `busy`, `done` | — | **+5** | +5 |
| *(Charter bỏ quên)* `state` | — | **+2** | +2 |
| **TỔNG** | **24–28** | **36** | **+8…+12** |

> 🔎 Lần này tổng **vượt hẳn** dải Charter. Nguyên nhân rõ ràng: Charter đếm hai thanh ghi
> dịch và bộ đếm bit, nhưng **bỏ quên thanh ghi ra `rx_data` (8 FF)** và **5 đầu ra thanh ghi**.
> Cùng một kiểu bỏ sót như ở H02 — nhưng ở H02 nó bị che bởi sai số ngược chiều của bộ chia
> baud, còn ở H03 bộ chia SCLK quá nhỏ (2 FF) nên **không che được**.
>
> **Kết luận:** ước lượng của Charter mục 10 có xu hướng **bỏ quên đầu ra thanh ghi**. Đây là
> phát hiện nhất quán trên cả ba đề nhóm H.

### 2.3 Vì sao `half_count` chỉ 2 bit

`HCW = $clog2(HALF_CYCLES) = $clog2(4) = 2`. Bộ chia SCLK của H03 **rẻ hơn hẳn** bộ chia baud
của UART, vì `f_sclk` chỉ cần thấp hơn `f_clk` vài lần (MHz), trong khi baud UART thấp hơn
clock hàng trăm tới hàng chục nghìn lần. Đây là khác biệt bản chất giữa **giao thức có clock
chung** và **giao thức không có clock chung**.

## 3. Sáu khối con và vai trò

| Khối | Bản chất | Vai trò trong giao thức SPI mode 0 |
|---|---|---|
| **FSM** (`state`, 2 FF) | 3 trạng thái | Phân định: chưa bắt đầu / đang truyền / kết thúc |
| **Chia SCLK** (`half_count`, 2 FF) | Đếm modulo `HALF_CYCLES` | Sinh `half_tick` ⟹ mỗi `half_tick` đảo `sclk` một lần ⟹ `f_sclk = f_clk/(2·HC)` |
| **Đếm sườn** (`edge_count`, 4 FF) | Đếm modulo 9 (0…8) | Đếm **sườn lên** = số bit đã thu; so `== 8` để kết thúc |
| **Dịch ra** (`tx_shift`, 7 FF) | PISO, dịch **trái** | MSB-first ra MOSI |
| **Dịch vào** (`rx_shift`, 8 FF) | SIPO, dịch **trái** | MSB-first từ MISO |
| **Thanh ghi ra** (`rx_data`, 8 FF) | Chốt kết quả | **Ranh giới giao dịch** — chỉ đổi khi `done` |

**Đối xứng đẹp:** `tx_shift` và `rx_shift` chạy **ngược pha** nhau — một dịch ở sườn **xuống**,
một dịch ở sườn **lên**. Chính sự lệch nửa chu kỳ đó tạo ra **khoảng setup** cho bên kia, và
đó là toàn bộ nội dung của "chế độ 0". Xem `timing_diagram.md` §5.

## 4. Khối con nào nằm trên đường tới hạn — đối chiếu `06_GDSII/sta/`

Đường tới hạn thật (`sta/summary.txt`, `timing_report_max.txt`):

```
 start ──▶ _137_ ──▶ _138_ ──▶ _139_ ──▶ _241_/D
 (cổng vào) (nor3b_1)  (a22oi_1)  (a21boi_0)  (dfxtp_1)
  1,00 ns    +0,61      +0,12      +0,18    = 1,90 ns
  (GIẢ ĐỊNH) fanout 10  fanout 1   fanout 1   slack +8,02 ns
             slew 0,77
```

| Đại lượng | Giá trị | Nguồn |
|---|---:|---|
| Startpoint | `start` (cổng vào) | `sta/summary.txt` |
| Endpoint | `_241_/D` (`dfxtp_1`) | như trên |
| Data arrival | **1,90 ns** | `timing_report_max.txt` |
| Data required | 9,92 ns | như trên |
| **Slack** | **+8,02 ns (MET)** | như trên |
| Số cell trên đường | **4** | BRIEF H03 |
| WNS / TNS | 0,00 / 0,00 | `wns.txt` · `tns.txt` |

### Đọc kết quả — bốn kết luận

**(1) Đường tới hạn là đường nạp, không phải đường dịch.**
Nó bắt đầu từ cổng `start` và kết thúc tại một flip-flop. Đường thứ hai trong báo cáo
(`start → _137_ → _195_ → _196_ → _260_`) có **cùng cấu trúc và cùng arrival 1,90 ns** — dấu
hiệu của **một nhóm bit song song**, tức là đường `tx_shift <= tx_data` / `rx_shift <= '0`
được gate bởi `start ∧ (state == IDLE)`.

**(2) `_137_` (`nor3b_1`, fanout 10) chiếm 32 % arrival.** Một mình cổng này tốn **0,61 ns**
với slew ra **0,77 ns**, trong khi `_138_` chỉ tốn 0,12 ns. Cùng "một tầng cổng", chênh **5×**.
**Fanout và slew quyết định, không phải số tầng.**

**(3) 1,00/1,90 ns là giả định.** `design.sdc` đặt `set_input_delay 1.0`. Logic **thật** chỉ
tốn **0,90 ns**.

**(4) Không khối con nào là nút thắt.** Slack +8,02 ns trên chu kỳ **giả định** 10 ns ⟹ dùng
19,2 % ngân sách — cao nhất trong ba đề nhóm H, nhưng vẫn rất dư.

### So sánh ba đề nhóm H (cùng chuỗi công cụ)

| Đề | Startpoint | Cell | Arrival | **Trừ 1,00 ns giả định** | Slack |
|---|---|:-:|---:|---:|---:|
| H01 | `valid_in` (vào) | 4 | 1,48 ns | **0,48 ns** | +8,39 |
| H02 | `state[2]` (FF) | 6 | 1,65 ns | **1,65 ns** (không có giả định) | +8,22 |
| **H03** | **`start` (vào)** | **4** | **1,90 ns** | **0,90 ns** | **+8,02** |

> H03 có arrival **cao nhất** nhưng logic nội bộ chỉ 0,90 ns — vẫn **nông hơn** H02 (1,65 ns).
> Nó "chậm" chủ yếu vì cộng giả định IO và vì `_137_` có fanout 10.

> 🔎 **Kết luận kiến trúc:** H03 **không** bị giới hạn bởi timing nội bộ. Nút thắt thật của
> một chủ SPI nằm **ngoài** chip: **độ trễ vòng của MISO** và **skew giữa `sclk`/`mosi`/`cs_n`
> tại pad** — cả hai đều **chưa được phân tích** (cần P&R và số liệu bo mạch đích).
> Xem `corner_cases.md` §6.

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
