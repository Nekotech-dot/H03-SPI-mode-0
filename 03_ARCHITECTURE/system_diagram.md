# H03 · Sơ đồ hệ thống (System Diagram)

---

## 1. Bối cảnh ứng dụng (Charter mục 1)

> *"Khối đọc cảm biến gia tốc giao tiếp SPI trong thiết bị đeo tay."*

H03 là **chủ (master)** của một bus SPI bốn dây, nối tới một chip cảm biến gia tốc bên ngoài.
"Thiết bị đeo tay" là bối cảnh quan trọng: nó chốt hai ràng buộc thật — **công suất thấp** và
**tần số đọc vừa phải** (cảm biến gia tốc thường lấy mẫu vài chục đến vài trăm Hz).

```
 ┌──────────────── VI MẠCH (thiết bị đeo tay) ─────────────┐
 │                                                         │
 │  ┌──────────────┐       ┌──────────────────────────┐    │
 │  │ Bộ điều khiển│──────▶│      ███ H03 ███         │    │
 │  │ đọc cảm biến │ start │   Chủ SPI chế độ 0       │    │
 │  │              │tx_data│                          │    │
 │  │              │◀──────│ rx_data · busy · done    │    │
 │  └──────┬───────┘       └───┬────┬─────┬──────┬────┘    │
 │         │                   │    │     │      │         │
 │         ▼              sclk │mosi│cs_n │      │ miso    │
 │  ┌──────────────┐           │    │     │      │         │
 │  │ Bộ lọc / xử  │           │    │     │      │         │
 │  │ lý gia tốc   │           │    │     │      │         │
 │  └──────────────┘           │    │     │      │         │
 └─────────────────────────────┼────┼─────┼──────┼─────────┘
                       BIÊN CHIP│    │     │      │
                                ▼    ▼     ▼      ▲
                          ┌─────────────────────────────┐
                          │  Cảm biến gia tốc (chip TỚ) │
                          │  vd. ADXL / LIS3DH          │
                          │  SCLK  MOSI  CS_n     MISO  │
                          └─────────────────────────────┘
```

### Vì sao chuỗi này chọn SPI

| Tiêu chí | **SPI (H03)** | UART (H01/H02) | I²C |
|---|---|---|---|
| Số dây | 4 | 1–2 | 2 |
| Có dây clock chung | ✅ **Có** | ❌ Không | ✅ Có |
| Phải khôi phục nhịp bit? | ❌ **Không cần** | ✅ Cần (H02) | ❌ |
| Tốc độ | Cao (MHz) | Trung bình | Thấp–trung bình |
| Song công (full-duplex) | ✅ **Có** | Có, nhưng 2 dây riêng | ❌ Bán song công |
| Phổ biến ở cảm biến MEMS | ✅ **Rất** | Hiếm | Có |

> **Điểm bản chất phân biệt H03 với H02:** SPI **có dây clock chung**, nên bên tớ **không cần
> đoán** biên bit. Toàn bộ bài toán "lấy mẫu giữa bit" của H02 **biến mất**. Đổi lại, H03 phải
> trả 3 dây thừa — và phải **tự chịu trách nhiệm** về quan hệ pha giữa SCLK và hai đường dữ
> liệu. Đó là ý nghĩa của "chế độ 0".

## 2. Ranh giới khối

| Chức năng | Thuộc H03 | Thuộc tầng ngoài |
|---|:-:|:-:|
| Sinh 8 xung SCLK, đúng CPOL = 0 | ✅ | |
| Khẳng định / nhả CS bao trọn 8 xung | ✅ | |
| Dịch `tx_data` ra MOSI, MSB-first, đổi ở sườn **xuống** | ✅ | |
| Lấy mẫu MISO ở sườn **lên**, dồn vào `rx_data` | ✅ | |
| Chia clock hệ thống thành `f_sclk` | ✅ (`half_count`) | |
| **Chọn `HALF_CYCLES`** ⟹ chọn `f_sclk` | ⬛ (`parameter`) | ✅ |
| Quyết định gửi byte nào, khi nào | | ✅ |
| **Giải mã lệnh/thanh ghi của chip cảm biến** | ⬛ | ✅ — H03 chỉ biết "một byte", không biết ý nghĩa |
| **Truyền nhiều byte trong một lần CS thấp** | ⬛ ngoài phạm vi Charter mục 3 | ✅ (nếu cần, phải sửa H03) |
| Chọn giữa nhiều chip tớ | ⬛ ngoài phạm vi | ✅ |
| **Bảo đảm độ trễ vòng MISO < `HALF_CYCLES × T_clk`** | ❌ **H03 không kiểm được** | ✅ — thiết kế bo mạch |
| Pad, ESD, chuyển mức điện áp | ⬛ | ✅ |

> ⚠️ **Hạn chế kiến trúc đáng nêu:** H03 nhả CS sau **mỗi** byte. Nhiều cảm biến SPI yêu cầu
> giữ CS thấp suốt **nhiều** byte (ví dụ: 1 byte địa chỉ + N byte dữ liệu). Với H03, tầng ngoài
> **không thể** làm điều đó — giữ CS qua nhiều byte nằm **ngoài phạm vi** Charter mục 3
> ("truyền nhiều byte"). Đây là giới hạn phải ghi rõ trong `07_TRACEABILITY/limitations.md`.

### Nghĩa vụ hợp đồng của tầng ngoài

```
 1. Giữ rst_n = 0 qua ≥ 1 cạnh clk (reset ĐỒNG BỘ).
 2. start và tx_data phải ĐỒNG BỘ với clk. (miso thì KHÔNG cần — nhưng xem mục 3 dưới.)
 3. Chỉ nhấn start khi busy = 0.
 4. Đọc rx_data tại chu kỳ done = 1, hoặc bất cứ lúc nào sau đó cho tới giao dịch kế.
 5. KHÔNG coi rx_data = 0x00 là "chưa có dữ liệu" — 0x00 là giá trị hợp lệ.
 6. Chọn HALF_CYCLES sao cho f_sclk ≤ f_sclk_max của chip tớ,
    VÀ HALF_CYCLES × T_clk > độ trễ vòng MISO.
 7. Nếu cảm biến cần giữ CS qua nhiều byte: H03 hiện KHÔNG hỗ trợ.
```

## 3. Phân loại analog / digital / mixed

| Thành phần | Loại |
|---|---|
| **H03** | **Digital thuần** — 100 % standard cell `sky130_fd_sc_hd` (156 cell, 26 loại) |
| Pad SCLK/MOSI/CS/MISO | Mixed (ESD, chuyển mức, điều khiển slew) — ngoài phạm vi |
| Cảm biến gia tốc | **Mixed** — MEMS (analog) + ADC + giao diện số — ngoài phạm vi |

Bằng chứng: `06_GDSII/synthesis/synth_stat.txt` — 156 cell, **36 là `dfxtp_1`**. Công suất
nhóm Sequential **94,0 %** (`06_GDSII/power/power_report.txt`).

> ⚠️ **Lưu ý về ranh giới miền clock — khác biệt quan trọng so với H02:**
> H02 **có** bộ đồng bộ 2 tầng trên `rx_async`; **H03 KHÔNG có bộ đồng bộ nào trên `miso`** —
> `miso` đi thẳng vào `rx_shift` (dòng 74–76). Lý lẽ bênh vực: `miso` do bên tớ lái theo
> **SCLK mà chính H03 phát ra**, nên nó tương quan với `clk` của H03. Lý lẽ phản bác: **độ trễ
> vòng của bo mạch không bị ràng buộc bởi STA của H03**. Phân tích rủi ro đầy đủ:
> `02_SPECIFICATION/functional_spec.md` §8.1. ⬜ **Chưa phân tích định lượng.**

## 4. Sơ đồ vòng đời RTL → GDSII — trạng thái **thật**

Lấy đúng từ `06_GDSII/physical_report.md` §1 và BRIEF H03.

```
 ┌──────────────────────────────────────────────────────────────────────────────┐
 │  [Charter H03]                                                               │
 │       ▼                                                                      │
 │  ✅ 01 Yêu cầu ──▶ ✅ 02 Đặc tả ──▶ ✅ 03 Kiến trúc ──▶ ✅ 04 RTL              │
 │                                                            │                 │
 │                        ┌───────────────────────────────────┤                 │
 │                        ▼                                   ▼                 │
 │            ✅ Mô hình chuẩn Python                  ✅ Mô phỏng RTL           │
 │               PASS (8 nhóm test,                       ✅ PASS                │
 │               5000 ca ngẫu nhiên)                      $finish @ t = 355 ns  │
 │               python_reference_run.log                 simulation.log        │
 │                        │                                   │                 │
 │                        │                   ⚠️ NHƯNG rx_data và mosi          │
 │                        │                      KHÔNG BAO GIỜ ĐƯỢC KIỂM        │
 │                        │                      (corner_cases.md §1)           │
 │                        └───────────────┬───────────────────┘                 │
 │                                        ▼                                     │
 │                              ✅ Tổng hợp (Yosys 0.33)                         │
 │                                 156 cell · 36 FF · 1443,8848 µm²             │
 │                                 (37 bit khai báo → 1 FF bị xoá)              │
 │                                        │                                     │
 │                       ┌────────────────┼────────────────┐                    │
 │                       ▼                                 ▼                    │
 │              ✅ STA (OpenSTA 3.1.0)            ✅ Công suất (ước lượng)        │
 │                 start → _241_                     1,61e-04 W                 │
 │                 arrival 1,90 ns                   tuần tự 94,0 %             │
 │                 slack  +8,02 ns                   tổ hợp   6,0 %             │
 │                 wns/tns = 0,00                                               │
 │                       ▼                                                      │
 │              ⬜ Floorplan ─▶ ⬜ Placement ─▶ ⬜ CTS ─▶ ⬜ Routing               │
 │                       ▼                                                      │
 │              ⬜ DRC ──▶ ⬜ LVS ──▶ ⬜ GDS                                       │
 │                                                                              │
 │  ⬛ Sign-off · tape-out · chế tạo · kiểm tra sau chế tạo — NGOÀI PHẠM VI       │
 └──────────────────────────────────────────────────────────────────────────────┘

 ✅ đã chạy, có log   ⬜ chưa chạy   ⬛ ngoài phạm vi
```

| Bước | Trạng thái | Công cụ | Bằng chứng |
|---|:-:|---|---|
| Mô hình chuẩn Python | ✅ PASS | CPython 3 | `python_reference_run.log` |
| Mô phỏng RTL | ✅ **PASS** | Icarus Verilog 12.0 | `simulation.log` |
| Tổng hợp | ✅ PASS | Yosys 0.33 | `synthesis/synth_stat.txt` |
| STA | ✅ PASS (real_clock) | OpenSTA 3.1.0 | `sta/timing_report_max.txt` |
| Công suất | ✅ ước lượng | OpenSTA 3.1.0 | `power/power_report.txt` |
| Floorplan / Placement / CTS / Routing | ⬜ chưa chạy | LibreLane / OpenROAD | — |
| DRC / LVS / GDS | ⬜ chưa chạy | Magic · Netgen · KLayout | — |
| Gate-level (L4) · post-layout (L5) | ⬜ chưa chạy | — | — |

> ❗ **H03 là đề duy nhất trong ba đề nhóm H có mô phỏng PASS.** Nhưng PASS ở đây chứng minh
> **ít hơn nhiều** so với vẻ ngoài: testbench **không kiểm `rx_data`**, **không kiểm `mosi`**,
> và độ phủ Charter mục 8 chỉ ~1,5/7. Xem `02_SPECIFICATION/corner_cases.md` §1 và §7.
> **PASS với độ phủ thấp có thể nguy hiểm hơn FAIL, vì nó tạo ra niềm tin sai.**

## 5. Vị trí trong ô Tiny Tapeout

```
 ┌──────────────── 1 ô Tiny Tapeout · 24 chân ─────────────────┐
 │  ui_in[7:0]   ──▶ tx_data[7:0]        8 bit vào             │
 │  uio[a]       ──▶ start               1 bit vào             │
 │  uio[b]       ──▶ miso                1 bit vào             │
 │  clk, rst_n   ──▶ (chân hệ thống riêng)                     │
 │                                                             │
 │  uo_out[0]    ◀── sclk                                      │
 │  uo_out[1]    ◀── mosi                                      │
 │  uo_out[2]    ◀── cs_n                                      │
 │  uo_out[3]    ◀── busy      (ngoài Charter mục 4)           │
 │  uo_out[4]    ◀── done      (ngoài Charter mục 4)           │
 │  uo_out[7:5]  ◀── rx_data[2:0]  ┐                           │
 │  uio[c..h]    ◀── rx_data[7:3]  ┘ 8 bit ra                  │
 │                                                             │
 │  Tổng: 10 bit vào + 13 bit ra = 23 / 24 chân · dư 1         │
 │  uio dùng: 2 vào + 5 ra = 7 / 8                             │
 └─────────────────────────────────────────────────────────────┘
```

Charter mục 4 đã cảnh báo: *"chân `uio[0, 1]` bị gán vừa làm đầu vào vừa làm đầu ra… chỉ cần
đánh số lại."* Sơ đồ trên là **một** cách đánh số lại hợp lệ. Lưu ý ngân sách **rất sát**
(23/24) vì `busy` và `done` là hai cổng **ngoài** danh mục Charter. Nếu cần thêm chân, chúng
là hai ứng viên đầu tiên để lược bớt — nhưng `done` rất đáng giữ (nó là thứ H01 **thiếu**).

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
