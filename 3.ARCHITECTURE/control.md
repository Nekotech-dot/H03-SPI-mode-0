# H03 · Phần điều khiển (Control)

---

## 1. H03 là **chủ** — nó tự định nghĩa thời gian

Đây là khác biệt bản chất với H02. H02 phải **khôi phục** nhịp từ một sườn duy nhất; H03
**phát ra** nhịp và gửi hẳn nó ra ngoài qua dây `sclk`. Hệ quả:

| | H02 (tớ của clock ngoài) | **H03 (chủ)** |
|---|---|---|
| Nguồn nhịp bit | Suy từ sườn xuống của RX | **Tự sinh từ `clk`** |
| Bộ đếm cần rộng bao nhiêu | `⌈log₂(f_clk/baud)⌉` — có thể 9–14 bit | **`⌈log₂(HALF_CYCLES)⌉` = 2 bit** |
| Rủi ro sai nhịp | **Cao** — trôi tích luỹ | **Bằng 0** — bên tớ dùng chính SCLK của ta |
| Phần điều khiển | 7 trạng thái, 11 bit | **3 trạng thái, 8 bit** |

H03 chỉ có **8 bit điều khiển** (`state` 2 + `half_count` 2 + `edge_count` 4) trên tổng 36 FF
— tỉ lệ điều khiển **thấp nhất** nhóm H. Phần còn lại (24 bit) là dữ liệu và đầu ra.

## 2. Ba tầng điều khiển và quan hệ phân tần

```
      clk (f)
       │
       ▼
  ┌──────────────────────────────┐
  │ half_count[1:0] · 2 FF       │  half_tick ⟺ == HALF_CYCLES-1
  │ mod HALF_CYCLES              │─────────────┐    tần số: f / HALF_CYCLES
  └──────────────────────────────┘             │
       ▲ xoá về 0 khi half_tick                │
       └────────────────────────────────────────┤
                                                ▼
                            ┌──────────────────────────────────┐
                            │  sclk · 1 FF — ĐẢO mỗi half_tick │
                            │  f_sclk = f / (2 × HALF_CYCLES)  │───▶ sclk (ra ngoài)
                            └───────┬──────────────────┬───────┘
                                    │ sclk == 0        │ sclk == 1
                                    │ (sắp LÊN)        │ (sắp XUỐNG)
                                    ▼                  ▼
                    ┌───────────────────────┐  ┌────────────────────┐
                    │ edge_count[3:0]· 4 FF │  │ so sánh == 8       │
                    │ +1 mỗi SƯỜN LÊN       │─▶│ ⟹ state ← FINISH   │
                    └───────────────────────┘  └────────────────────┘
```

**Quy tắc phân tần nghiêm ngặt:** `sclk`, `tx_shift`, `rx_shift`, `mosi`, `edge_count` **chỉ**
được phép đổi trong nhánh `if (half_tick)` (dòng 68). Khi `half_tick = 0`, toàn bộ datapath
**đóng băng**; chỉ `half_count` tăng. Cùng kiểu kiến trúc với H01 — và đó là kiểu **đúng**.

## 3. Bảng tín hiệu điều khiển và tác dụng

| Tín hiệu | Nguồn | Rộng | Tác dụng lên datapath |
|---|---|:-:|---|
| `start` | cổng vào | 1 | Khi `state == IDLE`: **nạp** `tx_shift ← tx_data`, **xoá** `rx_shift`, `mosi ← tx_data[7]`, `cs_n ← 0`, `busy ← 1`, `state ← TRANSFER`. Ở trạng thái khác: **bị bỏ qua** |
| `rst_n` | cổng vào | 1 | Reset **đồng bộ** toàn bộ 36 FF; `sclk ← 0`, `cs_n ← 1` (nhả bus sạch) |
| `half_tick` | tổ hợp | 1 | **Enable chủ đạo** — cho phép đảo `sclk` và cập nhật datapath |
| `sclk` (giá trị hiện tại) | FF | 1 | **Chọn pha**: `0` ⟹ nhánh sườn lên (lấy mẫu MISO); `1` ⟹ nhánh sườn xuống (đổi MOSI) |
| `edge_count == 8` | tổ hợp | 1 | Chọn giữa "gửi bit tiếp" và "kết thúc giao dịch" |
| `state[1:0]` | FF | 2 | Giải mã toàn khối |
| `MSB_FIRST` | **parameter** | — | Chốt lúc **biên dịch**, không tốn phần cứng chạy |

## 4. Enable phân cấp — và một quyết định thiết kế rất tinh tế

```systemverilog
TRANSFER: begin
    busy <= 1'b1;
    if (half_tick) begin                          // ← ENABLE mức 1
        half_count <= '0;
        if (sclk == 1'b0) begin                   // ← ENABLE mức 2: chọn PHA
            sclk <= 1'b1;
            rx_shift <= {rx_shift[6:0],miso};
            edge_count <= edge_count + 1'b1;
        end else begin
            sclk <= 1'b0;
            if (edge_count == 8) state <= FINISH; // ← ENABLE mức 3
            else begin tx_shift <= …; mosi <= tx_shift[6]; end
        end
    end else half_count <= half_count + 1'b1;
end
```

### ⭐ Vì sao `edge_count == 8` được kiểm ở nhánh **sườn xuống**, không phải sườn lên

Đây là chi tiết quyết định tính đúng đắn của cả khối:

| Nếu kiểm ở nhánh **sườn lên** | Nếu kiểm ở nhánh **sườn xuống** (RTL làm thế này) |
|---|---|
| Sau sườn lên thứ 8, `edge_count = 8` ⟹ sang `FINISH` ngay | Sườn xuống thứ 8 **vẫn được phát ra** |
| `sclk` **kẹt ở mức cao** khi vào `FINISH` | `sclk <= 1'b0` được thực thi trước |
| Chu kỳ SCLK thứ 8 **không hoàn chỉnh** | Đủ **8 chu kỳ SCLK trọn vẹn** |
| ❌ **Vi phạm CPOL = 0** | ✅ **Đúng chuẩn** |

> Đây là loại lỗi rất dễ mắc và **rất khó thấy** nếu testbench chỉ đếm `rise_count == 8` —
> đúng như testbench hiện tại đang làm. Bằng chứng chắc chắn duy nhất là **kiểm `sclk = 0`
> ngay trước khi `cs_n` lên**. Ca đó **hiện chưa có**.

### `FINISH` là một trạng thái riêng chỉ để "dọn dẹp"

```systemverilog
FINISH: begin
    sclk <= 1'b0;  cs_n <= 1'b1;  busy <= 1'b0;
    rx_data <= rx_shift;  done <= 1'b1;
    state <= IDLE;
end
```

Một chu kỳ clock dành riêng cho: nhả CS, chốt `rx_data`, phát xung `done`. Cái giá là **+1 chu
kỳ** mỗi giao dịch (`16·HC + 1` thay vì `16·HC`).

> 🔎 **Đối chiếu có giá trị dạy học:** ở **H02**, việc dùng trạng thái riêng cho mỗi lần "làm
> việc" chính là **lỗi chí mạng** (`known_issues.md` của H02). Ở **H03** thì nó **vô hại**.
> Khác nhau ở đâu? Vì `FINISH` của H03 nằm **NGOÀI vòng lặp bit** — nó chạy đúng **một lần**
> mỗi giao dịch, nên không gây **trôi tích luỹ**. Ở H02, `S_DATA_SAMPLE` nằm **TRONG** vòng
> lặp 8 bit, nên mỗi vòng cộng thêm một chu kỳ.
>
> **Quy tắc rút ra: một trạng thái "dọn dẹp" ngoài vòng lặp là độ trễ; một trạng thái "làm
> việc" trong vòng lặp là TRÔI NHỊP.**

## 5. Quan hệ điều khiển ↔ datapath

| Thời điểm | Điều khiển làm gì | Datapath làm gì |
|---|---|---|
| `IDLE`, `start = 0` | Giữ `IDLE`; xoá `half_count`, `edge_count`; `sclk ← 0`, `cs_n ← 1` | `rx_data` giữ nguyên (kết quả giao dịch trước) |
| `IDLE`, `start = 1` | `state ← TRANSFER`, `busy ← 1`, `cs_n ← 0` | **Nạp** `tx_shift ← tx_data`, **xoá** `rx_shift`, `mosi ← tx_data[7]` |
| `TRANSFER`, `half_tick = 0` | `half_count + 1` | **đóng băng** |
| `TRANSFER`, `half_tick`, `sclk = 0` | `sclk ← 1`, `edge_count + 1` | **Lấy mẫu `miso`** vào `rx_shift` |
| `TRANSFER`, `half_tick`, `sclk = 1`, `edge_count ≠ 8` | `sclk ← 0` | **Dịch `tx_shift`**, `mosi ← tx_shift[6]` |
| `TRANSFER`, `half_tick`, `sclk = 1`, `edge_count = 8` | `sclk ← 0`, `state ← FINISH` | **Không** dịch, **không** đổi `mosi` |
| `FINISH` | `cs_n ← 1`, `busy ← 0`, `done ← 1`, `state ← IDLE` | **`rx_data ← rx_shift`** |
| `state = 2'b11` | ❌ **KHÔNG CÓ NHÁNH** — kẹt vĩnh viễn | đóng băng vĩnh viễn |

## 6. Ba khiếm khuyết điều khiển

### 6.1 ⚠️ Không có `default` cho mã trạng thái thừa — LỖI TIỀM ẨN

`enum logic [1:0]` với **3** trạng thái ⟹ mã `2'b11` thừa; `case (state)` (dòng 46) **không
có `default`**. Nếu `state = 2'b11`: không lệnh gán nào trong `case` chạy ⟹ mọi thanh ghi
**giữ nguyên** ⟹ FSM **kẹt vĩnh viễn**, `cs_n` có thể kẹt ở `0` (giữ chip tớ bị chọn).
**Chỉ reset mới thoát.** Bản vá: `fsm.md` §5.2. **Chưa áp dụng.**

### 6.2 Không có `ready`/`ack` — lệnh bị nuốt im lặng

`start = 1` khi `busy = 1` bị bỏ qua, không có tín hiệu báo. Giống H01. Tầng ngoài phải tự
kiểm `busy` trước khi nhấn `start`.

### 6.3 CS nhả sau **mỗi** byte — không giữ được qua nhiều byte

Nhiều cảm biến SPI yêu cầu giữ CS thấp suốt 1 byte địa chỉ + N byte dữ liệu. H03 **không** hỗ
trợ, và Charter mục 3 liệt "truyền nhiều byte" vào **ngoài phạm vi**. Phải ghi rõ trong
`07_TRACEABILITY/limitations.md` — đây là giới hạn **ứng dụng**, không phải lỗi.

### 6.4 Biên CS bất đối xứng

| Biên | Khoảng cách | Phụ thuộc `HALF_CYCLES`? |
|---|---|:-:|
| CS xuống → sườn lên **đầu tiên** | **`HALF_CYCLES`** chu kỳ clock | ✅ có |
| Sườn xuống **cuối** → CS lên | **1** chu kỳ clock | ❌ **không** |

Biên sau (`t_CS_hold`) là **hằng số 1 chu kỳ clock**, bất kể `HALF_CYCLES`. Nếu chip tớ yêu
cầu `t_CS_hold` lớn hơn một chu kỳ clock hệ thống, thiết kế **không đáp ứng** và **không có
cách nào chỉnh bằng tham số**. ⬜ **Chưa kiểm** với datasheet cảm biến đích. Xem
`timing_diagram.md` §4.

## 7. Nghĩa vụ hợp đồng của tầng ngoài

```
 1. Giữ rst_n = 0 qua ≥ 1 cạnh clk (reset ĐỒNG BỘ).
 2. start và tx_data đồng bộ với clk; tx_data hợp lệ đúng tại cạnh có start = 1.
 3. Chỉ nhấn start khi busy = 0 (không có ready/ack — lệnh thừa bị nuốt im lặng).
 4. Đọc rx_data tại chu kỳ done = 1 hoặc bất cứ lúc nào trước giao dịch kế.
 5. KHÔNG coi rx_data = 0x00 là "chưa có dữ liệu".
 6. Chọn HALF_CYCLES thoả CẢ BA:
      a) f_sclk = f_clk/(2·HALF_CYCLES) ≤ f_sclk_max của chip tớ
      b) HALF_CYCLES × T_clk > độ trễ vòng MISO  (H03 KHÔNG tự kiểm được)
      c) HALF_CYCLES × T_clk ≥ t_setup của chip tớ cho MOSI
 7. Kiểm t_CS_hold của chip tớ ≤ 1 chu kỳ clock — nếu không, H03 KHÔNG đáp ứng.
 8. Nếu cảm biến cần giữ CS qua nhiều byte: H03 KHÔNG hỗ trợ (ngoài phạm vi Charter mục 3).
```

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
