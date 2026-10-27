# H03 — Chủ SPI chế độ 0 · Ghi chú thực hiện

---

## 1. Bài toán này thực chất là gì

Bề mặt: "gửi một byte và nhận một byte qua bốn dây". Thực chất: **thoả thuận PHA giữa một dây
clock và hai dây dữ liệu, và giữ thoả thuận đó tuyệt đối.**

Khác hẳn UART. H02 (bộ thu UART) phải **đoán** biên bit vì không có dây clock. H03 **gửi hẳn**
clock đi — bên tớ không phải đoán gì. Toàn bộ bài toán "lấy mẫu giữa bit" biến mất. Nhưng đổi
lại, H03 phải chịu trách nhiệm cho một thứ khác: **quan hệ pha**.

SPI có bốn chế độ, khác nhau ở hai bit:

| | CPOL | CPHA | Lấy mẫu ở | Đổi dữ liệu ở |
|---|:-:|:-:|---|---|
| **Mode 0** (đề này) | **0** (SCLK nghỉ **thấp**) | **0** | **sườn LÊN** | **sườn XUỐNG** |
| Mode 1 | 0 | 1 | sườn xuống | sườn lên |
| Mode 2 | 1 | 0 | sườn xuống | sườn lên |
| Mode 3 | 1 | 1 | sườn lên | sườn xuống |

Nếu chủ và tớ không cùng chế độ, **mọi bit đều lệch** — và tệ hơn, hệ thống vẫn "có vẻ chạy"
khi dữ liệu ổn định. Đó chính là điều Charter mục 10 cảnh báo.

**Hệ quả quan trọng nhất của CPHA = 0**, và là chỗ nhiều thiết kế làm sai: **bit đầu tiên
phải có mặt trên MOSI TRƯỚC sườn lên thứ nhất** — tức là ngay khi CS xuống, chứ không phải
chờ một sườn SCLK. RTL của H03 làm đúng (dòng 56 + 60): `cs_n <= 1'b0` và
`mosi <= tx_data[7]` được gán **cùng một cạnh clock**.

Bối cảnh Charter mục 1 — đọc cảm biến gia tốc trong **thiết bị đeo tay** — chốt hai ràng buộc
thật: **công suất thấp** (pin nhỏ) và **tần số đọc vừa phải** (vài chục đến vài trăm Hz).
Cả hai đều ủng hộ SPI: giao dịch ngắn, xong là nhả bus, không có mạch nào phải chạy liên tục
giữa hai lần đọc.

## 2. Bản chất kỹ thuật — cơ chế hoạt động

H03 là **hai thanh ghi dịch chạy ngược pha nhau quanh một bộ chia clock**. Hiểu được sự lệch
pha đó là hiểu cả khối.

```
      clk ──▶ half_count (mod HALF_CYCLES) ──half_tick──▶ sclk (ĐẢO mỗi tick)
                                                            │
                        ┌───────────────────────────────────┴──────────────┐
                        │                                                  │
                 sclk sắp LÊN                                      sclk sắp XUỐNG
                        │                                                  │
             rx_shift ← {rx_shift[6:0], miso}              tx_shift ← tx_shift << 1
             edge_count + 1                                mosi     ← tx_shift[6]
```

**Nút thắt của SPI không phải là logic — mà là NỬA CHU KỲ SCLK ngăn cách hai sự kiện đó.**
`mosi` đổi ở sườn xuống thứ `k`; chip tớ lấy mẫu ở sườn lên thứ `k+1`. Khoảng cách giữa hai
mốc đó — `HALF_CYCLES × T_clk` — **chính là khoảng setup** mà bên tớ được hưởng. Nó không phải
chi tiết hiện thực; nó **là định nghĩa** của chế độ 0.

Và điều đẹp nhất: khoảng setup đó **đồng đều cho mọi bit, kể cả bit đầu tiên**, vì `mosi` được
đặt tại `E(s)` còn sườn lên #1 ở `E(s + HALF_CYCLES)` — đúng bằng khoảng cách giữa mọi cặp
sườn xuống/lên kế tiếp. Nhiều hiện thực sai làm bit đầu "hẹp hơn" các bit sau.

**Chi tiết tinh tế nhất của RTL**, và nó quyết định tính đúng đắn: phép so sánh
`edge_count == 8` được đặt ở nhánh **sườn XUỐNG**, không phải sườn lên.

| Nếu kiểm ở nhánh sườn LÊN | Nếu kiểm ở nhánh sườn XUỐNG (RTL làm thế này) |
|---|---|
| Sau sườn lên #8 ⟹ sang `FINISH` ngay | Sườn xuống #8 **vẫn được phát** |
| `sclk` **kẹt ở mức cao** khi nhả CS | `sclk <= 1'b0` chạy trước |
| Chu kỳ SCLK thứ 8 **không hoàn chỉnh** | Đủ **8 chu kỳ trọn vẹn** |
| ❌ Vi phạm CPOL = 0 | ✅ Đúng chuẩn |

Đây là loại lỗi **rất khó thấy** nếu testbench chỉ đếm `rise_count == 8` — đúng như testbench
hiện tại đang làm.

## 3. Đọc mã nguồn: RTL làm gì, từng dòng quan trọng

**(a) Nhận lệnh — CPHA = 0 thể hiện ở đây, dòng 54–62:**

```systemverilog
if (start) begin
    busy <= 1'b1;
    cs_n <= 1'b0;
    tx_shift <= tx_data;
    rx_shift <= '0;
    mosi <= MSB_FIRST ? tx_data[7] : tx_data[0];   // ← bit đầu CÙNG LÚC với CS
    state <= TRANSFER;
end
```

Sáu thanh ghi cập nhật tại một cạnh. `mosi <= tx_data[7]` đi **thẳng** từ cổng vào, **không**
qua `tx_shift` — đó là lý do `tx_shift[7]` không bao giờ được đọc (xem (d)).

**(b) Chọn pha — dòng 71–80:**

```systemverilog
if (half_tick) begin
    half_count <= '0;
    if (sclk == 1'b0) begin           // sắp có SƯỜN LÊN
        sclk <= 1'b1;
        rx_shift <= {rx_shift[6:0],miso};
        edge_count <= edge_count + 1'b1;
    end else begin                    // sắp có SƯỜN XUỐNG
        sclk <= 1'b0;
```

`sclk` vừa là **đầu ra** vừa là **biến chọn nhánh**. Vì `sclk <= 1'b1` là gán không chặn,
`miso` được lấy mẫu **trước khi** `sclk` thực sự lên trên dây — tức là chủ bắt giá trị đã ổn
định **suốt toàn bộ pha SCLK thấp**, đúng bằng bit mà một chip tớ mode 0 trình ra. Hành vi
**đúng**, và cho khoảng setup lớn nhất có thể.

**(c) Dịch ra — "nhìn trước một bit", dòng 85–91:**

```systemverilog
if (MSB_FIRST) begin
    tx_shift <= {tx_shift[6:0],1'b0};
    mosi     <= tx_shift[6];        // ← KHÔNG phải [7]
end
```

Cùng cơ chế với H01 nhưng **ngược chiều dịch**: sau cạnh này `tx_shift` đã dịch **trái**, nên
MSB mới là `tx_shift_cũ[6]`. Đọc `[7]` sẽ **lặp lại** bit vừa gửi.

**(d) ⭐ Hệ quả: `tx_shift[7]` là mã chết chứng minh được.**
Nó được **ghi** ở hai chỗ (dòng 57, 86) nhưng **không bao giờ xuất hiện ở vế phải** của bất
kỳ biểu thức nào. Yosys chứng minh được điều đó và **xoá hẳn**: 37 bit khai báo →
**36 `dfxtp_1`**. `netlist.v` chỉ có `\tx_shift[0]` … `\tx_shift[6]`.

**(e) `FINISH` — dọn dẹp, dòng 99–106:**

```systemverilog
FINISH: begin
    sclk <= 1'b0;  cs_n <= 1'b1;  busy <= 1'b0;
    rx_data <= rx_shift;  done <= 1'b1;
    state <= IDLE;
end
```

Một chu kỳ dành riêng cho: nhả CS, chốt `rx_data`, phát xung `done`.

**(f) ⛔ Chỗ RTL thiếu — `case` không có `default`, dòng 46–107.**
`enum logic [1:0]` với 3 trạng thái ⟹ mã `2'b11` thừa. Nếu `state = 2'b11`, **không lệnh gán
nào chạy** ⟹ FSM **kẹt vĩnh viễn**, `cs_n` có thể kẹt ở `0`. Xem `fsm.md` §5.2.

## 4. Vì sao chọn kiến trúc này

FSM 3 trạng thái + 2 thanh ghi dịch riêng + 1 thanh ghi ra. Ba lý do:

| Lý do | Nội dung |
|---|---|
| **Dạy học** | Hai thanh ghi dịch tách bạch làm "song công" thành thứ **nhìn thấy được**. Một lõi SPI thương mại thường dùng **một** thanh ghi dùng chung (phương án B, `tradeoff.md` §5.1) — tiết kiệm **7 FF ≈ 19 %** nhưng giấu mất bản chất. |
| **Ranh giới giao dịch** | `rx_data` riêng (8 FF) bảo đảm tầng ngoài **không** thấy byte đang hình thành, và giao dịch bị cắt giữa chừng không rò dữ liệu rác. Cùng lý lẽ với `byte_out` của H02 — một **kiểu thiết kế nhất quán**. |
| **Timing dư dả** | Slack +8,02 ns trên chu kỳ giả định 10 ns ⟹ không có lý do nào để đánh đổi độ rõ lấy tốc độ. |

Bốn quyết định **không** được đổi:

| Quyết định | Vì sao bắt buộc |
|---|---|
| `sclk`, `mosi`, `cs_n` là **đầu ra thanh ghi** | Chúng đi **thẳng ra pad**. Một glitch trên `sclk` bị chip tớ đếm là **xung thừa** ⟹ lệch cả byte. Lỗi này **không** xuất hiện trong mô phỏng zero-delay. |
| `edge_count == 8` kiểm ở nhánh **sườn xuống** | Nếu không, `sclk` kẹt cao ⟹ vi phạm CPOL = 0 |
| Bit đầu ra MOSI **lúc CS xuống** | Đó là CPHA = 0. Nếu chờ sườn SCLK đầu tiên, thành mode 1 |
| `rx_data` là thanh ghi riêng | Ranh giới giao dịch |

## 5. Cách thực hiện — lộ trình 8 bước từ đặc tả tới GDSII

| # | Bước | Trạng thái thật | Bằng chứng |
|:-:|---|:-:|---|
| 1 | Chốt mode 0: CPOL = 0, CPHA = 0, MSB-first, CS bao trọn 8 xung | ✅ | `functional_spec.md` §4 |
| 2 | Viết mô hình chuẩn Python độc lập | ✅ **PASS** (8 nhóm test, 5000 ca) | `python_reference_run.log` |
| 3 | Viết RTL: FSM 3 trạng thái + chia SCLK + 2 thanh ghi dịch | ✅ | `rtl/h03_spi_master.sv` |
| 4 | Mô phỏng RTL | ✅ **PASS** — `$finish` tại `t = 355 ns` | `simulation.log` |
| 5 | Tổng hợp sang `sky130_fd_sc_hd` | ✅ PASS — 156 cell, **36** FF (37 khai báo) | `synth_stat.txt` |
| 6 | STA với SDC giả định (10 ns, IO 1 ns) | ✅ PASS — slack +8,02 ns | `timing_report_max.txt` |
| 7 | Ước lượng công suất | ✅ 1,61e-04 W | `power_report.txt` |
| 8 | P&R → GDS, DRC, LVS | ⬜ **chưa chạy** | `physical_report.md` §1 |

H03 là **đề duy nhất** trong ba đề nhóm H có bước 4 PASS. Nhưng xem §6 — PASS đó chứng minh
ít hơn nhiều so với vẻ ngoài.

## 6. Số liệu thật đã đo được và cách đọc chúng

| Chỉ số | Giá trị | Nguồn |
|---|---:|---|
| Số cell | **156** | `synth_stat.txt` |
| Flip-flop (`dfxtp_1`) | **36** (khai báo 37) | như trên |
| Cổng tổ hợp / FF | **3,33** | 120 ÷ 36 |
| Diện tích | **1443,8848 µm²** | `synth_stat.txt` |
| Startpoint → Endpoint | `start` → `_241_` | `sta/summary.txt` |
| Data arrival | **1,90 ns** | `timing_report_max.txt` |
| Slack | **+8,02 ns (MET)** | như trên |
| WNS / TNS | 0,00 / 0,00 | `wns.txt` · `tns.txt` |
| Công suất | **1,61e-04 W** (tuần tự 94,0 % · tổ hợp 6,0 %) | `power_report.txt` |
| Cell trên đường tới hạn | **4** | BRIEF H03 |
| Mô phỏng | **PASS**, `$finish` tại `t = 355 ns` | `simulation.log` |

**Những gì các con số này CHỨNG MINH:**

- **36 FF phân rã chính xác, và giải thích được cả bit bị mất**: `state` 2 + `half_count` 2 +
  `edge_count` 4 + `tx_shift` **7** + `rx_shift` 8 + `rx_data` 8 + 5 đầu ra = **36**, khớp
  từng nhóm với tên wire trong `netlist.v`. Bit thứ 37 (`tx_shift[7]`) bị xoá **vì lý do
  chứng minh được**.
- **Số chu kỳ giao dịch khớp chính xác với phân tích FSM**: dự đoán `16 × HALF_CYCLES + 1 = 33`
  chu kỳ từ `E2` (`t = 25 ns`) ⟹ `E35` = `t = 355 ns`. `simulation.log` ghi
  `$finish called at 355`. **Phép đếm bằng tay khớp với mô phỏng tới từng ns.**
- **Đúng 8 sườn lên**: testbench `assert(rise_count == 8)` PASS.
- **Mạch đúng phân loại Tuần tự**: 36 FF > 0; công suất tuần tự 94,0 %.
- **Không có nút thắt timing**: 1,90/9,92 = dùng 19,2 % ngân sách. Trong 1,90 ns có **1,00 ns
  là input delay GIẢ ĐỊNH**; logic thật chỉ **0,90 ns**.
- **Công suất tỉ lệ với số flip-flop**: H01 ≈ 4,30e-06 W/FF, H02 ≈ 4,13e-06, H03 ≈ 4,19e-06.
  Ba đề, ba kiến trúc khác nhau, nhưng công suất/FF **gần như không đổi**.

**Những gì chúng KHÔNG chứng minh:**

- ❌ **"Mô phỏng PASS" KHÔNG chứng minh `rx_data` đúng** — testbench **không bao giờ kiểm**
  `rx_data`. Nửa "thu" của một khối **song công** nằm hoàn toàn ngoài vùng kiểm chứng.
- ❌ **Không chứng minh `mosi` phát đúng byte** — cũng không có `assert` nào.
- ❌ **Không chứng minh FSM an toàn** — `state = 2'b11` **không có đường tới**, nên mô phỏng
  chức năng **không thể** phát hiện lỗi thiếu `default`.
- ❌ **Không chứng minh `MSB_FIRST = 0` hoạt động** — nhánh đó chưa từng được chạy.
- ❌ **Không chứng minh H03 chạy được ở 100 MHz.** `period 10.0` là **giả định** của
  `design.sdc`; chưa có RC, chưa P&R, một góc PVT.
- ❌ **Không nói gì về skew giữa ba pad** `sclk`/`mosi`/`cs_n` — rủi ro vật lý **lớn nhất**
  của một chủ SPI, chỉ kiểm được ở L5.
- ⚠️ `miso` **không qua bộ đồng bộ**; ngân sách độ trễ vòng ⬜ **chưa phân tích**.

## 7. Trả lời các câu hỏi kỹ thuật của Charter (mục 2)

**① CS phải bao trọn 8 xung SCLK — chứng minh trên waveform bằng cách chỉ vào hai mốc?**

| Mốc | Sự kiện | Thời điểm | Khoảng cách |
|:-:|---|---|---|
| **1** | `cs_n` xuống **trước** sườn lên #1 | `E2` (25 ns) vs `E4` (45 ns) | **20 ns = `HALF_CYCLES` chu kỳ clock** |
| **2** | `cs_n` lên **sau** sườn xuống #8 | `E35` (355 ns) vs `E34` (345 ns) | **10 ns = 1 chu kỳ clock** |

CS thấp trong `[25, 355] ns`, chứa trọn 8 sườn lên (45…325) và 8 sườn xuống (65…345). ✅

> ⚠️ **Phát hiện kèm theo:** hai biên **bất đối xứng**. `t_CS_setup` tỉ lệ với `HALF_CYCLES`,
> nhưng `t_CS_hold` là **hằng số 1 chu kỳ clock** bất kể tham số. Nếu datasheet cảm biến đòi
> `t_CS_hold` lớn hơn, **không có tham số nào chỉnh được**. ⬜ Chưa kiểm.

**② Mode 0 nghĩa là lấy mẫu MISO ở sườn nào — và mạch của em làm đúng chưa?**

**Sườn LÊN.** Và **mạch làm đúng**: `rx_shift <= {rx_shift[6:0],miso}` nằm trong nhánh
`sclk == 1'b0` (tức là cạnh clock mà `sclk` sắp lên), dòng 71–74. Trên waveform, `rx_shift`
đổi tại `E4, E8, E12, …, E32` — đúng 8 sườn lên — và **không** đổi tại các sườn xuống.

> ⚠️ **Nhưng testbench thì lái MISO SAI sườn**: nó lái `miso` trong `always @(posedge sclk)`
> — tức là **sau** khi chủ đã lấy mẫu. Hậu quả: `rx_data` thật sẽ là **`0x1E`** thay vì
> `0x3C`, trễ đúng một bit. Lỗi này **bị che hoàn toàn** vì testbench không kiểm `rx_data`.
> Phán xử đầy đủ: `corner_cases.md` §1.1. **Lỗi ở TESTBENCH, không ở DUT.**

**③ Phát MOSI và thu MISO xảy ra đồng thời — điều đó tiết kiệm được gì so với gửi rồi nhận?**

**Tiết kiệm đúng một nửa thời gian bus.** Song công: **8** chu kỳ SCLK cho một byte đi **và**
một byte về. Bán song công (gửi xong rồi nhận): **16** chu kỳ SCLK. Mô hình chuẩn Python ghi
nhận đúng tỉ lệ này: `test_full_duplex_time` khẳng định `8 < 16`.

Với số liệu thật của H03 (`HALF_CYCLES = 4`): **66** chu kỳ clock/giao dịch song công so với
**≈130** nếu bán song công. Và với một thiết bị **đeo tay**, thời gian bus ngắn hơn ⟹ thời
gian bật mạch ngắn hơn ⟹ **tốn ít năng lượng hơn cho mỗi lần đọc cảm biến**.

Chi phí của song công: **+8 flip-flop** (`rx_shift` riêng) nếu không dùng chung thanh ghi.

## 8. Trả lời câu phân tích riêng (Charter mục 9)

> *"SPI mode 0 quy định dữ liệu đổi ở sườn xuống và lấy mẫu ở sườn lên. Chứng minh thiết kế
> của mình làm đúng bằng waveform có chú thích — nêu rõ khoảng thiết lập (setup) mà bên tớ
> được hưởng."*

### Chứng minh (waveform đầy đủ: `03_ARCHITECTURE/timing_diagram.md` §1, §5)

| Khẳng định | Bằng chứng trên waveform | Bằng chứng trong RTL |
|---|---|---|
| MOSI **chỉ** đổi ở sườn **xuống** | `mosi` đổi tại `E6, E10, E14, E18, E22, E26, E30` — đúng 7 sườn xuống đầu; **không** đổi tại `E4, E8, …, E32` | `mosi <= tx_shift[6]` trong nhánh `else` (`sclk == 1`), dòng 87 |
| MISO **chỉ** lấy mẫu ở sườn **lên** | `rx_shift` đổi tại `E4, E8, …, E32` — đúng 8 sườn lên | `rx_shift <= {…,miso}` trong nhánh `sclk == 1'b0`, dòng 74 |
| Bit đầu có mặt **trước** sườn lên #1 | `mosi = b7 = 1` từ `E2`; sườn lên #1 tại `E4` | dòng 56 + 60 |

### Khoảng setup mà bên tớ được hưởng

```
   khoảng setup = HALF_CYCLES × T_clk = NỬA chu kỳ SCLK
```

| `HALF_CYCLES` | Khoảng setup | Chu kỳ SCLK | `f_sclk` (`T_clk` giả định 10 ns) |
|---:|---:|---:|---:|
| 2 (testbench) | **20 ns** | 40 ns | 25 MHz |
| **4 (đã tổng hợp)** | **40 ns** | 80 ns | 12,5 MHz |
| 8 | 80 ns | 160 ns | 6,25 MHz |

> **Đặc tính đáng khen nhất của thiết kế:** khoảng setup **đồng đều cho MỌI bit, kể cả bit
> đầu tiên** (INV-11). Nhiều hiện thực sai làm bit đầu hẹp hơn vì chúng đặt bit đầu muộn hơn.
> Ở đây `mosi` được đặt tại `E(s)` và sườn lên #1 ở `E(s + HALF_CYCLES)` — đúng bằng khoảng
> cách giữa mọi cặp sườn xuống/lên kế tiếp.

⚠️ `T_clk = 10 ns` là **giả định** của `design.sdc`, **không** phải khẳng định H03 chạy được
ở 100 MHz. Các giá trị ns ở trên là **tỉ lệ theo chu kỳ clock**.

**Chiều ngược lại (MISO → H03)** cũng được nửa chu kỳ SCLK, nhưng phải trừ độ trễ vòng
(`t_clk→Q` của tớ + 2× độ trễ pad/dây). H03 **không có bộ đồng bộ** trên `miso`, nên nếu tổng
đó vượt `HALF_CYCLES × T_clk` thì lấy mẫu sẽ sai. ⬜ **Chưa phân tích định lượng.**

## 9. Những chỗ sinh viên hay sai và cách phát hiện

| # | Sai lầm | Hậu quả | **Phát hiện bằng bằng chứng nào** |
|:-:|---|---|---|
| 1 | **Coi "mô phỏng PASS" là đã kiểm chứng xong** | Bỏ lọt: `rx_data` sai, `mosi` chưa kiểm, FSM có thể kẹt | Mở `h03_spi_master_tb.sv` và **đếm số `assert`**: chỉ có 3, không cái nào chạm `rx_data` hay `mosi`. Mở `test_matrix.csv` đối chiếu Charter mục 8. |
| 2 | Lái MISO **tại** sườn lên trong mô hình chip tớ | `rx_data` trễ **một bit** (`0x1E` thay vì `0x3C`), nhưng **không ai thấy** | Thêm `assert(rx_data == 8'h3C)` ⟹ FAIL ngay. Rồi truy vết: chip tớ mode 0 phải lái MISO ở sườn **xuống**. |
| 3 | Thấy `assert(rx_data)` FAIL rồi **sửa DUT** | Phá hỏng một thiết kế đang đúng | Đối chiếu RTL với định nghĩa mode 0: `rx_shift` nằm trong nhánh `sclk == 1'b0` ⟹ lấy mẫu ở sườn **lên** ⟹ **DUT đúng**. Lỗi ở testbench. |
| 4 | Đặt `edge_count == 8` ở nhánh sườn **lên** | `sclk` **kẹt cao** khi nhả CS ⟹ vi phạm CPOL = 0 | Waveform: kiểm `sclk == 0` **ngay trước** khi `cs_n` lên. Testbench hiện tại **không** kiểm điều này. |
| 5 | Đưa bit đầu ra MOSI ở sườn SCLK đầu tiên | Thành **mode 1**; chip tớ đọc lệch một bit | Waveform: `mosi` phải hợp lệ **trước** `E4` (sườn lên #1). Ở đây nó hợp lệ từ `E2`. |
| 6 | Viết `mosi <= tx_shift[7]` thay vì `[6]` | Mỗi bit gửi **hai lần** | `tx_sequence(0x96,True)` của mô hình chuẩn cho `[1,0,0,1,0,1,1,0]`; waveform sẽ cho `b7,b7,b6,b6,…` |
| 7 | **Quên `default` cho mã trạng thái thừa** | **Chính là lỗi của đề này.** FSM kẹt vĩnh viễn, `cs_n` có thể kẹt `0` | **Đếm mã**: `enum logic [1:0]` = 4 mã, dùng 3 ⟹ thừa 1 ⟹ **phải có `default`**. Mô phỏng chức năng **không thể** phát hiện; chỉ fault injection (ca CC-7) mới phủ được. |
| 8 | Dùng `sclk` làm clock cho logic bên trong | Tạo **clock domain thứ hai**, cần CTS riêng, dễ sinh glitch | Kiểm netlist: chỉ được có **một** net vào chân `CLK` của mọi `dfxtp_1`. RTL này làm đúng — `sclk` chỉ là **dữ liệu**, mọi thứ chạy theo `clk`. |
| 9 | Tin rằng `tx_shift` có 8 flip-flop | Đếm sai FF, lý giải sai diện tích | `netlist.v` chỉ có `\tx_shift[0..6]`. 37 khai báo → **36** `dfxtp_1`. Và bit đó **sẽ sống lại** nếu `MSB_FIRST = 0`. |
| 10 | Bỏ qua `miso` không có bộ đồng bộ | Lấy mẫu sai khi độ trễ vòng lớn | So RTL của H02 (**có** `rx_meta`/`rx_sync`) với H03 (**không có**). Rồi tính ngân sách độ trễ vòng của bo mạch. |
| 11 | Báo "H03 chạy được ở 100 MHz" hoặc "`f_sclk` = 12,5 MHz" | Phát biểu vượt mức | `02_SPECIFICATION/timing.md` §3 — bảng bốn giả định. `T_clk = 10 ns` là giả định phân tích. |

## 10. Câu hỏi mentor nên đặt khi bảo vệ

| # | Câu hỏi | Đáp án mong đợi |
|:-:|---|---|
| 1 | Chỉ **hai** mốc trên waveform chứng minh CS bao trọn 8 xung. | CS xuống tại `E2` (25 ns), sườn lên #1 tại `E4` (45 ns) ⟹ trước 2 chu kỳ. Sườn xuống #8 tại `E34` (345 ns), CS lên tại `E35` (355 ns) ⟹ sau 1 chu kỳ. |
| 2 | Mode 0 lấy mẫu MISO ở sườn nào? Mạch em làm đúng chưa? | Sườn **lên**. Đúng — `rx_shift` nằm trong nhánh `sclk == 1'b0`, và trên waveform nó đổi tại đúng 8 sườn lên. |
| 3 | Khoảng setup của bên tớ là bao nhiêu, và bit đầu có hẹp hơn không? | `HALF_CYCLES × T_clk` = nửa chu kỳ SCLK. **Bit đầu KHÔNG hẹp hơn** — `mosi` đặt tại `E(s)`, sườn lên #1 tại `E(s+HALF_CYCLES)`. |
| 4 | Mô phỏng PASS. Vậy `rx_data` đúng chưa? | **Chưa biết** — testbench **không bao giờ kiểm `rx_data`**. Và mô hình chip tớ của nó lái MISO **sai sườn**, nên `rx_data` thật sẽ là `0x1E` chứ không phải `0x3C`. |
| 5 | Nếu thêm `assert(rx_data == 8'h3C)` và nó FAIL, em sửa ở đâu? | **Sửa testbench**, không sửa DUT. Chip tớ mode 0 phải lái MISO ở sườn **xuống**, không phải sườn lên. |
| 6 | Vì sao `edge_count == 8` được kiểm ở nhánh sườn **xuống**? | Để sườn xuống #8 **vẫn được phát**, hoàn tất chu kỳ SCLK thứ 8 và đưa `sclk` về `0` trước khi nhả CS. Nếu kiểm ở sườn lên, `sclk` kẹt cao ⟹ vi phạm CPOL = 0. |
| 7 | FSM có trạng thái bất hợp lệ không? So với H01 và H02? | **Có, và RTL KHÔNG xử lý.** 3 trạng thái / 4 mã ⟹ thừa `2'b11`, mà `case` **không có `default`** ⟹ kẹt vĩnh viễn. H01: 4/4 mã, không cần `default` ✅. H02: 7/8 mã, **có** `default` ✅. **Chỉ H03 sai.** |
| 8 | Vì sao mô phỏng không phát hiện lỗi đó? | `2'b11` **không có đường tới** từ trạng thái hợp lệ. Chỉ fault injection (ép `state`) mới phủ được. **Mô phỏng chức năng chỉ chứng minh các đường có thể đi tới.** |
| 9 | Vì sao netlist có 36 flip-flop mà RTL khai báo 37? | `tx_shift[7]` **không bao giờ được đọc** (bit MSB lấy thẳng từ `tx_data[7]`, các bit sau từ `tx_shift[6]`) ⟹ Yosys xoá. Nó **sẽ sống lại** nếu đổi `MSB_FIRST = 0`. |
| 10 | Song công tiết kiệm được gì? Tốn gì? | Tiết kiệm **một nửa** thời gian bus: 8 chu kỳ SCLK thay vì 16. Tốn **+8 FF** (`rx_shift` riêng) — trừ khi dùng chung một thanh ghi dịch (tiết kiệm 7 FF nhưng giấu mất bản chất). |
| 11 | H03 có 36 FF — nhiều nhất nhóm H — nhưng chỉ 156 cell, ít hơn H02 (182). Vì sao? | Cổng tổ hợp/FF của H03 là **3,33**, thấp nhất (H02: 4,87). SPI **có dây clock chung** ⟹ không cần khôi phục nhịp ⟹ không cần bộ đếm rộng hay cây giải mã lớn. FSM chỉ 3 trạng thái. |
| 12 | `miso` có cần bộ đồng bộ không? | H02 **có** cho `rx_async`; H03 **không có** cho `miso`. Lý lẽ bênh vực: `miso` do tớ lái theo SCLK mà chính H03 phát. Lý lẽ phản bác: **độ trễ vòng bo mạch không bị STA của H03 ràng buộc**. ⬜ Chưa phân tích định lượng. |
| 13 | Rủi ro vật lý lớn nhất của H03 là gì? | **Skew giữa ba pad** `sclk`/`mosi`/`cs_n`. Nếu `mosi` tới muộn hơn `sclk`, setup của tớ bị ăn mòn; một glitch trên `sclk` bị đếm là xung thừa. Chỉ kiểm được ở **L5 (post-layout + SDF)** — chưa chạy. |
| 14 | H03 dùng được với cảm biến cần "1 byte địa chỉ + N byte dữ liệu" không? | **Không** — H03 nhả CS sau **mỗi** byte. Giữ CS qua nhiều byte nằm **ngoài phạm vi** Charter mục 3. Phải ghi vào `limitations.md`. |

## 11. Giới hạn: đã chứng minh được gì, chưa chứng minh được gì

### ✅ Đã chứng minh

| Điều | Bằng chứng |
|---|---|
| RTL tổng hợp được sang `sky130_fd_sc_hd` | `yosys.log` · `synth_stat.txt` |
| Cấu trúc RTL sinh **đúng** phần cứng dự kiến, kể cả bit bị xoá | 36 FF phân rã khớp `netlist.v`; `tx_shift[7]` mất **vì lý do chứng minh được** |
| **Đúng 8 sườn lên SCLK** | `assert(rise_count == 8)` PASS |
| **≥ 8 sườn xuống SCLK** | `assert(fall_count >= 8)` PASS |
| **CS được nhả ở cuối giao dịch** | `assert(cs_n == 1'b1)` PASS |
| **Số chu kỳ giao dịch khớp phân tích FSM** | Dự đoán `16·HC + 1 = 33` ck ⟹ `t = 355 ns`; `simulation.log` ghi `$finish called at 355` |
| Mạch đúng phân loại **Tuần tự** | 36 FF > 0; công suất tuần tự 94,0 % |
| Ràng buộc timing **giả định** 10 ns được thoả | slack +8,02 ns, WNS/TNS = 0,00 |
| Thuật toán SPI mode 0 (không phải RTL) đúng | `reference_model.py` PASS 5000 ca |
| MOSI phát đúng chuỗi (**bằng đọc mã**, không bằng mô phỏng) | `datapath.md` §4, truy vết 8 bit khớp `tx_sequence(0x96,True)` |

### ❌ Chưa chứng minh

| Điều | Vì sao | Cần gì |
|---|---|---|
| **`rx_data` đúng** | Testbench **không kiểm** | Ca **CC-1**: sửa mô hình chip tớ (lái MISO ở sườn **xuống**) + thêm `assert(rx_data == slave_bits)` |
| **`mosi` phát đúng byte** | Testbench **không kiểm** | Ca **CC-2**: thu 8 mẫu MOSI tại 8 sườn lên |
| **FSM an toàn với mã trạng thái thừa** | `2'b11` không có đường tới ⟹ mô phỏng mù | Bản vá `fsm.md` §5.4 + ca **CC-7** (fault injection) |
| CS xuống **trước** sườn lên #1 | Testbench chỉ kiểm CS lúc **cuối** | Ca kiểm mốc 1 |
| `MSB_FIRST = 0` hoạt động | Chưa từng mô phỏng | Ca **CC-3** |
| `HALF_CYCLES = 1` hoạt động | Nhánh chưa từng chạy | Ca **CC-4** |
| Ba ca byte của Charter mục 8 (`0x00`, `0xFF`, `0xA5`) | Chưa có | Bổ sung testbench |
| **Ngân sách độ trễ vòng MISO** | `miso` không qua bộ đồng bộ | Số liệu bo mạch đích, hoặc thêm 1–2 tầng đồng bộ + giảm `f_sclk` |
| **`t_CS_hold` đủ cho chip tớ** | Biên này là hằng số 1 chu kỳ clock, không chỉnh được bằng tham số | Datasheet cảm biến đích |
| **Skew giữa ba pad `sclk`/`mosi`/`cs_n`** | Chưa P&R | L5: post-layout + SDF |
| Hành vi trên netlist / tần số thật | L4, L5, P&R chưa chạy | Gate-level + SDF + STA đa góc |
| Diện tích/công suất ở `HALF_CYCLES` khác | Chỉ tổng hợp một cấu hình | Chạy lại `02_run_synth.sh` |

### ⬛ Ngoài phạm vi (Charter mục 3) — **không phải "chưa làm"**

Mode 1 / 2 / 3 · nhiều tớ · DMA · truyền nhiều byte (kể cả **giữ CS qua nhiều byte**) ·
thiết kế analog mức transistor · tự làm physical design · ASIC sign-off · tape-out · chế tạo
và kiểm tra sau chế tạo.

> Hồ sơ này **không** đưa ra bất kỳ khẳng định nào về sign-off, tape-out, chế tạo, hay tần số
> hoạt động trên silicon.
>
> ### ⚠️ Và một cảnh báo cuối, quan trọng nhất của đề H03:
> **Mô phỏng PASS ở đây chứng minh ÍT hơn nhiều so với vẻ ngoài của nó.** Ba `assert` kiểm
> được số sườn SCLK và trạng thái cuối của CS; chúng **không** chạm tới `rx_data`, `mosi`, hay
> tính an toàn của FSM. Một mô phỏng PASS với độ phủ chức năng thấp có thể **nguy hiểm hơn**
> một mô phỏng FAIL, vì nó tạo ra niềm tin sai.

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
