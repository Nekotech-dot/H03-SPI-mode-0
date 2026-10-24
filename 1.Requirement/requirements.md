# H03 · Bảng yêu cầu (Requirements)



Mọi yêu cầu đều **suy trực tiếp từ Project Charter — H03**. Cột *Nguồn* chỉ rõ mục nào
của Charter sinh ra yêu cầu đó. Không có yêu cầu nào do người soạn tự thêm.

Mức: **M** = bắt buộc · **S** = nên có · **O** = tuỳ chọn.

---

## 1. Yêu cầu chức năng và cấu trúc

| ID | Mức | Nội dung yêu cầu | Nguồn |
|---|---|---|---|
| REQ-H03-001 | M | Khối thực hiện đúng chức năng mô tả trong Charter mục 1: *Chủ SPI chế độ 0*. | mục 1 |
| REQ-H03-002 | M | Giao diện đúng ánh xạ chân Charter mục 4 (xem `02_SPECIFICATION/interface.md`). | mục 4 |
| REQ-H03-003 | M | Loại mạch phải đúng phân loại Charter: **Tuần tự** — có ô nhớ, đồng bộ theo clock. | mục 10 |
| REQ-H03-004 | M | Quy mô nằm trong khoảng hợp lý cho ô 1×1 tile (Charter ước lượng ~230–330 cell · 1×1 tile). | metadata |

## 2. Yêu cầu kiểm chứng

| ID | Mức | Nội dung yêu cầu | Nguồn |
|---|---|---|---|
| REQ-H03-010 | M | Chạy đủ các ca kiểm thử bắt buộc của Charter mục 8 (xem §4). | mục 8 |
| REQ-H03-011 | M | Bổ sung **ít nhất hai ca tự xây dựng**, trong đó có **ca biên**. | mục 8 |
| REQ-H03-012 | M | Mỗi khẳng định phải đi kèm **bằng chứng** và **điều kiện tạo ra bằng chứng**. | mục 6 |
| REQ-H03-013 | S | Thu một **artifact số có chú thích** và nêu điều kiện tạo ra nó. | mục 3, 5 |

## 3. Yêu cầu phân tích riêng (đặc thù của H03)

> Charter mục 9 — bắt buộc trả lời bằng số liệu của chính mình:
>
> SPI mode 0 quy định dữ liệu đổi ở sườn xuống và lấy mẫu ở sườn lên của SCLK. Chứng minh thiết kế của mình làm đúng bằng waveform có chú thích — nêu rõ khoảng thiết lập (setup) mà bên tớ được hưởng.
> Bắt buộc trả lời bằng số liệu của chính mình. Mỗi đề một câu khác nhau.

| ID | Mức | Nội dung |
|---|---|---|
| REQ-H03-020 | M | Trả lời câu phân tích riêng ở trên bằng dữ liệu do chính mình sinh ra. |
| REQ-H03-021 | M | Trả lời các câu hỏi kỹ thuật Charter mục 2 (xem §5) bằng bằng chứng. |

## 4. Ca kiểm thử bắt buộc (Charter mục 8)

- Gửi 0x00, 0xFF, 0xA5 · thu đồng thời một giá trị đã biết · kiểm CS bao trọn 8 xung SCLK
- Bổ sung ít nhất hai ca tự xây dựng, trong đó có ca biên.

Danh sách thực thi và kết quả: `05_VERIFICATION/test_matrix.csv`.

## 5. Câu hỏi kỹ thuật của Charter (mục 2)

1. **CS phải bao trọn 8 xung SCLK — chứng minh trên waveform bằng cách chỉ vào hai mốc?**
2. **Mode 0 (CPOL=0, CPHA=0) nghĩa là lấy mẫu MISO ở sườn nào — và mạch của em làm đúng chưa?**
3. **Phát MOSI và thu MISO xảy ra đồng thời — điều đó tiết kiệm được gì so với gửi rồi nhận?**

> Sinh viên được phép thay bằng câu hỏi của mình, miễn là cụ thể và trả lời được bằng bằng
> chứng — không viết "tìm hiểu về…". *(Charter mục 2)*

Câu trả lời kèm bằng chứng: `05_VERIFICATION/verification_report.md` và `06_GDSII/physical_report.md`.

## 6. Yêu cầu bàn giao (Charter mục 5)

- Hồ sơ phân tích đủ tám thành phần, có số phiên bản và ngày sửa.
- Bảng giao diện: tên tín hiệu, chiều, độ rộng, mức tích cực, giả định.
- Một artifact số có chú thích và nêu điều kiện tạo ra nó.
- Kết luận nêu rõ đã chứng minh được gì và chưa chứng minh được gì.

## 7. Mốc thực hiện (Charter mục 7)

- M1 · T7. Chốt đề và viết charter: ứng dụng, mục tiêu, 2–3 câu hỏi kỹ thuật.
- M2 · T8–9. Bảng hành vi suy từ đặc tả; đọc RTL và waveform; lập danh sách ca kiểm thử.
- M3 · T11–12. Sơ đồ khối hỗ trợ; thu artifact số, chú thích và đối chiếu bảng hành vi.
- M4 · T13–14. Hoàn thiện bảng giao diện, RTM-lite, sơ đồ vòng đời; rà từng khẳng định.
- M5 · T15. Nộp hồ sơ và trình bày; trả lời câu phân tích riêng bằng số của chính mình.

## 8. Rủi ro chính (Charter mục 10)

> Chỗ hay tắc: Lấy mẫu MISO sai sườn — chạy vẫn 'có vẻ đúng' với dữ liệu ổn định, chỉ lộ khi dữ liệu đổi sát sườn.
> Dấu hiệu làm đúng: 8 (dịch ra) + 8 (dịch vào) + 4 (đếm bit) + chia SCLK ≈ 24–28 ô nhớ.

---

*Phiên bản: v1.0 · Ngày: 2026-09-24 · Nguồn chuẩn: `Project_Charter_80_De.docx`, mục H03.*
