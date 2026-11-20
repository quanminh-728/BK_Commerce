# BK-Commerce

## Chạy ứng dụng

Yêu cầu Python 3 và MySQL 8.0.16 trở lên. Mở terminal tại thư mục dự án.

1. Kết nối MySQL bằng `mysql --default-character-set=utf8mb4 -u root`. Trong cửa sổ MySQL, chạy lần lượt các lệnh sau.

   **Dùng cơ sở dữ liệu thử nghiệm.** `Part1_CSDL.sql` xóa và tạo lại cơ sở dữ liệu `ThuongMaiDienTu` trước khi nạp dữ liệu mẫu.

   ```sql
   SOURCE Part1_CSDL.sql;
   USE ThuongMaiDienTu;
   SOURCE Part2_CSDL.sql;
   SOURCE TRIGGER.sql;
   ```

2. Trong terminal, cài thư viện và chạy Flask.

   ```sh
   python -m pip install -r requirements.txt
   python UI.py
   ```

   Mặc định Flask kết nối MySQL tại `localhost:3306` bằng tài khoản `root`, mật khẩu trống. Có thể đặt `DB_HOST`, `DB_PORT`, `DB_USER` và `DB_NAME` qua biến môi trường. Nếu tài khoản có mật khẩu, cập nhật cấu hình `password` trong `get_conn()` của `UI.py` trên máy bạn.

3. Mở [Quản lý sản phẩm](http://127.0.0.1:5000/) hoặc [Chi tiết đơn hàng](http://127.0.0.1:5000/chi-tiet-don-hang).

## Kiểm thử trigger

Trên trang **Chi tiết đơn hàng**, chọn khách hàng để mở các đơn của họ.

| Ca kiểm thử | Thao tác | Kết quả mong đợi với dữ liệu mẫu |
| --- | --- | --- |
| Sửa số lượng | Đơn **#2**, dòng **#1**, sửa số lượng đặt thành **10**, sau đó thử **36**. | **10** lưu được. **36** bị chặn vì tồn kho là **35**. Khôi phục số lượng ban đầu sau khi thử. |
| Thêm dòng | Trong đơn **#2**, chọn biến thể **#2** và đặt **36**. | Lỗi hiện trong hộp thoại và bảng giữ nguyên số dòng. |
| Sửa và ẩn đánh giá | Đơn **#5**, dòng **#1**, đổi đánh giá đang hiển thị từ **5 sao** xuống **2 sao**, rồi chuyển sang **Ẩn**. | Điểm trung bình lần lượt là **2.00** và **0.00**. Đổi lại **5 sao** và **Hiển thị** để khôi phục **5.00**. |

`TRIGGER.sql` chạy sẵn `sp_Demo_Trigger()` khi nạp. Bảng kết quả trong MySQL có **13 bước**, bao gồm thêm và xóa đánh giá. Với sản phẩm **#5**, thêm đánh giá thử **2 sao** đưa điểm từ **5.00** xuống **3.50**, rồi xóa đánh giá đưa điểm về **5.00**.
