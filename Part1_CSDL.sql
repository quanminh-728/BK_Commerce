

DROP DATABASE IF EXISTS ThuongMaiDienTu;
CREATE DATABASE ThuongMaiDienTu CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE ThuongMaiDienTu;

SET FOREIGN_KEY_CHECKS = 0;

-- ============================================================================
-- PHẦN 1: DDL - TẠO 30 BẢNG VÀ CÁC RÀNG BUỘC TOÀN VẸN
-- ============================================================================

-- 1. Bảng Tài khoản
CREATE TABLE `Tài khoản` (
    `Mã tài khoản` INT AUTO_INCREMENT PRIMARY KEY,
    `Tên đăng nhập` VARCHAR(50) NOT NULL UNIQUE,
    `Mật khẩu` VARCHAR(255) NOT NULL,
    `Trạng thái tài khoản` VARCHAR(30) NOT NULL DEFAULT 'Hoạt động',
    `Ngày tạo tài khoản` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `Đăng nhập gần nhất` DATETIME NULL,
    CONSTRAINT chk_tk_trangthai CHECK (`Trạng thái tài khoản` IN ('Hoạt động', 'Bị khóa', 'Chờ xác thực'))
) ENGINE=InnoDB;

-- 2. Bảng Người dùng (Quan hệ 1:1 với Tài khoản)
CREATE TABLE `Người dùng` (
    `Mã người dùng` INT AUTO_INCREMENT PRIMARY KEY,
    `Họ` VARCHAR(50) NOT NULL,
    `Tên đệm` VARCHAR(50) NULL,
    `Tên` VARCHAR(50) NOT NULL,
    `Số điện thoại` CHAR(10) NOT NULL UNIQUE,
    `Email` VARCHAR(100) NOT NULL UNIQUE,
    `Trạng thái hồ sơ` VARCHAR(30) NOT NULL DEFAULT 'Hoạt động',
    `Mã tài khoản` INT NOT NULL UNIQUE,
    CONSTRAINT fk_nd_taikhoan FOREIGN KEY (`Mã tài khoản`) REFERENCES `Tài khoản`(`Mã tài khoản`) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_nd_sdt CHECK (`Số điện thoại` REGEXP '^0[0-9]{9}$'),
    CONSTRAINT chk_nd_email CHECK (`Email` LIKE '%@%.%')
) ENGINE=InnoDB;

-- 3. Bảng Hạng hội viên
CREATE TABLE `Hạng hội viên` (
    `Mã hạng` INT AUTO_INCREMENT PRIMARY KEY,
    `Tên hạng` VARCHAR(50) NOT NULL UNIQUE,
    `Mức chi tiêu tối thiểu` DECIMAL(15, 2) NOT NULL DEFAULT 0,
    `Tỷ lệ tích điểm` DECIMAL(5, 2) NOT NULL DEFAULT 1.00,
    CONSTRAINT chk_hhv_chitieu CHECK (`Mức chi tiêu tối thiểu` >= 0),
    CONSTRAINT chk_hhv_tyle CHECK (`Tỷ lệ tích điểm` >= 0)
) ENGINE=InnoDB;

-- 4. Bảng Khách hàng (Chuyên biệt hóa 1:1 từ Người dùng)
CREATE TABLE `Khách hàng` (
    `Mã người dùng` INT PRIMARY KEY,
    `Điểm khả dụng` INT NOT NULL DEFAULT 0,
    `Tổng chi tiêu tích lũy` DECIMAL(15, 2) NOT NULL DEFAULT 0,
    `Mã hạng` INT NOT NULL,
    CONSTRAINT fk_kh_nguoidung FOREIGN KEY (`Mã người dùng`) REFERENCES `Người dùng`(`Mã người dùng`) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_kh_hang FOREIGN KEY (`Mã hạng`) REFERENCES `Hạng hội viên`(`Mã hạng`) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_kh_diem CHECK (`Điểm khả dụng` >= 0),
    CONSTRAINT chk_kh_chitieu CHECK (`Tổng chi tiêu tích lũy` >= 0)
) ENGINE=InnoDB;

-- 5. Bảng Quản trị viên (Chuyên biệt hóa 1:1 từ Người dùng)
CREATE TABLE `Quản trị viên` (
    `Mã người dùng` INT PRIMARY KEY,
    CONSTRAINT fk_qtv_nguoidung FOREIGN KEY (`Mã người dùng`) REFERENCES `Người dùng`(`Mã người dùng`) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

-- 6. Bảng Chi nhánh
CREATE TABLE `Chi nhánh` (
    `Mã chi nhánh` INT AUTO_INCREMENT PRIMARY KEY,
    `Tên chi nhánh` VARCHAR(100) NOT NULL,
    `Số nhà + đường` VARCHAR(150) NOT NULL,
    `Phường/Xã` VARCHAR(100) NOT NULL,
    `Quận/Huyện` VARCHAR(100) NOT NULL,
    `Tỉnh/TP` VARCHAR(100) NOT NULL,
    `SDT hotline` CHAR(10) NOT NULL,
    `Trạng thái hoạt động` VARCHAR(30) NOT NULL DEFAULT 'Đang hoạt động',
    CONSTRAINT chk_cn_sdt CHECK (`SDT hotline` REGEXP '^0[0-9]{9}$')
) ENGINE=InnoDB;

-- 7. Bảng Nhân viên chi nhánh (Chuyên biệt hóa 1:1 từ Người dùng)
CREATE TABLE `Nhân viên chi nhánh` (
    `Mã người dùng` INT PRIMARY KEY,
    `Mã chi nhánh` INT NOT NULL,
    CONSTRAINT fk_nv_nguoidung FOREIGN KEY (`Mã người dùng`) REFERENCES `Người dùng`(`Mã người dùng`) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_nv_chinhanh FOREIGN KEY (`Mã chi nhánh`) REFERENCES `Chi nhánh`(`Mã chi nhánh`) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- 8. Bảng Địa chỉ nhận hàng
CREATE TABLE `Địa chỉ nhận hàng` (
    `Mã địa chỉ` INT AUTO_INCREMENT PRIMARY KEY,
    `Mã khách hàng` INT NOT NULL,
    `Tên người nhận` VARCHAR(100) NOT NULL,
    `SDT người nhận` CHAR(10) NOT NULL,
    `Số nhà + đường` VARCHAR(150) NOT NULL,
    `Phường/Xã` VARCHAR(100) NOT NULL,
    `Quận/Huyện` VARCHAR(100) NOT NULL,
    `Tỉnh/TP` VARCHAR(100) NOT NULL,
    `Trạng thái mặc định` BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT fk_dc_khachhang FOREIGN KEY (`Mã khách hàng`) REFERENCES `Khách hàng`(`Mã người dùng`) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT chk_dc_sdt CHECK (`SDT người nhận` REGEXP '^0[0-9]{9}$')
) ENGINE=InnoDB;

-- 9. Bảng Giao dịch điểm
CREATE TABLE `Giao dịch điểm` (
    `Mã giao dịch điểm` INT AUTO_INCREMENT PRIMARY KEY,
    `Mã khách hàng` INT NOT NULL,
    `Số điểm thay đổi` INT NOT NULL,
    `Thời điểm giao dịch` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `Nội dung` VARCHAR(255) NOT NULL,
    `Loại giao dịch` VARCHAR(30) NOT NULL,
    `Số dư sau giao dịch` INT NOT NULL,
    CONSTRAINT fk_gdd_khachhang FOREIGN KEY (`Mã khách hàng`) REFERENCES `Khách hàng`(`Mã người dùng`) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT chk_gdd_loai CHECK (`Loại giao dịch` IN ('Cộng điểm', 'Trừ điểm', 'Hoàn điểm')),
    CONSTRAINT chk_gdd_sodu CHECK (`Số dư sau giao dịch` >= 0)
) ENGINE=InnoDB;

-- 10. Bảng Danh mục (Đệ quy Cha - Con)
CREATE TABLE `Danh mục` (
    `Mã danh mục` INT AUTO_INCREMENT PRIMARY KEY,
    `Mã danh mục cha` INT NULL,
    `Tên danh mục` VARCHAR(100) NOT NULL,
    `Mô tả` TEXT NULL,
    `Trạng thái` VARCHAR(30) NOT NULL DEFAULT 'Hiển thị',
    CONSTRAINT fk_dm_cha FOREIGN KEY (`Mã danh mục cha`) REFERENCES `Danh mục`(`Mã danh mục`) ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB;

-- 11. Bảng Thương hiệu
CREATE TABLE `Thương hiệu` (
    `Mã thương hiệu` INT AUTO_INCREMENT PRIMARY KEY,
    `Tên thương hiệu` VARCHAR(100) NOT NULL UNIQUE,
    `Mô tả` TEXT NULL,
    `Trạng thái` VARCHAR(30) NOT NULL DEFAULT 'Hoạt động'
) ENGINE=InnoDB;

-- 12. Bảng Nhà cung cấp
CREATE TABLE `Nhà cung cấp` (
    `Mã nhà cung cấp` INT AUTO_INCREMENT PRIMARY KEY,
    `Tên nhà cung cấp` VARCHAR(150) NOT NULL,
    `SDT` CHAR(10) NOT NULL,
    `Địa chỉ` VARCHAR(255) NOT NULL,
    `Trạng thái hợp tác` VARCHAR(30) NOT NULL DEFAULT 'Đang hợp tác',
    CONSTRAINT chk_ncc_sdt CHECK (`SDT` REGEXP '^0[0-9]{9}$')
) ENGINE=InnoDB;

-- 13. Bảng Sản phẩm
CREATE TABLE `Sản phẩm` (
    `Mã sản phẩm` INT AUTO_INCREMENT PRIMARY KEY,
    `Tên sản phẩm` VARCHAR(200) NOT NULL,
    `Mô tả` TEXT NULL,
    `Giá cơ sở` DECIMAL(15, 2) NOT NULL DEFAULT 0,
    `Trạng thái kinh doanh` VARCHAR(30) NOT NULL DEFAULT 'Đang kinh doanh',
    `Điểm đánh giá TB` DECIMAL(3, 2) NOT NULL DEFAULT 0.00,
    CONSTRAINT chk_sp_gia CHECK (`Giá cơ sở` >= 0),
    CONSTRAINT chk_sp_diem CHECK (`Điểm đánh giá TB` BETWEEN 0 AND 5)
) ENGINE=InnoDB;

-- 14. Bảng Phân loại sản phẩm (M:N Sản phẩm - Danh mục)
CREATE TABLE `Phân loại sản phẩm` (
    `Mã sản phẩm` INT NOT NULL,
    `Mã danh mục` INT NOT NULL,
    PRIMARY KEY (`Mã sản phẩm`, `Mã danh mục`),
    CONSTRAINT fk_plsp_sp FOREIGN KEY (`Mã sản phẩm`) REFERENCES `Sản phẩm`(`Mã sản phẩm`) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_plsp_dm FOREIGN KEY (`Mã danh mục`) REFERENCES `Danh mục`(`Mã danh mục`) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

-- 15. Bảng Gắn thương hiệu (M:N Thương hiệu - Sản phẩm)
CREATE TABLE `Gắn thương hiệu` (
    `Mã thương hiệu` INT NOT NULL,
    `Mã sản phẩm` INT NOT NULL,
    PRIMARY KEY (`Mã thương hiệu`, `Mã sản phẩm`),
    CONSTRAINT fk_gth_th FOREIGN KEY (`Mã thương hiệu`) REFERENCES `Thương hiệu`(`Mã thương hiệu`) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_gth_sp FOREIGN KEY (`Mã sản phẩm`) REFERENCES `Sản phẩm`(`Mã sản phẩm`) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

-- 16. Bảng Cung cấp (M:N Nhà cung cấp - Sản phẩm)
CREATE TABLE `Cung cấp` (
    `Mã nhà cung cấp` INT NOT NULL,
    `Mã sản phẩm` INT NOT NULL,
    PRIMARY KEY (`Mã nhà cung cấp`, `Mã sản phẩm`),
    CONSTRAINT fk_cc_ncc FOREIGN KEY (`Mã nhà cung cấp`) REFERENCES `Nhà cung cấp`(`Mã nhà cung cấp`) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_cc_sp FOREIGN KEY (`Mã sản phẩm`) REFERENCES `Sản phẩm`(`Mã sản phẩm`) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

-- 17. Bảng Hình ảnh sản phẩm (Thuộc tính đa trị 1:N)
CREATE TABLE `Hình ảnh sản phẩm` (
    `Mã sản phẩm` INT NOT NULL,
    `Hình ảnh sản phẩm` VARCHAR(255) NOT NULL,
    PRIMARY KEY (`Mã sản phẩm`, `Hình ảnh sản phẩm`),
    CONSTRAINT fk_hasp_sp FOREIGN KEY (`Mã sản phẩm`) REFERENCES `Sản phẩm`(`Mã sản phẩm`) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

-- 18. Bảng Biến thể sản phẩm
CREATE TABLE `Biến thể sản phẩm` (
    `Mã biến thể` INT AUTO_INCREMENT PRIMARY KEY,
    `Mã sản phẩm` INT NOT NULL,
    `Màu sắc` VARCHAR(50) NULL,
    `Kết quả xử lý` VARCHAR(100) NULL,
    `Dung lượng` VARCHAR(50) NULL,
    `Kích thước` VARCHAR(20) NULL,
    `Giá bán` DECIMAL(15, 2) NOT NULL DEFAULT 0,
    `Trạng thái khả dụng` VARCHAR(30) NOT NULL DEFAULT 'Còn hàng',
    CONSTRAINT fk_btsp_sp FOREIGN KEY (`Mã sản phẩm`) REFERENCES `Sản phẩm`(`Mã sản phẩm`) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT chk_btsp_gia CHECK (`Giá bán` >= 0)
) ENGINE=InnoDB;

-- 19. Bảng Tồn kho (M:N Chi nhánh - Biến thể sản phẩm)
CREATE TABLE `Tồn kho` (
    `Mã chi nhánh` INT NOT NULL,
    `Mã biến thể` INT NOT NULL,
    `Số lượng tồn` INT NOT NULL DEFAULT 0,
    `Cập nhật gần nhất` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`Mã chi nhánh`, `Mã biến thể`),
    CONSTRAINT fk_tkho_cn FOREIGN KEY (`Mã chi nhánh`) REFERENCES `Chi nhánh`(`Mã chi nhánh`) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_tkho_bt FOREIGN KEY (`Mã biến thể`) REFERENCES `Biến thể sản phẩm`(`Mã biến thể`) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT chk_tkho_sl CHECK (`Số lượng tồn` >= 0)
) ENGINE=InnoDB;

-- 20. Bảng Giỏ hàng (1:1 với Khách hàng)
CREATE TABLE `Giỏ hàng` (
    `Mã giỏ hàng` INT AUTO_INCREMENT PRIMARY KEY,
    `Mã khách hàng` INT NOT NULL UNIQUE,
    `Ngày tạo` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `Cập nhật gần nhất` DATETIME NULL,
    `Trạng thái` VARCHAR(30) NOT NULL DEFAULT 'Đang hoạt động',
    `Tổng tiền tạm tính` DECIMAL(15, 2) NOT NULL DEFAULT 0,
    CONSTRAINT fk_gh_khachhang FOREIGN KEY (`Mã khách hàng`) REFERENCES `Khách hàng`(`Mã người dùng`) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT chk_gh_tong CHECK (`Tổng tiền tạm tính` >= 0)
) ENGINE=InnoDB;

-- 21. Bảng Chi tiết giỏ hàng (M:N Giỏ hàng - Biến thể sản phẩm)
CREATE TABLE `Chi tiết giỏ hàng` (
    `Mã giỏ hàng` INT NOT NULL,
    `Mã biến thể` INT NOT NULL,
    `Số lượng` INT NOT NULL DEFAULT 1,
    `Trạng thái lựa chọn` BOOLEAN NOT NULL DEFAULT TRUE,
    PRIMARY KEY (`Mã giỏ hàng`, `Mã biến thể`),
    CONSTRAINT fk_ctgh_gh FOREIGN KEY (`Mã giỏ hàng`) REFERENCES `Giỏ hàng`(`Mã giỏ hàng`) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_ctgh_bt FOREIGN KEY (`Mã biến thể`) REFERENCES `Biến thể sản phẩm`(`Mã biến thể`) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT chk_ctgh_sl CHECK (`Số lượng` > 0)
) ENGINE=InnoDB;

-- 22. Bảng Đơn hàng
CREATE TABLE `Đơn hàng` (
    `Mã đơn hàng` INT AUTO_INCREMENT PRIMARY KEY,
    `Mã khách hàng` INT NOT NULL,
    `Mã chi nhánh` INT NOT NULL,
    `Ngày đặt hàng` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `Trạng thái hiện tại` VARCHAR(40) NOT NULL DEFAULT 'Chờ xử lý',
    `Phương thức thanh toán` VARCHAR(50) NOT NULL,
    `Phí vận chuyển` DECIMAL(15, 2) NOT NULL DEFAULT 0,
    `Tổng tiền hàng` DECIMAL(15, 2) NOT NULL DEFAULT 0,
    `Số tiền giảm` DECIMAL(15, 2) NOT NULL DEFAULT 0,
    `Tổng thanh toán` DECIMAL(15, 2) NOT NULL DEFAULT 0,
    `Tên người nhận` VARCHAR(100) NOT NULL,
    `SDT` CHAR(10) NOT NULL,
    `Số nhà + đường` VARCHAR(150) NOT NULL,
    `Phường/Xã` VARCHAR(100) NOT NULL,
    `Quận/Huyện` VARCHAR(100) NOT NULL,
    `Tỉnh/TP` VARCHAR(100) NOT NULL,
    CONSTRAINT fk_dh_khachhang FOREIGN KEY (`Mã khách hàng`) REFERENCES `Khách hàng`(`Mã người dùng`) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_dh_chinhanh FOREIGN KEY (`Mã chi nhánh`) REFERENCES `Chi nhánh`(`Mã chi nhánh`) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_dh_trangthai CHECK (`Trạng thái hiện tại` IN ('Chờ xử lý', 'Đang chuẩn bị', 'Đang giao hàng', 'Hoàn thành', 'Đã hủy')),
    CONSTRAINT chk_dh_tien CHECK (`Phí vận chuyển` >= 0 AND `Tổng tiền hàng` >= 0 AND `Số tiền giảm` >= 0 AND `Tổng thanh toán` >= 0),
    CONSTRAINT chk_dh_sdt CHECK (`SDT` REGEXP '^0[0-9]{9}$')
) ENGINE=InnoDB;

-- 23. Bảng Chi tiết đơn hàng (Thực thể yếu của Đơn hàng)
CREATE TABLE `Chi tiết đơn hàng` (
    `Mã đơn hàng` INT NOT NULL,
    `Số thứ tự dòng` INT NOT NULL,
    `Mã biến thể` INT NOT NULL,
    `Số lượng` INT NOT NULL,
    `Đơn giá lúc mua` DECIMAL(15, 2) NOT NULL,
    `Số tiền giảm` DECIMAL(15, 2) NOT NULL DEFAULT 0,
    `Thành tiền` DECIMAL(15, 2) NOT NULL DEFAULT 0,
    PRIMARY KEY (`Mã đơn hàng`, `Số thứ tự dòng`),
    CONSTRAINT fk_ctdh_dh FOREIGN KEY (`Mã đơn hàng`) REFERENCES `Đơn hàng`(`Mã đơn hàng`) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_ctdh_bt FOREIGN KEY (`Mã biến thể`) REFERENCES `Biến thể sản phẩm`(`Mã biến thể`) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_ctdh_sl CHECK (`Số lượng` > 0),
    CONSTRAINT chk_ctdh_gia CHECK (`Đơn giá lúc mua` >= 0 AND `Số tiền giảm` >= 0 AND `Thành tiền` >= 0)
) ENGINE=InnoDB;

-- 24. Bảng Lịch sử trạng thái đơn hàng (Thực thể yếu của Đơn hàng)
CREATE TABLE `Lịch sử trạng thái đơn hàng` (
    `Mã đơn hàng` INT NOT NULL,
    `Thời điểm cập nhật` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `Trạng thái` VARCHAR(40) NOT NULL,
    `Ghi chú` VARCHAR(255) NULL,
    `Mã nhân viên` INT NULL,
    PRIMARY KEY (`Mã đơn hàng`, `Thời điểm cập nhật`),
    CONSTRAINT fk_lstdh_dh FOREIGN KEY (`Mã đơn hàng`) REFERENCES `Đơn hàng`(`Mã đơn hàng`) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_lstdh_nv FOREIGN KEY (`Mã nhân viên`) REFERENCES `Nhân viên chi nhánh`(`Mã người dùng`) ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB;

-- 25. Bảng Đánh giá (1:1 với Chi tiết đơn hàng)
CREATE TABLE `Đánh giá` (
    `Mã đánh giá` INT AUTO_INCREMENT PRIMARY KEY,
    `Mã đơn hàng` INT NOT NULL,
    `Số thứ tự dòng` INT NOT NULL,
    `Số sao (1-5)` TINYINT NOT NULL,
    `Nội dung nhận xét` TEXT NULL,
    `Thời điểm đánh giá` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `Trạng thái hiển thị` VARCHAR(30) NOT NULL DEFAULT 'Hiển thị',
    UNIQUE KEY uq_dg_ctdh (`Mã đơn hàng`, `Số thứ tự dòng`),
    CONSTRAINT fk_dg_ctdh FOREIGN KEY (`Mã đơn hàng`, `Số thứ tự dòng`) REFERENCES `Chi tiết đơn hàng`(`Mã đơn hàng`, `Số thứ tự dòng`) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT chk_dg_sosao CHECK (`Số sao (1-5)` BETWEEN 1 AND 5)
) ENGINE=InnoDB;

-- 26. Bảng Hình ảnh đánh giá (Thuộc tính đa trị 1:N)
CREATE TABLE `Hình ảnh đánh giá` (
    `Mã đánh giá` INT NOT NULL,
    `Hình ảnh đánh giá` VARCHAR(255) NOT NULL,
    PRIMARY KEY (`Mã đánh giá`, `Hình ảnh đánh giá`),
    CONSTRAINT fk_hadg_dg FOREIGN KEY (`Mã đánh giá`) REFERENCES `Đánh giá`(`Mã đánh giá`) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

-- 27. Bảng Yêu cầu bảo hành đổi trả (1:N từ Chi tiết đơn hàng)
CREATE TABLE `Yêu cầu bảo hành đổi trả` (
    `Mã yêu cầu` INT AUTO_INCREMENT PRIMARY KEY,
    `Mã đơn hàng` INT NOT NULL,
    `Số thứ tự dòng` INT NOT NULL,
    `Mã chi nhánh` INT NOT NULL,
    `Loại yêu cầu` VARCHAR(30) NOT NULL,
    `Lý do` VARCHAR(255) NOT NULL,
    `Xử lý mong muốn` VARCHAR(100) NOT NULL,
    `Ngày tạo` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `Trạng thái xử lý` VARCHAR(40) NOT NULL DEFAULT 'Chờ tiếp nhận',
    `Lý do từ chối` VARCHAR(255) NULL,
    CONSTRAINT fk_ycbh_ctdh FOREIGN KEY (`Mã đơn hàng`, `Số thứ tự dòng`) REFERENCES `Chi tiết đơn hàng`(`Mã đơn hàng`, `Số thứ tự dòng`) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_ycbh_cn FOREIGN KEY (`Mã chi nhánh`) REFERENCES `Chi nhánh`(`Mã chi nhánh`) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_ycbh_loai CHECK (`Loại yêu cầu` IN ('Bảo hành', 'Đổi hàng', 'Trả hàng hoàn tiền'))
) ENGINE=InnoDB;

-- 28. Bảng Hình ảnh minh chứng (Thuộc tính đa trị 1:N)
CREATE TABLE `Hình ảnh minh chứng` (
    `Mã yêu cầu` INT NOT NULL,
    `Hình ảnh minh chứng` VARCHAR(255) NOT NULL,
    PRIMARY KEY (`Mã yêu cầu`, `Hình ảnh minh chứng`),
    CONSTRAINT fk_hamc_yc FOREIGN KEY (`Mã yêu cầu`) REFERENCES `Yêu cầu bảo hành đổi trả`(`Mã yêu cầu`) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

-- 29. Bảng Voucher
CREATE TABLE `Voucher` (
    `Mã voucher` INT AUTO_INCREMENT PRIMARY KEY,
    `Loại giảm giá` VARCHAR(30) NOT NULL,
    `Giá trị giảm` DECIMAL(15, 2) NOT NULL,
    `Mức giảm tối đa` DECIMAL(15, 2) NULL,
    `Đơn tối thiểu` DECIMAL(15, 2) NOT NULL DEFAULT 0,
    `Tổng lượt sử dụng` INT NOT NULL DEFAULT 100,
    `Ngày bắt đầu` DATETIME NOT NULL,
    `Ngày kết thúc` DATETIME NOT NULL,
    `Trạng thái` VARCHAR(30) NOT NULL DEFAULT 'Đang áp dụng',
    CONSTRAINT chk_vc_loai CHECK (`Loại giảm giá` IN ('Phần trăm', 'Số tiền cố định', 'Miễn phí vận chuyển')),
    CONSTRAINT chk_vc_giatri CHECK (`Giá trị giảm` > 0 AND `Đơn tối thiểu` >= 0 AND `Tổng lượt sử dụng` >= 0),
    CONSTRAINT chk_vc_ngay CHECK (`Ngày kết thúc` > `Ngày bắt đầu`)
) ENGINE=InnoDB;

-- 30. Bảng Áp dụng voucher (M:N Đơn hàng - Voucher)
CREATE TABLE `Áp dụng voucher` (
    `Mã đơn hàng` INT NOT NULL,
    `Mã voucher` INT NOT NULL,
    `Số tiền giảm thực tế` DECIMAL(15, 2) NOT NULL DEFAULT 0,
    PRIMARY KEY (`Mã đơn hàng`, `Mã voucher`),
    CONSTRAINT fk_advc_dh FOREIGN KEY (`Mã đơn hàng`) REFERENCES `Đơn hàng`(`Mã đơn hàng`) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_advc_vc FOREIGN KEY (`Mã voucher`) REFERENCES `Voucher`(`Mã voucher`) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_advc_tien CHECK (`Số tiền giảm thực tế` >= 0)
) ENGINE=InnoDB;

SET FOREIGN_KEY_CHECKS = 1;


-- ============================================================================
-- PHẦN 2: DML - THÊM DỮ LIỆU MẪU 
-- ============================================================================

-- 1. Tài khoản (15 dòng để đủ 1:1 cho 5 Khách hàng + 5 Quản trị viên + 5 Nhân viên chi nhánh)
-- Lưu ý: Các bảng chuyên biệt hóa 1:1 bắt buộc mỗi nhóm phải có Mã người dùng riêng biệt để không vi phạm phân rã rời (Disjoint)
INSERT INTO `Tài khoản` (`Tên đăng nhập`, `Mật khẩu`, `Trạng thái tài khoản`, `Ngày tạo tài khoản`, `Đăng nhập gần nhất`) VALUES
('khach01', SHA2('123456', 256), 'Hoạt động', '2025-01-10 08:00:00', '2026-11-18 10:15:00'),
('khach02', SHA2('123456', 256), 'Hoạt động', '2025-02-12 09:30:00', '2026-11-17 14:20:00'),
('khach03', SHA2('123456', 256), 'Hoạt động', '2025-03-15 11:00:00', '2026-11-19 07:45:00'),
('khach04', SHA2('123456', 256), 'Hoạt động', '2025-04-20 15:10:00', '2026-11-15 20:00:00'),
('khach05', SHA2('123456', 256), 'Hoạt động', '2025-05-05 16:45:00', '2026-11-10 09:05:00'),
('admin01', SHA2('admin123', 256), 'Hoạt động', '2024-01-01 08:00:00', '2026-11-19 08:00:00'),
('admin02', SHA2('admin123', 256), 'Hoạt động', '2024-01-02 08:00:00', '2026-11-18 17:30:00'),
('admin03', SHA2('admin123', 256), 'Hoạt động', '2024-01-03 08:00:00', '2026-11-16 11:20:00'),
('admin04', SHA2('admin123', 256), 'Hoạt động', '2024-01-04 08:00:00', '2026-11-14 09:10:00'),
('admin05', SHA2('admin123', 256), 'Hoạt động', '2024-01-05 08:00:00', '2026-11-12 16:00:00'),
('nhanvien01', SHA2('nv123456', 256), 'Hoạt động', '2024-06-01 08:00:00', '2026-11-19 07:55:00'),
('nhanvien02', SHA2('nv123456', 256), 'Hoạt động', '2024-06-05 08:00:00', '2026-11-19 08:01:00'),
('nhanvien03', SHA2('nv123456', 256), 'Hoạt động', '2024-06-10 08:00:00', '2026-11-18 18:10:00'),
('nhanvien04', SHA2('nv123456', 256), 'Hoạt động', '2024-06-15 08:00:00', '2026-11-18 19:00:00'),
('nhanvien05', SHA2('nv123456', 256), 'Hoạt động', '2024-06-20 08:00:00', '2026-11-17 12:30:00');

-- 2. Người dùng (ID 1..5: Khách hàng | ID 6..10: Quản trị viên | ID 11..15: Nhân viên chi nhánh)
INSERT INTO `Người dùng` (`Họ`, `Tên đệm`, `Tên`, `Số điện thoại`, `Email`, `Trạng thái hồ sơ`, `Mã tài khoản`) VALUES
('Nguyễn', 'Văn', 'An', '0901000001', 'an.nguyen@gmail.com', 'Hoạt động', 1),
('Trần', 'Thị', 'Bình', '0901000002', 'binh.tran@gmail.com', 'Hoạt động', 2),
('Lê', 'Hoàng', 'Cường', '0901000003', 'cuong.le@gmail.com', 'Hoạt động', 3),
('Phạm', 'Minh', 'Dung', '0901000004', 'dung.pham@gmail.com', 'Hoạt động', 4),
('Hoàng', 'Gia', 'Em', '0901000005', 'em.hoang@gmail.com', 'Hoạt động', 5),
('Vũ', 'Đức', 'Phúc', '0911000001', 'admin1@ecommerce.vn', 'Hoạt động', 6),
('Đặng', 'Thu', 'Hà', '0911000002', 'admin2@ecommerce.vn', 'Hoạt động', 7),
('Bùi', 'Quốc', 'Huy', '0911000003', 'admin3@ecommerce.vn', 'Hoạt động', 8),
('Đỗ', 'Ngọc', 'Lan', '0911000004', 'admin4@ecommerce.vn', 'Hoạt động', 9),
('Hồ', 'Tấn', 'Lộc', '0911000005', 'admin5@ecommerce.vn', 'Hoạt động', 10),
('Ngô', 'Thanh', 'Mai', '0921000001', 'nv1@ecommerce.vn', 'Hoạt động', 11),
('Dương', 'Văn', 'Nam', '0921000002', 'nv2@ecommerce.vn', 'Hoạt động', 12),
('Lý', 'Thị', 'Oanh', '0921000003', 'nv3@ecommerce.vn', 'Hoạt động', 13),
('Võ', 'Hữu', 'Phát', '0921000004', 'nv4@ecommerce.vn', 'Hoạt động', 14),
('Trịnh', 'Khánh', 'Quỳnh', '0921000005', 'nv5@ecommerce.vn', 'Hoạt động', 15);

-- 3. Hạng hội viên (5 dòng)
INSERT INTO `Hạng hội viên` (`Tên hạng`, `Mức chi tiêu tối thiểu`, `Tỷ lệ tích điểm`) VALUES
('Thành viên Mới', 0.00, 1.00),
('Hạng Bạc', 5000000.00, 1.50),
('Hạng Vàng', 20000000.00, 2.00),
('Hạng Bạch Kim', 50000000.00, 3.00),
('Hạng Kim Cương', 100000000.00, 5.00);

-- 4. Khách hàng (5 dòng - Mã người dùng 1..5)
INSERT INTO `Khách hàng` (`Mã người dùng`, `Điểm khả dụng`, `Tổng chi tiêu tích lũy`, `Mã hạng`) VALUES
(1, 350, 35000000.00, 3),
(2, 120, 12000000.00, 2),
(3, 550, 55000000.00, 4),
(4, 50, 2500000.00, 1),
(5, 1200, 110000000.00, 5);

-- 5. Quản trị viên (5 dòng - Mã người dùng 6..10)
INSERT INTO `Quản trị viên` (`Mã người dùng`) VALUES
(6), (7), (8), (9), (10);

-- 6. Chi nhánh (5 dòng)
INSERT INTO `Chi nhánh` (`Tên chi nhánh`, `Số nhà + đường`, `Phường/Xã`, `Quận/Huyện`, `Tỉnh/TP`, `SDT hotline`, `Trạng thái hoạt động`) VALUES
('Chi nhánh Quận 1', '123 Lê Lợi', 'Phường Bến Nghé', 'Quận 1', 'TP. Hồ Chí Minh', '0283822111', 'Đang hoạt động'),
('Chi nhánh Thủ Đức', '268 Lý Thường Kiệt', 'Phường Linh Trung', 'TP. Thủ Đức', 'TP. Hồ Chí Minh', '0283822222', 'Đang hoạt động'),
('Chi nhánh Cầu Giấy', '45 Xuân Thủy', 'Phường Dịch Vọng Hậu', 'Quận Cầu Giấy', 'Hà Nội', '0243766333', 'Đang hoạt động'),
('Chi nhánh Hải Châu', '88 Nguyễn Văn Linh', 'Phường Nam Dương', 'Quận Hải Châu', 'Đà Nẵng', '0236388444', 'Đang hoạt động'),
('Chi nhánh Ninh Kiều', '12 Hòa Bình', 'Phường An Cư', 'Quận Ninh Kiều', 'Cần Thơ', '0292381555', 'Đang hoạt động');

-- 7. Nhân viên chi nhánh (5 dòng - Mã người dùng 11..15)
INSERT INTO `Nhân viên chi nhánh` (`Mã người dùng`, `Mã chi nhánh`) VALUES
(11, 1),
(12, 2),
(13, 3),
(14, 4),
(15, 5);

-- 8. Địa chỉ nhận hàng (5 dòng)
INSERT INTO `Địa chỉ nhận hàng` (`Mã khách hàng`, `Tên người nhận`, `SDT người nhận`, `Số nhà + đường`, `Phường/Xã`, `Quận/Huyện`, `Tỉnh/TP`, `Trạng thái mặc định`) VALUES
(1, 'Nguyễn Văn An', '0901000001', '10 Nguyễn Huệ', 'Phường Bến Nghé', 'Quận 1', 'TP. Hồ Chí Minh', TRUE),
(2, 'Trần Thị Bình', '0901000002', '25 Võ Văn Ngân', 'Phường Linh Chiểu', 'TP. Thủ Đức', 'TP. Hồ Chí Minh', TRUE),
(3, 'Lê Hoàng Cường', '0901000003', '102 Trần Duy Hưng', 'Phường Trung Hòa', 'Quận Cầu Giấy', 'Hà Nội', TRUE),
(4, 'Phạm Minh Dung', '0901000004', '55 Bạch Đằng', 'Phường Thạch Thang', 'Quận Hải Châu', 'Đà Nẵng', TRUE),
(5, 'Hoàng Gia Em', '0901000005', '77 Đường 30/4', 'Phường Xuân Khánh', 'Quận Ninh Kiều', 'Cần Thơ', TRUE);

-- 9. Giao dịch điểm (5 dòng)
INSERT INTO `Giao dịch điểm` (`Mã khách hàng`, `Số điểm thay đổi`, `Thời điểm giao dịch`, `Nội dung`, `Loại giao dịch`, `Số dư sau giao dịch`) VALUES
(1, 350, '2026-10-05 14:00:00', 'Tích điểm đơn hàng #1', 'Cộng điểm', 350),
(2, 120, '2026-10-12 16:30:00', 'Tích điểm đơn hàng #2', 'Cộng điểm', 120),
(3, 600, '2026-10-20 09:15:00', 'Tích điểm đơn hàng #3', 'Cộng điểm', 600),
(3, -50, '2026-11-01 10:00:00', 'Đổi điểm lấy mã giảm giá', 'Trừ điểm', 550),
(5, 1200, '2026-11-10 18:45:00', 'Tích điểm đơn hàng #5', 'Cộng điểm', 1200);

-- 10. Danh mục (5 dòng - có quan hệ đệ quy Cha - Con)
INSERT INTO `Danh mục` (`Mã danh mục cha`, `Tên danh mục`, `Mô tả`, `Trạng thái`) VALUES
(NULL, 'Thiết bị điện tử', 'Các sản phẩm công nghệ, điện tử tiêu dùng', 'Hiển thị'),
(1, 'Điện thoại thông minh', 'Smartphone chính hãng các hãng', 'Hiển thị'),
(1, 'Laptop & Máy tính', 'Laptop văn phòng, gaming, đồ họa', 'Hiển thị'),
(NULL, 'Thời trang & Phụ kiện', 'Quần áo, giày dép, phụ kiện thời trang', 'Hiển thị'),
(4, 'Giày Sneaker', 'Giày thể thao năng động chính hãng', 'Hiển thị');

-- 11. Thương hiệu (5 dòng)
INSERT INTO `Thương hiệu` (`Tên thương hiệu`, `Mô tả`, `Trạng thái`) VALUES
('Apple', 'Thương hiệu công nghệ hàng đầu từ Mỹ', 'Hoạt động'),
('Samsung', 'Tập đoàn điện tử đa quốc gia Hàn Quốc', 'Hoạt động'),
('Sony', 'Thương hiệu điện tử & âm thanh Nhật Bản', 'Hoạt động'),
('Nike', 'Thương hiệu thời trang thể thao toàn cầu', 'Hoạt động'),
('Adidas', 'Thương hiệu đồ thể thao nổi tiếng từ Đức', 'Hoạt động');

-- 12. Nhà cung cấp (5 dòng)
INSERT INTO `Nhà cung cấp` (`Tên nhà cung cấp`, `SDT`, `Địa chỉ`, `Trạng thái hợp tác`) VALUES
('Công ty CP Thế Giới Số (DGW)', '0283929001', 'Số 195 Đường 3/2, Quận 10, TP.HCM', 'Đang hợp tác'),
('Công ty TNHH Phân phối Synnex FPT', '0247300002', 'Số 17 Duy Tân, Cầu Giấy, Hà Nội', 'Đang hợp tác'),
('Công ty TNHH Sony Electronics VN', '0283822003', 'Tầng 6, Tòa nhà President Place, Quận 1, TP.HCM', 'Đang hợp tác'),
('Công ty TNHH Nike Việt Nam', '0283520004', 'Tầng 12, Tòa nhà Metropolitan, Quận 1, TP.HCM', 'Đang hợp tác'),
('Công ty TNHH Adidas Việt Nam', '0283915005', 'Tầng 8, Tòa nhà Deutsches Haus, Quận 1, TP.HCM', 'Đang hợp tác');

-- 13. Sản phẩm (5 dòng)
INSERT INTO `Sản phẩm` (`Tên sản phẩm`, `Mô tả`, `Giá cơ sở`, `Trạng thái kinh doanh`, `Điểm đánh giá TB`) VALUES
('iPhone 16 Pro Max', 'Chip A18 Pro, màn hình Super Retina XDR 6.9 inch', 34990000.00, 'Đang kinh doanh', 5.00),
('Samsung Galaxy S24 Ultra', 'Trang bị Galaxy AI, bút S-Pen tích hợp, camera 200MP', 29990000.00, 'Đang kinh doanh', 4.80),
('MacBook Air M3 13 inch', 'Chip Apple M3 siêu mỏng nhẹ, pin lên đến 18 giờ', 27990000.00, 'Đang kinh doanh', 4.90),
('Tai nghe Sony WH-1000XM5', 'Tai nghe chụp tai chống ồn chủ động hàng đầu', 7990000.00, 'Đang kinh doanh', 4.75),
('Giày Nike Air Force 1 07', 'Giày sneaker cổ điển màu trắng biểu tượng', 2900000.00, 'Đang kinh doanh', 4.85);

-- 14. Phân loại sản phẩm (5 dòng)
INSERT INTO `Phân loại sản phẩm` (`Mã sản phẩm`, `Mã danh mục`) VALUES
(1, 2),
(2, 2),
(3, 3),
(4, 1),
(5, 5);

-- 15. Gắn thương hiệu (5 dòng)
INSERT INTO `Gắn thương hiệu` (`Mã thương hiệu`, `Mã sản phẩm`) VALUES
(1, 1),
(2, 2),
(1, 3),
(3, 4),
(4, 5);

-- 16. Cung cấp (5 dòng)
INSERT INTO `Cung cấp` (`Mã nhà cung cấp`, `Mã sản phẩm`) VALUES
(1, 1),
(2, 2),
(1, 3),
(3, 4),
(4, 5);

-- 17. Hình ảnh sản phẩm (5 dòng)
INSERT INTO `Hình ảnh sản phẩm` (`Mã sản phẩm`, `Hình ảnh sản phẩm`) VALUES
(1, 'https://cdn.ecommerce.vn/products/iphone-16-pro-max-titan.jpg'),
(2, 'https://cdn.ecommerce.vn/products/galaxy-s24-ultra-gray.jpg'),
(3, 'https://cdn.ecommerce.vn/products/macbook-air-m3-midnight.jpg'),
(4, 'https://cdn.ecommerce.vn/products/sony-wh1000xm5-black.jpg'),
(5, 'https://cdn.ecommerce.vn/products/nike-af1-white.jpg');

-- 18. Biến thể sản phẩm (5 dòng)
INSERT INTO `Biến thể sản phẩm` (`Mã sản phẩm`, `Màu sắc`, `Kết quả xử lý`, `Dung lượng`, `Kích thước`, `Giá bán`, `Trạng thái khả dụng`) VALUES
(1, 'Titan Sa Mạc', 'Chip A18 Pro', '256GB', NULL, 34990000.00, 'Còn hàng'),
(2, 'Xám Titan', 'Snapdragon 8 Gen 3', '512GB', NULL, 31990000.00, 'Còn hàng'),
(3, 'Xanh Đêm', 'Apple M3 8-Core', '16GB/512GB', NULL, 32990000.00, 'Còn hàng'),
(4, 'Đen Nhám', 'Chip V1 + QN1', 'Standard', NULL, 7990000.00, 'Còn hàng'),
(5, 'Trắng Tinh', 'Da tổng hợp cao cấp', NULL, '42', 2900000.00, 'Còn hàng');

-- 19. Tồn kho (5 dòng)
INSERT INTO `Tồn kho` (`Mã chi nhánh`, `Mã biến thể`, `Số lượng tồn`, `Cập nhật gần nhất`) VALUES
(1, 1, 50, '2026-11-18 09:00:00'),
(2, 2, 35, '2026-11-18 09:30:00'),
(3, 3, 25, '2026-11-18 10:00:00'),
(4, 4, 40, '2026-11-18 10:30:00'),
(5, 5, 60, '2026-11-18 11:00:00');

-- 20. Giỏ hàng (5 dòng - 1:1 với 5 Khách hàng)
INSERT INTO `Giỏ hàng` (`Mã khách hàng`, `Ngày tạo`, `Cập nhật gần nhất`, `Trạng thái`, `Tổng tiền tạm tính`) VALUES
(1, '2026-11-01 08:00:00', '2026-11-18 10:20:00', 'Đang hoạt động', 34990000.00),
(2, '2026-11-02 09:00:00', '2026-11-17 14:25:00', 'Đang hoạt động', 31990000.00),
(3, '2026-11-03 10:00:00', '2026-11-19 07:50:00', 'Đang hoạt động', 32990000.00),
(4, '2026-11-04 11:00:00', '2026-11-15 20:05:00', 'Đang hoạt động', 7990000.00),
(5, '2026-11-05 12:00:00', '2026-11-10 09:10:00', 'Đang hoạt động', 5800000.00);

-- 21. Chi tiết giỏ hàng (5 dòng)
INSERT INTO `Chi tiết giỏ hàng` (`Mã giỏ hàng`, `Mã biến thể`, `Số lượng`, `Trạng thái lựa chọn`) VALUES
(1, 1, 1, TRUE),
(2, 2, 1, TRUE),
(3, 3, 1, TRUE),
(4, 4, 1, TRUE),
(5, 5, 2, TRUE);

-- 22. Đơn hàng (5 dòng)
INSERT INTO `Đơn hàng` (`Mã khách hàng`, `Mã chi nhánh`, `Ngày đặt hàng`, `Trạng thái hiện tại`, `Phương thức thanh toán`, `Phí vận chuyển`, `Tổng tiền hàng`, `Số tiền giảm`, `Tổng thanh toán`, `Tên người nhận`, `SDT`, `Số nhà + đường`, `Phường/Xã`, `Quận/Huyện`, `Tỉnh/TP`) VALUES
(1, 1, '2026-10-01 10:00:00', 'Hoàn thành', 'Chuyển khoản ngân hàng', 0.00, 34990000.00, 1000000.00, 33990000.00, 'Nguyễn Văn An', '0901000001', '10 Nguyễn Huệ', 'Phường Bến Nghé', 'Quận 1', 'TP. Hồ Chí Minh'),
(2, 2, '2026-10-10 14:30:00', 'Hoàn thành', 'Ví điện tử MoMo', 30000.00, 31990000.00, 30000.00, 31990000.00, 'Trần Thị Bình', '0901000002', '25 Võ Văn Ngân', 'Phường Linh Chiểu', 'TP. Thủ Đức', 'TP. Hồ Chí Minh'),
(3, 3, '2026-10-18 09:00:00', 'Hoàn thành', 'Thẻ tín dụng', 0.00, 32990000.00, 1500000.00, 31490000.00, 'Lê Hoàng Cường', '0901000003', '102 Trần Duy Hưng', 'Phường Trung Hòa', 'Quận Cầu Giấy', 'Hà Nội'),
(4, 4, '2026-11-15 16:00:00', 'Đang giao hàng', 'Thanh toán khi nhận hàng (COD)', 25000.00, 7990000.00, 200000.00, 7815000.00, 'Phạm Minh Dung', '0901000004', '55 Bạch Đằng', 'Phường Thạch Thang', 'Quận Hải Châu', 'Đà Nẵng'),
(5, 5, '2026-11-18 11:20:00', 'Chờ xử lý', 'Chuyển khoản ngân hàng', 0.00, 5800000.00, 300000.00, 5500000.00, 'Hoàng Gia Em', '0901000005', '77 Đường 30/4', 'Phường Xuân Khánh', 'Quận Ninh Kiều', 'Cần Thơ');

-- 23. Chi tiết đơn hàng (5 dòng)
INSERT INTO `Chi tiết đơn hàng` (`Mã đơn hàng`, `Số thứ tự dòng`, `Mã biến thể`, `Số lượng`, `Đơn giá lúc mua`, `Số tiền giảm`, `Thành tiền`) VALUES
(1, 1, 1, 1, 34990000.00, 0.00, 34990000.00),
(2, 1, 2, 1, 31990000.00, 0.00, 31990000.00),
(3, 1, 3, 1, 32990000.00, 0.00, 32990000.00),
(4, 1, 4, 1, 7990000.00, 0.00, 7990000.00),
(5, 1, 5, 2, 2900000.00, 0.00, 5800000.00);

-- 24. Lịch sử trạng thái đơn hàng (5 dòng)
INSERT INTO `Lịch sử trạng thái đơn hàng` (`Mã đơn hàng`, `Thời điểm cập nhật`, `Trạng thái`, `Ghi chú`, `Mã nhân viên`) VALUES
(1, '2026-10-05 13:55:00', 'Hoàn thành', 'Khách hàng đã nhận hàng và thanh toán đủ', 11),
(2, '2026-10-12 16:25:00', 'Hoàn thành', 'Giao hàng thành công đúng hẹn', 12),
(3, '2026-10-20 09:10:00', 'Hoàn thành', 'Đã bàn giao sản phẩm nguyên seal', 13),
(4, '2026-11-16 08:30:00', 'Đang giao hàng', 'Đơn vị vận chuyển đã lấy hàng từ kho Đà Nẵng', 14),
(5, '2026-11-18 11:20:00', 'Chờ xử lý', 'Đơn hàng mới tạo trên hệ thống', 15);

-- 25. Đánh giá (5 dòng - tham chiếu đúng cặp (Mã đơn hàng, Số thứ tự dòng))
INSERT INTO `Đánh giá` (`Mã đơn hàng`, `Số thứ tự dòng`, `Số sao (1-5)`, `Nội dung nhận xét`, `Thời điểm đánh giá`, `Trạng thái hiển thị`) VALUES
(1, 1, 5, 'Máy màu Titan Sa Mạc cực kỳ sang trọng, giao hàng siêu nhanh trong 2h!', '2026-10-06 09:00:00', 'Hiển thị'),
(2, 1, 5, 'Màn hình chống chói xuất sắc, bút S-Pen ghi chú rất mượt.', '2026-10-13 10:15:00', 'Hiển thị'),
(3, 1, 5, 'MacBook Air M3 16GB RAM chạy đa nhiệm cực mượt, pin trâu cả ngày.', '2026-10-21 14:40:00', 'Hiển thị'),
(4, 1, 4, 'Chống ồn tốt nhưng đeo lâu hơi nóng tai một chút.', '2026-11-17 19:00:00', 'Hiển thị'),
(5, 1, 5, 'Giày form chuẩn, da mềm, đóng gói hộp đôi rất cẩn thận.', '2026-11-19 08:00:00', 'Hiển thị');

-- 26. Hình ảnh đánh giá (5 dòng)
INSERT INTO `Hình ảnh đánh giá` (`Mã đánh giá`, `Hình ảnh đánh giá`) VALUES
(1, 'https://cdn.ecommerce.vn/reviews/rev1_iphone16.jpg'),
(2, 'https://cdn.ecommerce.vn/reviews/rev2_s24ultra.jpg'),
(3, 'https://cdn.ecommerce.vn/reviews/rev3_macbookm3.jpg'),
(4, 'https://cdn.ecommerce.vn/reviews/rev4_sonyxm5.jpg'),
(5, 'https://cdn.ecommerce.vn/reviews/rev5_nikeaf1.jpg');

-- 27. Yêu cầu bảo hành đổi trả (5 dòng)
INSERT INTO `Yêu cầu bảo hành đổi trả` (`Mã đơn hàng`, `Số thứ tự dòng`, `Mã chi nhánh`, `Loại yêu cầu`, `Lý do`, `Xử lý mong muốn`, `Ngày tạo`, `Trạng thái xử lý`, `Lý do từ chối`) VALUES
(1, 1, 1, 'Bảo hành', 'Cổng sạc Type-C thỉnh thoảng chập chờn', 'Kiểm tra và bảo hành chính hãng', '2026-10-15 10:00:00', 'Đã hoàn tất', NULL),
(2, 1, 2, 'Đổi hàng', 'Khách muốn đổi sang phiên bản màu Đen Titan', 'Đổi sang màu khác nguyên seal', '2026-10-14 11:30:00', 'Từ chối', 'Sản phẩm đã bóc seal và kích hoạt bảo hành điện tử'),
(3, 1, 3, 'Bảo hành', 'Phím Space hơi cứng khi gõ nhanh', 'Vệ sinh và cân chỉnh bàn phím', '2026-10-25 15:00:00', 'Đang xử lý', NULL),
(4, 1, 4, 'Đổi hàng', 'Hộp sản phẩm bị móp nhẹ góc phải khi vận chuyển', 'Đổi hộp nguyên vẹn mới', '2026-11-17 09:20:00', 'Chờ tiếp nhận', NULL),
(5, 1, 5, 'Đổi hàng', 'Đặt nhầm size 42, muốn đổi sang size 41', 'Đổi sang size 41 cùng mẫu', '2026-11-19 08:10:00', 'Chờ tiếp nhận', NULL);

-- 28. Hình ảnh minh chứng (5 dòng)
INSERT INTO `Hình ảnh minh chứng` (`Mã yêu cầu`, `Hình ảnh minh chứng`) VALUES
(1, 'https://cdn.ecommerce.vn/warranty/yc1_typec_port.jpg'),
(2, 'https://cdn.ecommerce.vn/warranty/yc2_box_seal.jpg'),
(3, 'https://cdn.ecommerce.vn/warranty/yc3_keyboard.jpg'),
(4, 'https://cdn.ecommerce.vn/warranty/yc4_dented_box.jpg'),
(5, 'https://cdn.ecommerce.vn/warranty/yc5_shoe_size.jpg');

-- 29. Voucher (5 dòng)
INSERT INTO `Voucher` (`Loại giảm giá`, `Giá trị giảm`, `Mức giảm tối đa`, `Đơn tối thiểu`, `Tổng lượt sử dụng`, `Ngày bắt đầu`, `Ngày kết thúc`, `Trạng thái`) VALUES
('Số tiền cố định', 1000000.00, 1000000.00, 20000000.00, 100, '2026-01-01 00:00:00', '2026-12-31 23:59:59', 'Đang áp dụng'),
('Miễn phí vận chuyển', 30000.00, 30000.00, 300000.00, 500, '2026-01-01 00:00:00', '2026-12-31 23:59:59', 'Đang áp dụng'),
('Phần trăm', 5.00, 1500000.00, 15000000.00, 200, '2026-06-01 00:00:00', '2026-12-31 23:59:59', 'Đang áp dụng'),
('Số tiền cố định', 200000.00, 200000.00, 5000000.00, 300, '2026-09-01 00:00:00', '2026-12-31 23:59:59', 'Đang áp dụng'),
('Phần trăm', 10.00, 300000.00, 2000000.00, 150, '2026-10-01 00:00:00', '2026-12-31 23:59:59', 'Đang áp dụng');

-- 30. Áp dụng voucher (5 dòng)
INSERT INTO `Áp dụng voucher` (`Mã đơn hàng`, `Mã voucher`, `Số tiền giảm thực tế`) VALUES
(1, 1, 1000000.00),
(2, 2, 30000.00),
(3, 3, 1500000.00),
(4, 4, 200000.00),
(5, 5, 300000.00);
