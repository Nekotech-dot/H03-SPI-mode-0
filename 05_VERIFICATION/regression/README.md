# H03 · Regression testbench

Đặt thư mục này tại `05_VERIFICATION/regression/` trong bộ hồ sơ H03. **RTL gốc của thầy
không bị sửa** (sha256 `1b352c9d…ebf8`, giống hệt `08_ORIGINAL_SOURCE/rtl/`).

| File | Vai trò |
|---|---|
| `h03_spi_master_regression_tb.sv` | Testbench regression viết bằng task, 4 nhóm test |
| `run_regression.sh` | Chạy với `HALF_CYCLES` = 1, 2, 4 → `logs/results.csv`, VCD |
| `run_mutation.py` | Kiểm chính testbench: cài 9 lỗi vào **bản sao** RTL, xem TB nào bắt được |
| `plot_waveform.py` | Vẽ waveform có chú thích từ VCD (mọi mốc thời gian đọc từ VCD) |
| `run_gls.sh` | L4 gate-level: chạy cùng regression TB trên netlist LibreLane (sau tổng hợp và sau P&R) |
| `ref/h03_spi_master_tb_sua_slave.sv` | Testbench một vector đã sửa slave, dùng để so sánh |
| `logs/` | Log, bảng kết quả, VCD, ảnh waveform |

## Chạy lại (từ thư mục gốc H03)

```bash
bash    05_VERIFICATION/regression/run_regression.sh
python3 05_VERIFICATION/regression/run_mutation.py
python3 05_VERIFICATION/regression/plot_waveform.py \
        05_VERIFICATION/regression/logs/h03_waveform_hc2.vcd \
        05_VERIFICATION/regression/logs/h03_waveform_hc2.png
```

Điều kiện tạo bằng chứng: Icarus Verilog 12.0 (stable), cờ `-g2012`, `Tclk = 10 ns`,
`MSB_FIRST = 1`, slave giữ MISO 1 ns sau sườn lên rồi đặt `X`.

## Bốn nhóm test

| Nhóm | Nội dung | Kiểm gì |
|---|---|---|
| A | 6 cặp TX/slave: 00/FF, FF/00, A5/3A, B4/3A, 01/80, 80/01 | MOSI đúng byte, RX đúng byte, MSB-first, biên all-0/all-1 |
| B | Chạy trong mọi ca A, C, D | 8 sườn lên + 8 sườn xuống trong cửa sổ CS; MOSI chỉ đổi ở sườn xuống / lúc CS xuống; MISO = X ngoài cửa sổ quanh sườn lên; đo `t_lead`, `t_lag`, setup; `busy`, `done` 1 chu kỳ, `rx_data` không đổi giữa chừng |
| C | C1 reset giữa transaction · C2 START giữ mức 1 · C3 ép FSM vào `2'b11` (chỉ thông tin) | Nhả bus sạch khi reset và phục hồi; chu kỳ lặp `(16·HC+2)·Tclk`; lỗi thiếu `default` |
| D | Một transaction TX = 0x96, slave = 0x3A, chỉ phần này ghi VCD | Waveform minh hoạ cho báo cáo |

## Kết quả (18/10/2026)

* `HC = 1, 2, 4`: **ALL H03 TESTS PASS**, mỗi cấu hình 116 phép kiểm.
* Đo được: `t_lead = setup_min = HC × Tclk` (10 / 20 / 40 ns), `t_lag = 1 × Tclk = 10 ns`,
  chu kỳ lặp khi giữ START = 180 / 340 / 660 ns = `(16·HC+2) × Tclk`.
  Tất cả khớp `02_SPECIFICATION/functional_spec.md` §2 và §7.
* C3: FSM **kẹt ở `2'b11`**, START sau đó không được nhận, chỉ thoát bằng reset. Đây là xác nhận
  bằng mô phỏng cho lỗi thiếu `default` mà `fsm.md` §5.2 đã phân tích.

## Mutation test: testbench có bắt được lỗi không?

| Mã | Lỗi cài vào bản sao RTL | TB gốc thầy | TB sửa slave | Regression |
|---|---|:-:|:-:|:-:|
| M1 | Ghép bit nhận theo LSB-first | ✗ | ✗ | ✓ |
| M2 | Lấy mẫu MISO ở sườn **xuống** (rủi ro Charter mục 10) | ✗ | ✗ | ✓ |
| M3 | Đổi MOSI ở sườn **lên** | ✗ | ✗ | ✓ |
| M4 | Phát 9 xung SCLK | ✓ | ✓ | ✓ |
| M5 | Nhả CS cùng lúc sườn xuống #8 | ✗ | ✓ | ✓ |
| M6 | Không đưa bit đầu lên MOSI khi CS xuống | ✗ | ✓ | ✓ |
| M7 | `rx_data` cập nhật từng bit giữa chừng | ✗ | ✗ | ✓ |
| M8 | Bộ chia lệch 1 chu kỳ | treo | treo | ✓ (HC=2)\* |
| M9 | `done` không tự xoá | ✗ | ✗ | ✓ |
| | **Tổng bắt được** | **1/9** | **3/9** | **9/9** |

\* M8 tương đương RTL đúng khi `HC = 1` (nhánh `HALF_CYCLES <= 1`), nên chỉ lộ ở `HC ≥ 2`.
Đây là lý do regression phải chạy nhiều giá trị `HALF_CYCLES`.

## L4 · Gate-level simulation (18/10/2026)

```bash
CELL_LIB=<repo skywater-pdk-libs-sky130_fd_sc_hd> bash 05_VERIFICATION/regression/run_gls.sh
```

Netlist lấy từ lần chạy LibreLane `RUN_2026-09-25_17-54-52` (chính netlist đã đi vào GDS).
Model cell: `sky130_fd_sc_hd`, bản `FUNCTIONAL` (zero-delay), từ repo
`google/skywater-pdk-libs-sky130_fd_sc_hd`. Netlist tổng hợp với tham số mặc định nên chạy
`HALF_CYCLES = 4`. Ca C3 (ép `dut.state`) bị bỏ ở gate-level vì tên tín hiệu nội bộ không còn.

| Netlist | Instance | Flip-flop | Kết quả |
|---|---:|---:|---|
| Sau tổng hợp (`06-yosys-synthesis`) | 130 | 37 | **ALL H03 TESTS PASS** (116 phép kiểm) |
| Sau P&R (`final/nl`, có buffer, fill, tap) | 764 | 37 | **ALL H03 TESTS PASS** (116 phép kiểm) |

Kiểm tra chéo: cài lỗi stuck-at-0 vào flip-flop `rx_data[1]` của netlist → regression **FAIL**
ngay (`RX: kỳ vọng 0x3a, DUT thu 0x38`). Vậy GLS thực sự chạy trên các cell, không PASS suông.

Lưu ý số flip-flop: netlist LibreLane có **37** FF vì Yosys mã hoá lại FSM 3 trạng thái thành
**one-hot (3 FF)** (`yosys-synthesis.log`: *mapping auto encoding to one-hot*). Bản tổng hợp
riêng trong hồ sơ của thầy ghi 36 FF (FSM nhị phân 2 bit).

## Giới hạn

* GLS ở trên là **zero-delay**. Chưa chạy post-layout có back-annotate SDF (L5).
* Slave là mô hình lý tưởng; độ trễ vòng thật của MISO trên bo mạch chưa được mô hình hoá.
* `MSB_FIRST = 0` chưa được chạy.
