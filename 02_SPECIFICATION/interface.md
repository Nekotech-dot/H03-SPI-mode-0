# H03 · Giao diện (Interface)

---

## 1. Ánh xạ chân theo Charter (mục 4)

> Theo danh mục đề: ui_in[7:0]=byte gửi · uio_in[0]=bắt đầu · uio_in[1]=MISO · uo_out[0]=SCLK · uo_out[1]=MOSI · uo_out[2]=CS · uio_out[7:0]=byte nhận
> Ngân sách chân: 10 bit vào + 11 bit ra = 21 trên 24 chân.
> Lỗi ánh xạ cần sửa trước khi thiết kế: chân uio[0, 1] bị gán vừa làm đầu vào vừa làm đầu ra. Tổng bit vẫn trong 24 chân nên chỉ cần đánh số lại.
> Một ô Tiny Tapeout có đúng 24 chân: ui_in 8 chỉ vào, uo_out 8 chỉ ra, uio 8 chọn chiều từng chân. uio_in và uio_out là cùng một bộ chân vật lý.

## 2. Bảng giao diện đã CHỐT — module `h03_spi_master`

Bảng dưới đây **đọc trực tiếp từ RTL** (`04_IMPLEMENTATION/rtl/`), không phải chép tay,
nên luôn nhất quán với mã nguồn.

| Tín hiệu | Chiều | Độ rộng (bit) | Vai trò | Mức tích cực / giả định |
|---|---|---:|---|---|
| `clk` | input | 1 | clock | |
| `rst_n` | input | 1 | reset (đồng bộ hoá trạng thái) | |
| `start` | input | 1 | trạng thái / bắt tay | |
| `tx_data[7:0]` | input | 8 | dữ liệu vào | |
| `miso` | input | 1 | dữ liệu vào | |
| `mosi` | output | 1 | kết quả ra | |
| `sclk` | output | 1 | clock | |
| `cs_n` | output | 1 | kết quả ra | |
| `rx_data[7:0]` | output | 8 | kết quả ra | |
| `busy` | output | 1 | trạng thái / bắt tay | |
| `done` | output | 1 | trạng thái / bắt tay | |

**Tổng hợp:** 5 cổng vào (12 bit) · 6 cổng ra (13 bit).

**Clock:** `clk`, `sclk`

**Reset:** `rst_n`

## 3. Ngân sách chân Tiny Tapeout

| Hạng mục | Số bit |
|---|---:|
| Tổng bit vào | **12** |
| Tổng bit ra | **13** |
| **Tổng cộng** | **25** |
| Ô Tiny Tapeout có | **24** |
| **Chênh lệch** | **+1 (VƯỢT)** |

> Nhắc lại cấu trúc chân Tiny Tapeout: một ô có đúng 24 chân — `ui_in` 8 chỉ vào,
> `uo_out` 8 chỉ ra, `uio` 8 chọn chiều từng chân; **`uio_in` và `uio_out` là cùng một bộ
> chân vật lý**.

> 🟡 **ĐIỂM MỞ.** Thiết kế cần nhiều hơn 24 bit. Charter mục 4 yêu cầu **hỏi giảng viên
> trước khi chọn cách xử lý**. Gói này chốt lõi logic và **cố ý không** tự bịa ra lớp vỏ
> vật lý. Ba hướng thường dùng: (1) nạp/phát nhiều nhịp — thêm ô nhớ; (2) thu hẹp độ rộng
> một toán hạng; (3) bỏ bớt tín hiệu ra. Mỗi hướng đều đánh đổi khác nhau — xem
> `03_ARCHITECTURE/tradeoff.md`.

## 4. Điều kiện hợp lệ của đầu vào

| Điều kiện | Ai bảo đảm |
|---|---|
| Các cổng vào không chứa `X`/`Z` khi lấy mẫu | Tầng ngoài |
| Tín hiệu vào đồng bộ với `clk` hoặc đã qua bộ đồng bộ | Tầng ngoài |
| Chuỗi reset được giữ đủ dài trước khi bắt đầu hoạt động | Tầng ngoài |

---

*Phiên bản: v1.0 · Ngày: 2026-09-24 · Truy vết: REQ-H03-002, AC-1.*
