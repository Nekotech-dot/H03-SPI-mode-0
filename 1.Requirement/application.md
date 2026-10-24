# H03 · Bối cảnh ứng dụng



| | |
|---|---|
| Mã đề | **H03** |
| Tên đề | Chủ SPI chế độ 0 |
| Nhóm đề | H · Giao tiếp nối tiếp |
| Độ khó | Trung bình |
| Loại mạch | **Tuần tự** |
| Quy mô ước lượng (Charter) | ~230–330 cell · 1×1 tile |
| Nguồn gốc | Project Charter — H03, mục 1 |

---

## 1. Mục tiêu và bối cảnh ứng dụng

Trích nguyên văn Charter mục 1:

> Phân tích khối số “Chủ SPI chế độ 0” ở mức khối. Bối cảnh ứng dụng: Khối đọc cảm biến gia tốc giao tiếp SPI trong thiết bị đeo tay.

## 2. Vị trí khối H03 trong hệ thống

```
   ┌──────────────┐      ┌──────────────────────────────┐      ┌──────────────┐
   │  Nguồn tín   │─────▶│      ►►► KHỐI H03 ◄◄◄        │─────▶│  Tầng tiêu   │
   │  hiệu / dữ   │      │  Chủ SPI chế độ 0             │      │  thụ kết quả │
   │  liệu vào    │      │  Loại mạch: Tuần tự          │      │              │
   └──────────────┘      └──────────────────────────────┘      └──────────────┘
```

> Sơ đồ chi tiết có chú thích: `03_ARCHITECTURE/system_diagram.md`.

## 3. Phân loại analog / digital / mixed

| Khối | Phân loại | Ghi chú |
|---|---|---|
| Cảm biến / nguồn tín hiệu vật lý (nếu có) | Analog | Đại lượng liên tục |
| Chuyển đổi ADC/DAC (nếu có) | Mixed-signal | Ranh giới analog–số |
| **H03 — Chủ SPI chế độ 0** | **Digital, tuần tự** | Có ô nhớ, hoạt động theo cạnh clock |
| Tầng xử lý phía sau | Digital | Tiêu thụ kết quả của H03 |

Bằng chứng cho dòng phân loại của H03: tổng hợp thật cho **36 flip-flop**
(`06_GDSII/synthesis/synth_stat.txt`).

---

**Truy vết:** yêu cầu sinh từ tài liệu này được đánh số `REQ-H03-0xx` trong
`01_REQUIREMENT/requirements.md`, và truy vết đến bằng chứng trong `07_TRACEABILITY/RTM.csv`.

*Phiên bản: v1.0 · Ngày: 2026-09-24*
