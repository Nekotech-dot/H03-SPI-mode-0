# H03 · Đánh đổi kiến trúc (Trade-off Analysis)

---

## 1. Câu hỏi trung tâm của đề

> **Charter mục 10 — Chỗ hay tắc:** *"Lấy mẫu MISO sai sườn — chạy vẫn 'có vẻ đúng' với dữ
> liệu ổn định, chỉ lộ khi dữ liệu đổi sát sườn."*

Charter cảnh báo đúng chỗ, và ở H03 lời cảnh báo đó ứng nghiệm theo một cách bất ngờ:
**RTL lấy mẫu ĐÚNG sườn, nhưng TESTBENCH lái MISO sai sườn** — và lỗi đó bị che hoàn toàn
vì testbench **không bao giờ kiểm `rx_data`**. Xem `02_SPECIFICATION/corner_cases.md` §1.1.

## 2. Số liệu thật đo được

| Chỉ số | Giá trị | Nguồn |
|---|---:|---|
| Tổng cell | **156** | `synth_stat.txt` |
| Flip-flop (`dfxtp_1`) | **36** | như trên |
| Cell tổ hợp | **120** | 156 − 36 |
| **Cổng tổ hợp / flip-flop** | **3,33** | 120 ÷ 36 |
| Diện tích | **1443,8848 µm²** | `synth_stat.txt` |
| Diện tích trung bình / cell | **9,2557 µm²** | 1443,8848 ÷ 156 |
| Tổng công suất | **1,61e-04 W** | `power_report.txt` |
| — tuần tự | **1,51e-04 W (94,0 %)** | như trên |
| — tổ hợp | **9,73e-06 W (6,0 %)** | như trên |
| Công suất trung bình / FF | **≈ 4,19e-06 W** | 1,51e-04 ÷ 36 |
| Arrival / Slack | **1,90 ns / +8,02 ns** | `timing_report_max.txt` |

## 3. So sánh ba đề nhóm H — cùng một chuỗi công cụ

> Ba đề chạy trên **cùng** tổ hợp Yosys 0.33 + OpenSTA 3.1.0 +
> `sky130_fd_sc_hd__tt_025C_1v80.lib`, nên so sánh chéo là **hợp lệ**.

| Đề | Trạng thái | Cell | FF | **Cổng/FF** | Diện tích (µm²) | µm²/cell | Arrival | Công suất | Seq % |
|---|:-:|---:|---:|---:|---:|---:|---:|---:|---:|
| H01 phát UART | 4 | 99 | 20 | 3,95 | 848,3136 | 8,5688 | 1,48 ns | 9,27e-05 W | 92,7 |
| H02 thu UART | 7 | 182 | 31 | **4,87** | 1498,9376 | 8,2359 | 1,65 ns | 1,32e-04 W | **97,1** |
| **H03 chủ SPI** | **3** | 156 | **36** | **3,33** | 1443,8848 | **9,2557** | 1,90 ns | **1,61e-04 W** | 94,0 |

### Bốn kết luận rút ra

**(1) H03 nhiều flip-flop nhất (36) nhưng logic đơn giản nhất (3,33 cổng/FF).**
Lý do bản chất: SPI **có dây clock chung**, nên H03 **không** phải khôi phục nhịp. Không cần
bộ đếm rộng, không cần cây giải mã lớn. FSM chỉ **3 trạng thái** — ít nhất nhóm H.
Đổi lại, H03 phải giữ **ba** bản của một byte (`tx_shift` 7 + `rx_shift` 8 + `rx_data` 8 =
23 FF = **64 %** tổng flip-flop) vì nó **song công**.

**(2) Diện tích trung bình/cell của H03 cao nhất (9,2557 µm²).**
Vì tỉ lệ flip-flop trong tổng cell của H03 là **36/156 = 23,1 %** — cao nhất
(H01: 20,2 %, H02: 17,0 %), mà `dfxtp_1` lớn hơn hẳn một cổng NAND. Đây là phép suy luận từ
hai số đo, không phải ước lượng.

**(3) H03 tốn công suất nhất (1,61e-04 W) — và nhiều flip-flop nhất là nguyên nhân chính.**
Công suất/FF của ba đề rất gần nhau: H01 ≈ 4,30e-06 W, H02 ≈ 4,13e-06 W, H03 ≈ 4,19e-06 W.
**Công suất của cả ba đề tỉ lệ gần tuyến tính với số flip-flop.** Với một thiết bị **đeo tay**
(Charter mục 1), đây là kết luận có giá trị ứng dụng thật: muốn giảm công suất, phải giảm
**số flip-flop**, không phải tối ưu logic tổ hợp.

**(4) Công suất tổ hợp của H03 là 6,0 % — cao nhất nhóm H** dù nó có **ít** cổng tổ hợp nhất.
Nghịch lý này có lời giải: công suất tổ hợp phụ thuộc **hoạt động chuyển mức**. Trong H03,
`sclk` đảo **16 lần** mỗi giao dịch và `tx_shift`/`rx_shift` dịch **mỗi nửa chu kỳ SCLK** —
datapath của nó **bận** hơn hẳn. Trong khi đó FSM của H02 **đứng yên** phần lớn thời gian
trong các trạng thái `*_WAIT`, nên khối logic lớn của nó hầu như **không chuyển mức**.

> 📚 **Bài học lớn từ bảng này: diện tích, số cổng và công suất là BA trục độc lập.**
> H02 nhiều cổng nhất nhưng ít công suất tổ hợp nhất. H03 ít cổng nhất nhưng nhiều công suất
> tổ hợp nhất. Không có cái nào suy ra được cái kia.

## 4. Đối chiếu Charter mục 10 — "dấu hiệu làm đúng"

> *"8 (dịch ra) + 8 (dịch vào) + 4 (đếm bit) + chia SCLK ≈ **24–28 ô nhớ**"*

| Hạng mục | Charter đoán | Đo được | Chênh |
|---|:-:|:-:|:-:|
| Dịch ra (`tx_shift`) | 8 | **7** | **−1** (`tx_shift[7]` bị Yosys xoá) |
| Dịch vào (`rx_shift`) | 8 | 8 | 0 |
| Đếm bit (`edge_count`) | 4 | 4 | 0 |
| Chia SCLK (`half_count`) | "…" | 2 | — |
| *(Charter bỏ quên)* `rx_data` | — | **+8** | **+8** |
| *(Charter bỏ quên)* `sclk`,`mosi`,`cs_n`,`busy`,`done` | — | **+5** | **+5** |
| *(Charter bỏ quên)* `state` | — | **+2** | **+2** |
| **TỔNG** | **24–28** | **36** | **+8…+12** |

> 🔎 **Tổng vượt hẳn dải Charter, và nguyên nhân rõ ràng: Charter bỏ quên đầu ra thanh ghi.**
> Đây là phát hiện **nhất quán trên cả ba đề nhóm H**: ở H02, việc bỏ quên 13 FF bị che bởi
> sai số ngược chiều của bộ chia baud; ở H03, bộ chia SCLK chỉ 2 FF nên **không che được**.
>
> Ước lượng của Charter mục 10 nên được đọc là *"số flip-flop của phần datapath lõi"*, không
> phải *"tổng số flip-flop"*.

### 4.1 Phụ thuộc vào `HALF_CYCLES` và `MSB_FIRST`

Tổng FF = **`34 + HCW`** với `HCW = ⌈log₂(HALF_CYCLES)⌉`, **cộng 1** nếu `MSB_FIRST = 0`
(vì khi đó `tx_shift[7]` **được đọc** và không bị xoá).

| `HALF_CYCLES` | `HCW` | `f_sclk` (`T_clk` = 10 ns) | FF (`MSB_FIRST=1`) | FF (`MSB_FIRST=0`) |
|---:|:-:|---:|:-:|:-:|
| 2 (testbench) | 1 | 25 MHz | 35 | 36 |
| **4 (đã tổng hợp)** | **2** | **12,5 MHz** | **36** ✅ khớp đo được | 37 |
| 16 | 4 | 3,125 MHz | 38 | 39 |
| 64 | 6 | 781 kHz | 40 | 41 |

> ⭐ **So sánh đắt giá với UART:** bộ chia nhịp của H03 tăng **rất chậm** (mỗi lần chia đôi
> `f_sclk` chỉ thêm 1 FF, và `f_sclk` thường chỉ thấp hơn `f_clk` vài chục lần). Bộ chia baud
> của H01/H02 cần `⌈log₂(f_clk/baud)⌉` — có thể **9–14 bit** vì baud thấp hơn clock hàng nghìn
> lần. **Đây là cái giá cụ thể, đo được, của việc KHÔNG có dây clock chung.**

### 4.2 Với cảm biến gia tốc thật thì chọn `HALF_CYCLES` bao nhiêu?

Cảm biến MEMS phổ biến chịu được `f_sclk` cỡ 5–10 MHz. Với `T_clk` giả định 10 ns:
`HALF_CYCLES = 8` cho `f_sclk = 6,25 MHz` — hợp lý, và chỉ tốn **37 FF** (thêm 1 so với hiện
tại). ⬜ **Chưa chạy tổng hợp với `HALF_CYCLES = 8`** — cần chạy lại `02_run_synth.sh` để có
số diện tích thật.

## 5. So sánh kiến trúc đã chọn với ba kiến trúc thay thế

Ba phương án B/C/D **chưa được tổng hợp** — cột diện tích ghi ⬜.

| Kiến trúc | Trạng thái | FF (`HC=4`) | Diện tích | Thông lượng | Độ phức tạp | Nên dùng khi |
|---|:-:|:-:|:-:|---|---|---|
| **(A) FSM 3 trạng thái + 2 thanh ghi dịch + thanh ghi ra — ĐANG DÙNG** | 3 | **36 (đo được)** | **1443,8848 µm² (đo được)** | `16·HC + 2` ck/byte | Thấp | ✅ Mặc định — đúng chuẩn, dễ dạy |
| **(B) Dùng chung MỘT thanh ghi dịch cho cả TX và RX** | 3 | **29** (`−7`) | ⬜ chưa chạy | như (A) | Trung bình | Khi diện tích là ràng buộc cứng |
| **(C) Bỏ `rx_data`, xuất thẳng `rx_shift` + `done`** | 3 | **28** (`−8`) | ⬜ | như (A) | Thấp | ❌ **Không nên** — xem §5.2 |
| **(D) Hỗ trợ giữ CS qua nhiều byte** | 4 | **+4…5** (đếm byte) | ⬜ | tốt hơn nhiều với cảm biến | Trung bình | Khi cảm biến cần địa chỉ + N byte — **nhưng NGOÀI PHẠM VI** Charter mục 3 |

### 5.1 (B) — thanh ghi dịch dùng chung: tiết kiệm 7 FF, nhưng…

Trong SPI song công, bit đi ra và bit đi vào **không bao giờ dùng cùng một ô nhớ tại cùng một
thời điểm**: bit ra rời `tx_shift` ở sườn **xuống**, bit vào tới `rx_shift` ở sườn **lên**.
Về nguyên tắc có thể dùng **một** thanh ghi 8 bit duy nhất: dịch trái, MSB đi ra `mosi`, LSB
nhận `miso`. Sau 8 chu kỳ, thanh ghi chứa **trọn byte nhận được** và byte gửi đã đi hết.

| | (A) hiện tại | (B) dùng chung |
|---|:-:|:-:|
| `tx_shift` + `rx_shift` | 7 + 8 = **15 FF** | **8 FF** |
| Tiết kiệm | — | **−7 FF ≈ −19 %** |
| Nhược điểm | — | `tx_data` và `rx_data` **không** cùng tồn tại; khó gỡ lỗi; khó mở rộng sang nhiều byte |

Đây là kiến trúc **kinh điển** của nhiều lõi SPI thương mại. Với một đề **dạy học**, (A) rõ
ràng hơn nhiều — nhìn hai thanh ghi là thấy ngay "song công". Nhưng **phải biết (B) tồn tại**,
vì nó là câu trả lời cho *"có cách nào nhỏ hơn không"* khi bảo vệ.

### 5.2 (C) — bỏ `rx_data`: **KHÔNG nên**, dù tiết kiệm 8 FF

| Nếu xuất thẳng `rx_shift` | Hậu quả |
|---|---|
| Tầng ngoài thấy byte **đổi từng bit** suốt 8 chu kỳ SCLK | Không có thời điểm "byte hợp lệ" hiển nhiên |
| Giao dịch bị `rst_n` cắt giữa chừng vẫn rò dữ liệu dở | Tầng ngoài đọc nhầm |
| Tầng ngoài buộc phải tự chốt bằng `done` | **8 FF chỉ chuyển sang tầng ngoài** — tổng hệ thống không rẻ hơn |

8 FF là giá của **ranh giới giao dịch** (INV-8) — cùng lý lẽ với `byte_out` của H02. Đây là
một **kiểu thiết kế nhất quán** giữa hai đề.

### 5.3 (D) — giữ CS qua nhiều byte: đáng giá nhất về ứng dụng, nhưng ngoài phạm vi

Nhiều cảm biến SPI cần 1 byte địa chỉ + N byte dữ liệu **trong một lần CS thấp**. H03 nhả CS
sau **mỗi** byte, nên với một cảm biến như vậy nó **không dùng được trực tiếp**.

Chi phí: thêm một bộ đếm byte (≈ 3–4 FF) + 1 cổng vào `keep_cs` + 1 trạng thái.
**Charter mục 3 liệt "truyền nhiều byte" vào ngoài phạm vi** ⟹ chỉ bàn trên giấy, phải ghi
vào `07_TRACEABILITY/limitations.md` như một **giới hạn ứng dụng**.

## 6. Ràng buộc phạm vi — chỉ được so sánh trên giấy (Charter mục 3)

| Kiến trúc ngoài phạm vi | Chi phí (đếm khai báo, ⬜ chưa tổng hợp) | Vì sao bị loại |
|---|---|---|
| **Mode 1 / 2 / 3** | +2 cổng vào (`CPOL`, `CPHA`) + logic đảo `sclk` và dời pha ⟹ **+0 FF nhưng +logic đáng kể**, và `sclk` có thể phải reset về `1` | Charter mục 3 |
| **Nhiều tớ** | +`⌈log₂(N)⌉` cổng vào + N chân `cs_n` + bộ giải mã ⟹ **+0 FF, +N chân** | Charter mục 3. Với N = 4: **+4 chân**, mà ngân sách chỉ còn **1 chân dư** (`system_diagram.md` §5) ⟹ **không khả thi về chân** |
| **DMA** | Giao diện bộ nhớ + bộ đếm địa chỉ ⟹ **+20…30 FF** | Charter mục 3 |
| **Truyền nhiều byte / FIFO 16 byte** | **+128 FF** — gấp **3,6 lần** toàn bộ H03 | Charter mục 3 |

> Con số đáng nhớ: **thêm 4 chip tớ cần 4 chân, mà H03 chỉ còn dư 1 chân** (23/24 đã dùng, vì
> `busy` và `done` là hai cổng **ngoài** Charter mục 4). Ràng buộc chân là ràng buộc **cứng**
> ở Tiny Tapeout — đôi khi nó chặn một tính năng trước cả khi diện tích kịp lên tiếng.

## 7. Ba quan sát về chi phí ẩn

| # | Quan sát | Bằng chứng | Đánh giá |
|:-:|---|---|---|
| 1 | `tx_shift[7]` **bị Yosys xoá** vì không bao giờ được đọc | `netlist.v` chỉ có `\tx_shift[0..6]`; 37 khai báo → 36 `dfxtp_1` | ✅ Vô hại. Nhưng **sẽ sống lại** nếu đổi `MSB_FIRST = 0` ⟹ mọi con số diện tích/công suất đổi theo |
| 2 | `a21boi_0 × 25` ≈ số flip-flop dữ liệu (23) | `synth_stat.txt` | Phần lớn logic tổ hợp của H03 chỉ là **MUX hồi tiếp** của các thanh ghi, không phải phép toán |
| 3 | `busy` và `done` là hai cổng **ngoài Charter mục 4** | `functional_spec.md` §0 | Tốn 2 chân, đẩy ngân sách lên 23/24. `done` **rất đáng giữ** (nó là thứ H01 **thiếu**); `busy` có thể suy từ `done` nếu cần chân |

## 8. Những đánh đổi **KHÔNG được phép** trong đề này

| Cấm | Vì sao |
|---|---|
| **Chuyển `edge_count == 8` sang nhánh sườn LÊN** | `sclk` sẽ **kẹt ở mức cao** khi nhả CS ⟹ **vi phạm CPOL = 0** và chu kỳ SCLK thứ 8 không hoàn chỉnh. Xem `control.md` §4. |
| **Biến `sclk`, `mosi`, `cs_n` thành đầu ra tổ hợp** | Ba tín hiệu này đi **thẳng ra pad**. Một glitch trên `sclk` bị chip tớ đếm là **một xung thừa** ⟹ lệch cả byte. Lỗi này **không** xuất hiện trong mô phỏng zero-delay. |
| **Lấy mẫu MISO ở sườn xuống** | Đổi hẳn sang mode 1. Charter mục 3: mode 1/2/3 ngoài phạm vi. |
| **Đưa bit đầu ra MOSI ở sườn SCLK đầu tiên thay vì lúc CS xuống** | Đó là **CPHA = 1**, không phải mode 0. Chip tớ sẽ đọc lệch một bit. |
| **Bỏ `rx_data` để tiết kiệm 8 FF** | Phá ranh giới giao dịch (§5.2) |
| **Sửa DUT để testbench kiểm `rx_data` PASS** | Lỗi nằm ở **mô hình chip tớ của testbench** (lái MISO sai sườn), **không** ở DUT. Xem `corner_cases.md` §1.1. Sửa DUT ở đây là làm hỏng một thiết kế đang đúng. |
| **Coi "mô phỏng PASS" là bằng chứng chức năng đầy đủ** | Testbench **không kiểm `rx_data`**, **không kiểm `mosi`**, độ phủ Charter mục 8 chỉ ~1,5/7 |
| **Bỏ qua lỗi thiếu `default`** vì "mô phỏng vẫn PASS" | `2'b11` **không có đường tới**, nên mô phỏng chức năng **không thể** phát hiện. Phải phát hiện bằng **đếm mã trạng thái**. Xem `fsm.md` §5.2. |
| **Tự tối ưu netlist bằng tay** | Charter mục 3 (mọi đề) |
| **So sánh số liệu H03 với đề chạy môi trường khác** | `02_SPECIFICATION/parameters.md` §2. (So với H01/H02 thì **hợp lệ** — cùng chuỗi công cụ.) |

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
