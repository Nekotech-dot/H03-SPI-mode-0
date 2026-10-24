# H03 · Đặc tả chức năng (Functional Specification)

---

## 0. Đối chiếu Charter mục 4 — **ĐẠT** (kèm hai lưu ý)

Khác H01 và H02, **RTL của H03 cung cấp đủ mọi cổng mà Charter mục 4 yêu cầu.**

| Chân Charter | Vai trò | Tín hiệu RTL | Trạng thái |
|---|---|---|:-:|
| `ui_in[7:0]` | byte gửi | `tx_data[7:0]` | ✅ |
| `uio_in[0]` | bắt đầu | `start` | ✅ |
| `uio_in[1]` | MISO | `miso` | ✅ |
| `uo_out[0]` | SCLK | `sclk` | ✅ |
| `uo_out[1]` | MOSI | `mosi` | ✅ |
| `uo_out[2]` | CS | `cs_n` | ✅ (tích cực **thấp**) |
| `uio_out[7:0]` | byte nhận | `rx_data[7:0]` | ✅ |
| — | *(ngoài Charter)* | `busy` | ➕ thừa, hữu ích |
| — | *(ngoài Charter)* | `done` | ➕ thừa, hữu ích |

### Lưu ý 1 — ngân sách chân sau khi cộng `busy` và `done`

| Hạng mục | Charter dự tính | RTL thật |
|---|---:|---:|
| Bit vào | 10 | **10** |
| Bit ra | 11 | **13** (thêm `busy`, `done`) |
| **Tổng** | **21 / 24** | **23 / 24** |

Vẫn **vừa** 24 chân, nhưng chỉ còn **1 chân dư**. Ánh xạ bắt buộc phải là: `ui_in[7:0]` ←
`tx_data`; `uo_out[7:0]` ← 8 trong 13 bit ra; `uio` ← 2 chân vào (`start`, `miso`) + 5 chân ra.
Tổng `uio` dùng 7/8. Đây đúng là điều Charter mục 4 đã cảnh báo:
*"chân `uio[0, 1]` bị gán vừa làm đầu vào vừa làm đầu ra… chỉ cần đánh số lại."*

### Lưu ý 2 — ⚠️ một lỗi tiềm ẩn **không** liên quan tới cổng

FSM của H03 dùng `enum logic [1:0]` cho **3** trạng thái ⟹ có **1 mã thừa** (`2'b11`), nhưng
khối `case (state)` (dòng 46) **KHÔNG có nhánh `default`**. Nếu `state` rơi vào `2'b11`,
FSM **kẹt vĩnh viễn**. Chi tiết và bản vá: `03_ARCHITECTURE/fsm.md` §5.2.

> **Kết luận §0: H03 THOẢ Charter mục 4.** Khiếm khuyết của H03 nằm ở chỗ khác (Lưu ý 2 và
> §8), không phải ở giao diện.

---

## 1. Khối này làm gì

H03 là **chủ SPI (SPI master) chế độ 0**: trao đổi **đồng thời** một byte đi và một byte về
trên hai dây dữ liệu, dùng một dây clock **do chính nó sinh ra**.

```
        ┌──── CS thấp: một giao dịch 8 bit ────────────────────────────┐
 cs_n ──┐                                                             ┌──
        └─────────────────────────────────────────────────────────────┘
          ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐
 sclk ────┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └────────────────
          1     2     3     4     5     6     7     8   ← ĐÚNG 8 xung
      ┌─────┬─────┬─────┬─────┬─────┬─────┬─────┬─────┐
 mosi │ b7  │ b6  │ b5  │ b4  │ b3  │ b2  │ b1  │ b0  │  MSB-first
      └─────┴─────┴─────┴─────┴─────┴─────┴─────┴─────┘
      ┌─────┬─────┬─────┬─────┬─────┬─────┬─────┬─────┐
 miso │ s7  │ s6  │ s5  │ s4  │ s3  │ s2  │ s1  │ s0  │  từ chip tớ
      └─────┴─────┴─────┴─────┴─────┴─────┴─────┴─────┘
         ▲     ▲     ▲     ▲     ▲     ▲     ▲     ▲
      lấy mẫu MISO tại SƯỜN LÊN (mode 0)
```

### Chế độ 0 nghĩa là gì (Charter mục 2, câu 2)

| Tham số | Giá trị chế độ 0 | Hệ quả |
|---|---|---|
| **CPOL = 0** | SCLK **nghỉ ở mức thấp** | Giữa hai giao dịch `sclk = 0` |
| **CPHA = 0** | Lấy mẫu ở **sườn đầu tiên** của mỗi chu kỳ SCLK = **sườn LÊN** | Đổi dữ liệu ở **sườn XUỐNG** |

Hệ quả quan trọng nhất của **CPHA = 0**: **bit đầu tiên phải có mặt trên MOSI TRƯỚC sườn lên
thứ nhất** — tức là ngay khi CS xuống thấp, chứ không phải chờ một sườn SCLK. Đây là chi tiết
phân biệt mode 0 với mode 1, và là chỗ rất nhiều thiết kế làm sai.

RTL làm đúng điều đó (dòng 60):

```systemverilog
if (start) begin
    …
    cs_n <= 1'b0;
    mosi <= MSB_FIRST ? tx_data[7] : tx_data[0];   // ← bit đầu ra CÙNG LÚC với CS
    state <= TRANSFER;
end
```

## 2. Định nghĩa chính xác từng đầu ra theo đầu vào

Ký hiệu: `HC = HALF_CYCLES` (mặc định 4; testbench dùng 2), `E(n)` = cạnh lên clock thứ `n`,
`E(s)` = cạnh nhận lệnh `start`.

| Đầu ra | Định nghĩa |
|---|---|
| `cs_n` | `0` từ `E(s)` tới `E(s + 16·HC + 1)`; `1` ngoài khoảng đó |
| `sclk` | Sườn **lên** thứ `k` tại `E(s + (2k−1)·HC)`, sườn **xuống** thứ `k` tại `E(s + 2k·HC)`, `k = 1…8`. Chu kỳ SCLK = `2·HC` chu kỳ clock. |
| `mosi` | `tx_data[7]` từ `E(s)`; đổi sang `tx_data[7−k]` tại sườn **xuống** thứ `k` (`k = 1…7`); **không** đổi tại sườn xuống thứ 8 |
| `rx_data[7:0]` | Cập nhật **một lần** tại `E(s + 16·HC + 1)`, bằng 8 giá trị `miso` lấy tại 8 sườn **lên**, MSB-first |
| `busy` | `1` từ `E(s)` tới `E(s + 16·HC + 1)` |
| `done` | **Xung đúng 1 chu kỳ** tại `E(s + 16·HC + 1)` |

### 2.1 Tần số SCLK

```
   f_sclk = f_clk / (2 × HALF_CYCLES)
```
Mô hình chuẩn Python kiểm đúng công thức này
(`05_VERIFICATION/golden_model/reference_model.py`, `test_divider`):
`half = round(fclk/(2*fsclk))` với `fclk = 16 MHz`, `fsclk = 1 MHz` cho `half = 8`.

### 2.2 `done` là **xung**, không phải mức

RTL bảo đảm bằng `done <= 1'b0;` vô điều kiện ở dòng 44 (chạy mọi chu kỳ), chỉ bị ghi đè tại
`FINISH`. Cùng kiểu mã "gán mặc định rồi ghi đè" như `data_new` của H02.

## 3. Bảng hành vi theo trạng thái

| Trạng thái | Điều kiện vào | Thời lượng | `sclk` | `cs_n` | `busy` | `done` |
|---|---|:-:|:-:|:-:|:-:|:-:|
| `IDLE` | reset / sau `FINISH` | ≥ 1 ck | `0` | `1` | `0` | `0` |
| `TRANSFER` | `start = 1` tại `IDLE` | `16·HC` ck | đảo mỗi `HC` ck | `0` | `1` | `0` |
| `FINISH` | sườn xuống thứ 8 | **1 ck** | `0` | `1` | `0` | **`1`** |

## 4. Ràng buộc cấu trúc bắt buộc

Tên đề — "Chủ SPI **chế độ 0**" — chốt **giao thức**, và các ràng buộc sau phải hiện diện
**tường minh** trong RTL:

| Ràng buộc | Phải thấy trong RTL | Có trong `h03_spi_master.sv`? |
|---|---|:-:|
| CPOL = 0: SCLK nghỉ thấp | `sclk <= 1'b0` ở `IDLE`, `FINISH` và reset | ✅ dòng 38, 48, 100 |
| CPHA = 0: lấy mẫu MISO ở sườn **lên** | ghi `rx_shift` trong nhánh `sclk == 1'b0` (sắp lên) | ✅ dòng 71–77 |
| CPHA = 0: đổi MOSI ở sườn **xuống** | ghi `mosi` trong nhánh `else` (sclk sắp xuống) | ✅ dòng 78–92 |
| CPHA = 0: bit đầu có mặt **trước** sườn lên thứ nhất | `mosi <= tx_data[7]` cùng lúc `cs_n <= 0` | ✅ dòng 56, 60 |
| **Đúng 8** xung SCLK | đếm sườn lên tới 8 | ✅ `edge_count` tăng ở **sườn lên**, so `== 8` ở **sườn xuống** |
| CS **bao trọn** 8 xung | CS xuống trước sườn lên thứ nhất, lên sau sườn xuống thứ 8 | ✅ — xem `timing_diagram.md` §4 |
| Song công (full-duplex) thật | phát và thu trong **cùng** một vòng, không hai pha | ✅ `tx_shift` và `rx_shift` cùng chạy trong `TRANSFER` |
| MSB-first | `mosi <= tx_shift[6]`, `rx_shift <= {rx_shift[6:0], miso}` | ✅ khi `MSB_FIRST = 1` |

> **Tất cả 8 ràng buộc đều ĐẠT.** Về mặt giao thức SPI mode 0, RTL của H03 là bản đúng nhất
> trong ba đề H01/H02/H03.

## 5. Cơ chế đếm sườn — chi tiết tinh tế nhất của RTL

```systemverilog
if (half_tick) begin
    half_count <= '0;
    if (sclk == 1'b0) begin           // sắp có SƯỜN LÊN
        sclk <= 1'b1;
        rx_shift <= {rx_shift[6:0], miso};   // LẤY MẪU tại sườn lên
        edge_count <= edge_count + 1'b1;     // ← chỉ đếm SƯỜN LÊN
    end else begin                    // sắp có SƯỜN XUỐNG
        sclk <= 1'b0;
        if (edge_count == 8) state <= FINISH;
        else begin
            tx_shift <= {tx_shift[6:0],1'b0};
            mosi     <= tx_shift[6];         // ĐỔI DỮ LIỆU tại sườn xuống
        end
    end
end
```

Ba điều quan trọng:

1. **`edge_count` chỉ đếm sườn lên** ⟹ nó đúng bằng "số bit đã lấy mẫu". Sau sườn lên thứ 8,
   `edge_count = 8`.
2. **So sánh `edge_count == 8` đặt ở nhánh sườn XUỐNG**, không phải sườn lên. Nhờ vậy sườn
   xuống thứ 8 **vẫn được phát ra** (để hoàn tất chu kỳ SCLK thứ 8) rồi mới sang `FINISH`.
   Nếu đặt ở nhánh sườn lên, SCLK sẽ **kẹt ở mức cao** khi CS nhả — vi phạm CPOL = 0.
3. **Tại sườn xuống thứ 8, `mosi` KHÔNG được cập nhật** — đúng, vì không còn bit nào để gửi.

## 6. Tính chất bất biến (invariants)

| # | Phát biểu | Trạng thái |
|---|---|:-:|
| **INV-1** | `cs_n = 0` ⟹ `busy = 1` | ✅ |
| **INV-2** | Đúng **8** sườn lên và **8** sườn xuống của `sclk` mỗi giao dịch | ✅ — testbench kiểm `rise_count == 8` |
| **INV-3** | **CS bao trọn 8 xung**: `cs_n` xuống **trước** sườn lên thứ 1 và lên **sau** sườn xuống thứ 8 | ✅ |
| **INV-4** | `sclk = 0` khi `cs_n = 1` (CPOL = 0) | ✅ |
| **INV-5** | `mosi` chỉ đổi tại sườn **xuống** của `sclk` (hoặc tại lúc khẳng định CS) | ✅ |
| **INV-6** | `rx_shift` chỉ đổi tại sườn **lên** của `sclk` | ✅ |
| **INV-7** | `done` là xung 1 chu kỳ: `done \|=> !done` | ✅ (dòng 44) |
| **INV-8** | `rx_data` chỉ đổi tại chu kỳ có `done = 1` | ✅ (dòng 103–104) |
| **INV-9** | `edge_count ≤ 8` mọi lúc | ✅ |
| **INV-10** | `half_count < HALF_CYCLES` mọi lúc | ✅ |
| **INV-11** | Khoảng setup của bên tớ = `HALF_CYCLES × T_clk` cho **mọi** bit, kể cả bit đầu | ✅ — xem `timing_diagram.md` §5 |
| **INV-12** | Từ **mọi** giá trị của `state`, FSM về `IDLE` sau hữu hạn chu kỳ | ❌ **VI PHẠM** với `state = 2'b11` (thiếu `default`) |

INV-2, INV-3, INV-5, INV-6, INV-11 là năm assertion đáng bổ sung vào
`05_VERIFICATION/assertions/` — chúng đặc tả **chính xác** chế độ 0.

## 7. Trạng thái sau reset và độ trễ

`rst_n` là **reset đồng bộ**.

| Tín hiệu | Sau reset | Vì sao |
|---|---|---|
| `state` | `IDLE` | |
| `sclk` | **`0`** | **Bắt buộc** — CPOL = 0 |
| `cs_n` | **`1`** | **Bắt buộc** — không được chọn tớ nào khi chưa có giao dịch |
| `mosi` | `0` | Không quan trọng khi `cs_n = 1` (tớ không nghe) |
| `busy`, `done` | `0` | |
| `rx_data`, `rx_shift`, `tx_shift`, `half_count`, `edge_count` | `0` | ⚠️ `rx_data = 0x00` là **giá trị hợp lệ** — phải dùng `done`, không dùng `rx_data ≠ 0` |

### Độ trễ (số chu kỳ)

| Từ → Đến | Độ trễ |
|---|---|
| `start = 1` tại `E(s)` → `cs_n = 0`, `mosi` hợp lệ | **0 chu kỳ** (cùng cạnh) |
| `E(s)` → sườn lên SCLK thứ 1 | **`HALF_CYCLES`** chu kỳ |
| `E(s)` → `done` | **`16 × HALF_CYCLES + 1`** chu kỳ |
| `done` → sẵn sàng nhận `start` mới | **+1 chu kỳ** (phải qua một chu kỳ `IDLE`) |
| **Chu kỳ lặp khi truyền liên tục** | **`16 × HALF_CYCLES + 2`** chu kỳ/byte |

Với `HALF_CYCLES = 4` (mặc định): **66** chu kỳ/byte.
Với `HALF_CYCLES = 2` (testbench): **34** chu kỳ/byte.

## 8. Điều kiện biên và hành vi không xác định

| Tình huống | Hành vi RTL | Đánh giá |
|---|---|---|
| `start = 1` khi `busy = 1` | **Bị bỏ qua** — nhánh `TRANSFER`/`FINISH` không đọc `start` | An toàn nhưng **im lặng**; không có `ready`/`ack` |
| `tx_data` đổi sau khi nhận lệnh | Không ảnh hưởng — đã chốt vào `tx_shift` **và** `mosi` | ✅ Tốt |
| `rst_n = 0` giữa giao dịch | `cs_n → 1`, `sclk → 0` ngay | ✅ Đúng — nhả bus sạch. Bên tớ sẽ thấy giao dịch bị huỷ giữa chừng (đúng ngữ nghĩa SPI). |
| **`miso` là tín hiệu bất đồng bộ** | ❌ **KHÔNG có bộ đồng bộ** — `miso` đi thẳng vào `rx_shift` | ⚠️ **Rủi ro thật** — xem §8.1 |
| `state = 2'b11` | ❌ **Kẹt vĩnh viễn** — `case` không có `default` | ❌ **Lỗi tiềm ẩn** — `fsm.md` §5.2 |
| `HALF_CYCLES = 1` | Nhánh `HALF_CYCLES <= 1` (dòng 28) cho `half_tick` luôn đúng ⟹ SCLK = `f_clk/2` | Có xử lý tường minh |
| `MSB_FIRST = 0` | RTL có nhánh LSB-first đầy đủ (dòng 76, 89–90) | ⚠️ **Chưa từng được mô phỏng** — testbench cố định `MSB_FIRST = 1'b1` |
| `tx_shift[7]` sau khi nạp | **Không bao giờ được đọc** khi `MSB_FIRST = 1` | ⟹ Yosys **xoá** nó: 37 bit khai báo → **36 `dfxtp_1`**. Xem `block_diagram.md` §2.1 |

### 8.1 ⚠️ `miso` không qua bộ đồng bộ — phân tích rủi ro

| Lập luận | Nội dung |
|---|---|
| **Vì sao có thể chấp nhận** | `miso` do bên tớ lái theo **SCLK do chính H03 phát ra**, nên nó *tương quan* với `clk` của H03. Không phải tín hiệu bất đồng bộ hoàn toàn như `rx_async` của H02. |
| **Vì sao vẫn rủi ro** | Độ trễ vòng (H03 → pad → dây → chip tớ → clk→Q của tớ → dây → pad → H03) là **thời gian thật, không bị ràng buộc bởi STA của H03**. Nếu tổng độ trễ đó vượt `HALF_CYCLES × T_clk`, `miso` sẽ **chưa ổn định** tại thời điểm lấy mẫu. |
| **Biên hiện có** | `HALF_CYCLES × T_clk` = **40 ns** (mặc định `HC = 4`, `T_clk = 10 ns` giả định) |
| **So sánh** | H02 **có** bộ đồng bộ 2 tầng cho `rx_async`; H03 **không có** cho `miso`. Đây là một khác biệt kiến trúc **có chủ ý hay không** — cần thầy xác nhận. |
| **Trạng thái** | ⬜ **Chưa phân tích định lượng.** Cần: ngân sách độ trễ vòng của bo mạch đích, hoặc thêm 1–2 tầng đồng bộ (chi phí 1–2 FF) và **giảm** `f_sclk` tương ứng. |

## 9. Điều H03 **không** làm (Charter mục 3 — ngoài phạm vi)

| Không có | Bằng chứng RTL |
|---|---|
| Mode 1 / 2 / 3 | `sclk` reset về `0` và luôn bắt đầu bằng sườn lên ⟹ cứng chế độ 0 |
| Nhiều tớ | Chỉ **một** `cs_n`, không có bộ giải mã chọn tớ |
| DMA | Không có giao diện bộ nhớ |
| Truyền nhiều byte | `edge_count` so cứng với `8`; không có bộ đếm byte, không có FIFO |

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
