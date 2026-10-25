# H03 · Báo cáo kiểm chứng (Verification Report)



**Ngày chạy:** 2026-09-24 · **Phiên bản:** v1.0

---

## 1. Điều kiện tạo ra bằng chứng

> Charter mục 6: *"Mỗi khẳng định đi kèm bằng chứng **và điều kiện tạo ra bằng chứng đó**."*

| Hạng mục | Giá trị |
|---|---|
| Hệ điều hành | Ubuntu 22.04 LTS (x86-64) |
| Công cụ mô phỏng | **Icarus Verilog 12.0 (stable)** (cờ `-g2012`) |
| Top module | `h03_spi_master` |
| RTL | `04_IMPLEMENTATION/rtl/` |
| Mô hình chuẩn | `05_VERIFICATION/golden_model/` |
| Testbench | `05_VERIFICATION/testbench/` |
| Lệnh chạy | `bash 04_IMPLEMENTATION/scripts/01_run_sim.sh` |
| Nguồn gốc gói | `H03_FINAL_MENTOR_PACKAGE_v1_0` |

## 2. Kết quả tổng hợp

| Lớp | Nội dung | Kết quả |
|---|---|---|
| L0 | Mô hình chuẩn Python | ✅ **PASS** |
| L2 | Mô phỏng RTL | ✅ PASS — testbench chạy hết, không có assertion nào vi phạm |
| L3 | Kiểm cấu trúc — số flip-flop | ✅ đo được **36** FF, phân loại Charter là **Tuần tự** |
| L4 | Mô phỏng gate-level | ⬜ chưa chạy |
| L5 | Mô phỏng post-layout (SDF) | ⬜ chưa chạy |

## 3. Trích log mô phỏng

```
H03 TB completed
05_VERIFICATION/testbench/h03_spi_master_tb.sv:49: $finish called at 355 (1s)
```

Log đầy đủ: [`simulation.log`](simulation.log)

## 4. Kiểm cấu trúc — số flip-flop

Trích `../06_GDSII/synthesis/synth_stat.txt` (Yosys 0.33 (git sha1 2584903a060) + `sky130_fd_sc_hd`):

| Chỉ số | Giá trị |
|---|---:|
| Tổng số cell | **156** |
| Cell tuần tự (flip-flop / latch) | **36** |
| Diện tích | 1443,8848 µm² |


✅ Đúng phân loại **Tuần tự** của Charter — có ô nhớ đồng bộ theo clock.


## 5. Trả lời câu hỏi kỹ thuật của Charter (mục 2)

> 1. CS phải bao trọn 8 xung SCLK — chứng minh trên waveform bằng cách chỉ vào hai mốc?
> 2. Mode 0 (CPOL=0, CPHA=0) nghĩa là lấy mẫu MISO ở sườn nào — và mạch của em làm đúng chưa?
> 3. Phát MOSI và thu MISO xảy ra đồng thời — điều đó tiết kiệm được gì so với gửi rồi nhận?
> Sinh viên được phép thay bằng câu hỏi của mình, miễn là cụ thể và trả lời được bằng bằng chứng — không viết “tìm hiểu về…”.

Phần trả lời dựa trên số liệu đo được nằm ở:

- Câu về **giao diện / tín hiệu**: `02_SPECIFICATION/interface.md`
- Câu về **thời gian / tần số**: `06_GDSII/sta/` và `06_GDSII/physical_report.md`
- Câu về **diện tích / tài nguyên**: `06_GDSII/physical_report.md` §2
- Phân tích bản chất và cơ chế: `implementation-notes_H03.md`

## 6. Những gì báo cáo này **chưa** chứng minh

| Chưa chứng minh | Vì sao |
|---|---|
| Kiến trúc bên trong đúng như mô tả | Kiểm chứng chức năng mù về cấu trúc — phải đọc RTL và netlist |
| Độ trễ lan truyền đạt yêu cầu | Mô phỏng hành vi là zero-delay |
| Mạch đúng sau place & route | Chưa chạy P&R |
| Không có glitch gây hại | Mô phỏng zero-delay không sinh glitch |

Danh sách đầy đủ: `07_TRACEABILITY/limitations.md`.

---

*Truy vết: REQ-H03-001, REQ-H03-003, REQ-H03-010…013.*
