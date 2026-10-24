# H03 · Ca biên và ca kiểm thử (Corner Cases)

---

## 1. Testbench thật đang có gì — đọc `05_VERIFICATION/testbench/h03_spi_master_tb.sv`

Mô phỏng **PASS** (`simulation.log`: `H03 TB completed`, `$finish called at 355`). Nhưng
PASS **chứng minh được ít hơn nhiều so với vẻ ngoài của nó**.

Toàn bộ phần kiểm tra của testbench:

```systemverilog
wait(done);
assert(rise_count==8) else $fatal(1,"Expected 8 rising edges");
assert(fall_count>=8) else $fatal(1,"Expected falling edges");
assert(cs_n==1'b1)    else $fatal(1,"CS not released");
$display("H03 TB completed");
```

> ## ⛔ **`rx_data` KHÔNG BAO GIỜ ĐƯỢC KIỂM.**
> Testbench có hẳn một mô hình chip tớ (`slave_bits = 8'h3C`, dòng 17) và lái `miso`, nhưng
> **không có một `assert` nào so `rx_data` với `8'h3C`**. Nửa "thu" của một khối **song công**
> hoàn toàn nằm ngoài vùng kiểm chứng.

### 1.1 Và mô hình chip tớ của testbench **sai** — lỗi này bị che vì `rx_data` không được kiểm

```systemverilog
always @(posedge sclk) begin
    rise_count = rise_count + 1;
    if (rx_i < 8) miso = slave_bits[7-rx_i];   // ← lái MISO TẠI sườn lên
end
always @(negedge sclk) begin
    fall_count = fall_count + 1;
    rx_i = rx_i + 1;
end
```

Trong SPI mode 0, **chip tớ phải đổi MISO ở sườn XUỐNG** (và đặt bit đầu tiên khi CS xuống),
để dữ liệu ổn định **trước** sườn lên. Testbench này lái `miso` **tại sườn lên** — tức là
**sau** khi chủ đã lấy mẫu. Hậu quả: chủ luôn bắt được bit của **chu kỳ trước**.

**Truy vết, `slave_bits = 0x3C = 0011_1100`:**

| Sườn lên # | `miso` lúc chủ lấy mẫu | Giá trị TB đặt **sau đó** |
|:-:|:-:|---|
| 1 | `0` *(giá trị khởi tạo `miso = 1'b0`)* | `slave_bits[7] = 0` |
| 2 | `slave_bits[7] = 0` | `slave_bits[6] = 0` |
| 3 | `slave_bits[6] = 0` | `slave_bits[5] = 1` |
| 4 | `slave_bits[5] = 1` | `slave_bits[4] = 1` |
| 5 | `slave_bits[4] = 1` | `slave_bits[3] = 1` |
| 6 | `slave_bits[3] = 1` | `slave_bits[2] = 1` |
| 7 | `slave_bits[2] = 1` | `slave_bits[1] = 0` |
| 8 | `slave_bits[1] = 0` | `slave_bits[0] = 0` |

Chuỗi thu được (MSB-first): `0,0,0,1,1,1,1,0` ⟹ **`rx_data = 0x1E`**, không phải `0x3C`.
Đúng bằng `0x3C >> 1` — **trễ đúng một bit**.

> 🔑 **Phán xử:** lỗi nằm ở **mô hình chip tớ của testbench**, **không** ở DUT. DUT lấy mẫu
> `miso` tại đúng cạnh clock mà nó nâng `sclk` — tức là bắt giá trị đã ổn định suốt **toàn bộ**
> pha SCLK thấp, chính là bit mà một chip tớ mode 0 thật sự trình ra cho sườn lên. Đây là hành
> vi **đúng**.
>
> 📚 **Giá trị dạy học:** đây là ví dụ hoàn hảo cho câu *"một testbench PASS không chứng minh
> thiết kế đúng"*. Nếu ai đó thêm `assert(rx_data == 8'h3C)`, testbench sẽ **FAIL** — và người
> ta rất dễ đổ lỗi cho DUT thay vì sửa mô hình chip tớ.

### 1.2 Độ phủ so với Charter mục 8

| Ca Charter mục 8 | Có trong testbench? | Ghi chú |
|---|:-:|---|
| Gửi `0x00` | ❌ | Chưa có |
| Gửi `0xFF` | ❌ | Chưa có |
| Gửi `0xA5` | ❌ | Testbench dùng `0x96` |
| **Kiểm MOSI có đúng byte không** | ❌ **không kiểm** | Không có `assert` nào trên `mosi` |
| **Thu đồng thời một giá trị đã biết** | ❌ **không kiểm** | `rx_data` chưa bao giờ được so |
| Kiểm CS bao trọn 8 xung SCLK | ⚠️ **một nửa** | Có `rise_count == 8` và `cs_n == 1` lúc cuối, nhưng **không** kiểm CS đã xuống **trước** sườn lên thứ nhất |
| ≥ 2 ca tự xây dựng, có ca biên | ❌ | Chưa có |

**Testbench kiểm 3 điều; Charter mục 8 đòi 5 ca + 2 ca tự xây. Độ phủ thật: ~1,5/7.**

> Mô hình chuẩn Python thì **mạnh hơn nhiều**: `reference_model.py` có 8 nhóm test, phủ cả hai
> thứ tự bit, 5000 ca ngẫu nhiên, kiểm 8 sườn lên / 8 sườn xuống, kiểm CS bao trọn, và kiểm
> công thức chia SCLK. Tất cả PASS (`python_reference_run.log`).

## 2. Ca bắt buộc theo Charter mục 8 — vì sao chọn từng ca

| Ca | **Lý do kỹ thuật** |
|---|---|
| **Gửi `0x00`** | MOSI im ở `0` suốt 8 chu kỳ. Kiểm: bộ đếm sườn có đếm đúng khi MOSI **không đổi** không? Đây là ca làm lộ lỗi "đếm bit bằng cách dò sườn của MOSI". Cũng kiểm `tx_shift` dịch vào `1'b0` đúng. |
| **Gửi `0xFF`** | MOSI im ở `1` suốt 8 chu kỳ. Ca **duy nhất** phân biệt được "MOSI đúng" với "MOSI kẹt cao". Kết hợp với `0x00`, hai ca này chốt chặn cả hai kiểu kẹt. |
| **Gửi `0xA5`** | `1010_0101` — MOSI đổi mức ở **mọi** biên bit. Kiểm định thời chặt nhất: nếu `mosi` đổi sai sườn (ở sườn lên thay vì sườn xuống), ca này lộ ra ngay. |
| **Thu đồng thời một giá trị đã biết** | Kiểm **song công thật**. Một hiện thực "gửi xong rồi mới nhận" vẫn qua được mọi ca chỉ kiểm MOSI. Ca này là ca **duy nhất** chứng minh hai chiều chạy cùng lúc. **Hiện đang thiếu hoàn toàn.** |
| **Kiểm CS bao trọn 8 xung SCLK** | Charter mục 2 câu 1 hỏi thẳng câu này. Nếu CS lên sớm, chip tớ nhả bus giữa chừng và bit cuối mất. Nếu CS xuống muộn, chip tớ bỏ lỡ bit đầu. Phải kiểm **hai** mốc: CS xuống **trước** sườn lên #1, CS lên **sau** sườn xuống #8. |

## 3. Ca tự xây dựng bổ sung (≥ 2, có ca biên)

| # | Ca | Vì sao cần | Kỳ vọng |
|---|---|---|---|
| **CC-1** | **Kiểm `rx_data` với mô hình chip tớ ĐÚNG** (lái MISO ở sườn **xuống** + bit đầu khi CS xuống) | Vá lỗ hổng lớn nhất của testbench (§1). Đây là ca **quan trọng nhất** cần bổ sung. | `rx_data == slave_bits` |
| **CC-2** | **Kiểm `mosi` tại từng sườn lên** | Nửa "phát" cũng chưa được kiểm. Thu 8 mẫu MOSI tại 8 sườn lên và so với `tx_sequence(tx_data, True)` của mô hình chuẩn | `1,0,0,1,0,1,1,0` cho `0x96` |
| **CC-3** | **`MSB_FIRST = 1'b0`** (ca biên tham số) | RTL có nhánh LSB-first đầy đủ (dòng 76, 89–90) **chưa từng được mô phỏng**. Code chưa chạy = code chưa đúng. | MOSI và `rx_data` đảo thứ tự bit |
| **CC-4** | **`HALF_CYCLES = 1`** (ca biên tham số) | Nhánh `HALF_CYCLES <= 1` (dòng 28) **chưa từng được chạy**; `HCW = 1` là trường hợp biên của `$clog2` | `f_sclk = f_clk/2`, vẫn đúng 8 xung |
| **CC-5** | **`start` giữ `1` liên tục** (ca biên thông lượng) | Đo chu kỳ lặp thật, kiểm chu kỳ `IDLE` bắt buộc giữa hai giao dịch | Đúng `16·HALF_CYCLES + 2` chu kỳ/byte, **không** phải `16·HALF_CYCLES` |
| **CC-6** | **`rst_n = 0` giữa giao dịch** (ca biên reset) | Kiểm nhả bus sạch: `cs_n → 1` và `sclk → 0` ngay | Không để `sclk` kẹt cao (vi phạm CPOL = 0) |
| **CC-7** | **Ép `state = 2'b11`** (fault injection) | `case` **không có `default`** ⟹ **kẹt vĩnh viễn**. Ca này biến một phân tích trên giấy thành bằng chứng chạy được | FSM **không** tự thoát ⟹ chứng minh cần bản vá `fsm.md` §5.2 |
| **CC-8** | **`miso` đổi sát sườn lên** (ca biên định thời) | Charter mục 10 cảnh báo đúng chỗ này: *"Lấy mẫu MISO sai sườn — chạy vẫn 'có vẻ đúng' với dữ liệu ổn định, chỉ lộ khi dữ liệu đổi sát sườn."* | Với thiết kế đúng: bit lấy được là bit ổn định trong pha SCLK **thấp** |

## 4. Phân loại ca theo tiêu chí kỹ thuật riêng của H03

Với SPI, tiêu chí phân loại đúng đắn là **quan hệ pha giữa sườn SCLK và hai đường dữ liệu**.

### 4.1 Theo sườn SCLK

| Sườn | Việc phải xảy ra | Ca nào kiểm | Đã kiểm? |
|---|---|---|:-:|
| **CS xuống** (trước sườn #1) | `mosi ← ` bit đầu | CC-2 | ❌ |
| **Sườn lên** × 8 | lấy mẫu `miso`; `mosi` **giữ nguyên** | CC-1, CC-2, CC-8 | ❌ |
| **Sườn xuống** × 7 | `mosi ← ` bit kế; `miso` **không** được đọc | CC-2 | ❌ |
| **Sườn xuống #8** | **không** đổi `mosi`; sang `FINISH` | TB hiện tại (gián tiếp, qua `fall_count`) | ⚠️ một phần |
| **CS lên** (sau sườn xuống #8) | nhả bus, `sclk = 0` | TB hiện tại (`assert(cs_n == 1)`) | ✅ |

### 4.2 Theo số lần chuyển mức của MOSI (áp lực định thời)

| Byte | MOSI (MSB-first) | Số lần đổi mức | Mức áp lực |
|---|---|:-:|---|
| `0x00` | `00000000` | **0** | Lộ lỗi "kẹt thấp" / đếm bằng sườn MOSI |
| `0xFF` | `11111111` | **0** | Lộ lỗi "kẹt cao" |
| `0x96` | `10010110` | 5 | Trung bình — **ca duy nhất TB đang chạy** |
| `0xA5` | `10100101` | **7** | **Cao nhất** — chặt nhất về định thời |

> Testbench đang chọn `0x96` — không phải ca có áp lực thấp nhất, nhưng cũng không phải ca
> chặt nhất. Ba ca Charter yêu cầu (`0x00`, `0xFF`, `0xA5`) đều **thiếu**.

### 4.3 Theo nhánh RTL được phủ

| Nhánh | Dòng | Ca nào phủ | Đã phủ? |
|---|---|---|:-:|
| `IDLE` → `IDLE` | 47–53 | mọi ca | ✅ |
| `IDLE` → `TRANSFER` | 54–62 | mọi ca | ✅ |
| `TRANSFER`, `half_tick = 0` | 94–95 | `HALF_CYCLES > 1` | ✅ |
| `TRANSFER`, sườn **lên** | 71–77 | mọi ca | ✅ |
| `TRANSFER`, sườn **xuống**, `edge_count ≠ 8` | 84–92 | mọi ca | ✅ |
| `TRANSFER`, sườn **xuống**, `edge_count = 8` | 82–83 | mọi ca | ✅ |
| `FINISH` | 99–106 | mọi ca | ✅ |
| Nhánh `MSB_FIRST = 0` (dòng 76, 89–90) | | **CC-3** | ❌ **chưa phủ** |
| Nhánh `HALF_CYCLES <= 1` (dòng 28) | | **CC-4** | ❌ **chưa phủ** |
| `state = 2'b11` | (**không có nhánh**) | **CC-7** | ⬛ **không tồn tại trong RTL** |

**Độ phủ nhánh: 7/10.** Nhưng độ phủ nhánh **cao** trong khi độ phủ **chức năng** rất thấp —
vì testbench chạy hết các nhánh mà **không kiểm kết quả**. Đây là minh hoạ cổ điển cho câu:
*coverage ≠ correctness.*

## 5. Ca **KHÔNG** áp dụng cho đề này

| Ca | Vì sao không áp dụng |
|---|---|
| **Mode 1 / 2 / 3** | Charter mục 3: ngoài phạm vi. RTL cứng mode 0: `sclk` reset về `0` và luôn bắt đầu bằng sườn lên. |
| **Nhiều tớ (multi-slave)** | Ngoài phạm vi. Chỉ có **một** `cs_n`, không có bộ giải mã chọn tớ. |
| **Truyền nhiều byte / DMA** | Ngoài phạm vi. `edge_count` so cứng với `8`; không có FIFO. |
| **Xung đột bus (bus contention) trên MISO** | Chỉ có một tớ ⟹ không thể xảy ra. Sẽ phải kiểm nếu có nhiều tớ. |
| **Ca "lỗi khung"** | SPI **không có** khái niệm khung tự đồng bộ — CS đóng vai trò biên khung, và nó do **chủ** điều khiển. Khác hẳn UART (H01/H02). |
| **Ca lấy mẫu giữa bit** | Không áp dụng: SPI **có dây clock chung**, nên không cần khôi phục nhịp. Đây chính là khác biệt bản chất với H02. |
| **Ca metastability trên `miso`** | ⚠️ **Không phải "không áp dụng"** mà là **"không mô phỏng được"**. `miso` đi thẳng vào `rx_shift`, **không** qua bộ đồng bộ. Điều duy nhất kiểm được là **ngân sách độ trễ vòng** — cần số liệu bo mạch đích, ⬜ chưa có. Xem `functional_spec.md` §8.1. |

## 6. Ca cần bổ sung khi chuyển sang gate-level / post-layout

| Ca gate-level | Vì sao chỉ lộ ở mức cổng |
|---|---|
| **X-propagation sau reset** | Netlist dùng `dfxtp_1` (**không có chân reset**); trước cạnh clock đầu tiên cả 36 FF là `X`. Phải kiểm `cs_n` ổn định về `1` và `sclk` về `0` sau đúng 1 cạnh — nếu không, một tớ ngoài chip có thể bị chọn nhầm ngay khi cấp nguồn. |
| **Skew giữa `sclk`, `mosi` và `cs_n`** | Ba tín hiệu này đi ra **ba pad khác nhau**. Ở RTL chúng đổi "cùng lúc"; sau P&R chúng lệch nhau vài trăm ps. Nếu `mosi` tới pad **sau** `sclk`, khoảng setup của chip tớ bị ăn mòn. **Đây là ca quan trọng nhất của H03 ở mức vật lý**, và nó **không thể** kiểm ở mức RTL. |
| **Ràng buộc `set_output_delay` thật cho `sclk`/`mosi`/`cs_n`** | `design.sdc` hiện đặt `set_output_delay 1.0` cho **mọi** cổng ra — một **giả định**. Giá trị thật phải suy từ `t_setup` của chip tớ cộng độ trễ dây. |
| **Ràng buộc đầu vào thật cho `miso`** | `set_input_delay 1.0` là giả định. Giá trị thật = `t_clk→Q` của tớ + độ trễ vòng của dây. Nếu vượt `HALF_CYCLES × T_clk` thì **phải giảm `f_sclk`**. |
| **Đo lại `f_sclk` trên waveform gate-level** | Chu kỳ SCLK vẫn là số nguyên lần `T_clk` (mạch đồng bộ), nhưng duty cycle có thể lệch nhẹ do độ trễ clk→Q khác nhau giữa hai pha. |
| **Kiểm 36 FF vẫn là 36 sau CTS** | CTS chèn buffer clock; số cell tăng nhưng số flip-flop **phải không đổi**. |

## 7. Tình trạng kiểm thử hiện tại — kết luận trung thực

| Lớp | Kết quả thật | Nguồn |
|---|---|---|
| L0 — mô hình chuẩn Python | ✅ **PASS** (8 nhóm test, 5000 ca ngẫu nhiên) | `python_reference_run.log` |
| L1 — assertion SVA (`properties.sv`) | ⬜ cần kiểm cờ biên dịch | `assertions/README.md` |
| L2 — mô phỏng RTL | ✅ **PASS** — `$finish` tại `t = 355 ns` | `simulation.log` |
| L3 — cấu trúc (36 FF > 0) | ✅ PASS | `synthesis/synth_stat.txt` |
| L4 — gate-level | ⬜ chưa chạy | — |
| L5 — post-layout SDF | ⬜ chưa chạy | — |

> ### ⚠️ **L2 PASS, nhưng PASS đó chứng minh được rất ít.**
>
> | Điều L2 **có** chứng minh | Điều L2 **KHÔNG** chứng minh |
> |---|---|
> | Đúng 8 sườn lên | ❌ `rx_data` đúng (**không kiểm**) |
> | ≥ 8 sườn xuống | ❌ `mosi` đúng byte (**không kiểm**) |
> | `cs_n` được nhả ở cuối | ❌ `cs_n` xuống **trước** sườn lên #1 |
> | FSM chạy hết một vòng | ❌ `MSB_FIRST = 0` hoạt động |
> | | ❌ FSM thoát được `state = 2'b11` |
> | | ❌ Song công thật sự đồng thời |
>
> **Đây là bài học trung tâm của đề H03: một mô phỏng PASS với độ phủ chức năng thấp có thể
> nguy hiểm hơn một mô phỏng FAIL, vì nó tạo ra niềm tin sai.**

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
