# BK-Commerce

## 1. Tạo môi trường Python và cài thư viện

```powershell
python --version
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
```

Lệnh cài đặt sẽ tải Flask và PyMySQL. Nếu máy chỉ nhận lệnh `py`, dùng `py -m venv .venv` để tạo môi trường. Các bước sau gọi trực tiếp Python trong `.venv`, không cần kích hoạt môi trường.

## 2. Khởi động MySQL và tạo database

Nhấn `Win + R`, nhập `services.msc`, tìm dịch vụ MySQL (ví dụ `MySQL80`) và chọn **Start** nếu chưa chạy.

Trong terminal tại thư mục dự án, đăng nhập MySQL:

```powershell
mysql --default-character-set=utf8mb4 -u root -p
```

Nếu báo không tìm thấy lệnh `mysql`, dùng đường dẫn đầy đủ, sửa phiên bản/thư mục theo máy bạn:

```powershell
& "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --default-character-set=utf8mb4 -u root -p
```

Nhập mật khẩu MySQL khi được hỏi; màn hình không hiển thị ký tự lúc nhập.

**Chỉ khởi tạo dữ liệu lần đầu hoặc khi muốn đặt lại dữ liệu mẫu.** File `sql/Part1_CSDL.sql` **xóa toàn bộ database `ThuongMaiDienTu` nếu đã tồn tại**, sau đó tạo lại bảng và dữ liệu mẫu. Sao lưu dữ liệu cần giữ trước khi chạy.

Khi thấy dấu nhắc `mysql>`, chạy lần lượt các lệnh SQL sau (không nhập chúng trực tiếp vào PowerShell):

```sql
SOURCE sql/Part1_CSDL.sql;
USE ThuongMaiDienTu;
SOURCE sql/Part2_CSDL.sql;
SOURCE sql/TRIGGER.sql;
SOURCE sql/CURSOR_LOOP.sql;
SOURCE sql/Stored Procedure.sql;

SHOW TABLES;
EXIT;
```

Các đường dẫn `SOURCE` tính từ thư mục đã mở terminal khi đăng nhập MySQL. Giữ nguyên dấu cách trong tên `Stored Procedure.sql`.

| File | Nội dung |
| --- | --- |
| `Part1_CSDL.sql` | Tạo database, bảng và dữ liệu mẫu. |
| `Part2_CSDL.sql` | Tạo các thủ tục thêm, sửa, xóa sản phẩm và chạy demo kiểm thử. |
| `TRIGGER.sql` | Thiết lập trigger, ràng buộc và chạy demo trigger. |
| `CURSOR_LOOP.sql` | Tạo các hàm tính tổng chi tiêu và xác định hạng cho trang tra cứu hội viên. |
| `Stored Procedure.sql` | Tạo thủ tục tìm biến thể sản phẩm theo giá và danh mục. |

Nếu có dòng `ERROR` khi nạp file, xử lý lỗi trước khi tiếp tục chạy ứng dụng.

## 3. Cấu hình kết nối và chạy ứng dụng

Sau khi thoát MySQL, chạy trong **cùng một terminal PowerShell**:

```powershell
$env:DB_HOST = "localhost"
$env:DB_PORT = "3306"
$env:DB_USER = "root"
$env:DB_PASSWORD = 'NhapMatKhauMySQLCuaBan'
$env:DB_NAME = "ThuongMaiDienTu"

.\.venv\Scripts\python.exe UI.py
```

Thay `NhapMatKhauMySQLCuaBan` bằng mật khẩu thật của tài khoản MySQL. Nếu dùng tài khoản, máy chủ hoặc cổng khác, thay giá trị tương ứng. Ứng dụng đọc các biến môi trường này trong `get_conn()` của `UI.py`; không cần ghi mật khẩu vào code. Nếu tài khoản không có mật khẩu, đặt `$env:DB_PASSWORD = ''`.

## 4. Mở giao diện

- [Quản lý sản phẩm](http://127.0.0.1:5000/)
- [Tra cứu hội viên](http://127.0.0.1:5000/hoi-vien)
- [Chi tiết đơn hàng](http://127.0.0.1:5000/chi-tiet-don-hang): ban đầu chỉ hiện khung chọn khách hàng. Chọn một khách hàng trong danh sách để tự hiển thị đơn hàng và sản phẩm của người đó.

Giữ terminal chạy trong khi sử dụng. Nhấn `Ctrl + C` để dừng server. Chế độ `debug` hiện tại dùng cho phát triển trên máy cá nhân.

## Chạy lại ở những lần sau

Mở PowerShell tại thư mục dự án, bảo đảm MySQL đang chạy, rồi thực hiện lại **bước 4**. Các biến môi trường trên chỉ có hiệu lực trong terminal đã đặt chúng; khi mở terminal mới, cần đặt lại.

Không cần tạo lại `.venv` hoặc nạp lại SQL mỗi lần chạy. Khi `requirements.txt` thay đổi sau khi pull code, chạy lại:

```powershell
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
```

## BONUS: Kiểm thử trigger

Trên trang **Chi tiết đơn hàng**, chọn khách hàng để mở các đơn của họ.

| Ca kiểm thử | Thao tác | Kết quả mong đợi với dữ liệu mẫu |
| --- | --- | --- |
| Sửa số lượng | Đơn **#2**, dòng **#1**, sửa số lượng đặt thành **10**, sau đó thử **36**. | **10** lưu được. **36** bị chặn vì tồn kho là **35**. Khôi phục số lượng ban đầu sau khi thử. |
| Thêm dòng | Trong đơn **#2**, chọn biến thể **#2** và đặt **36**. | Lỗi hiện trong hộp thoại và bảng giữ nguyên số dòng. |
| Sửa và ẩn đánh giá | Đơn **#5**, dòng **#1**, đổi đánh giá đang hiển thị từ **5 sao** xuống **2 sao**, rồi chuyển sang **Ẩn**. | Điểm trung bình lần lượt là **2.00** và **0.00**. Đổi lại **5 sao** và **Hiển thị** để khôi phục **5.00**. |

`TRIGGER.sql` chạy sẵn `sp_Demo_Trigger()` khi nạp. Bảng kết quả trong MySQL có **13 bước**, bao gồm thêm và xóa đánh giá. Với sản phẩm **#5**, thêm đánh giá thử **2 sao** đưa điểm từ **5.00** xuống **3.50**, rồi xóa đánh giá đưa điểm về **5.00**.
