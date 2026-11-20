DROP PROCEDURE IF EXISTS sp_ThemSanPham;
DROP PROCEDURE IF EXISTS sp_CapNhatSanPham;
DROP PROCEDURE IF EXISTS sp_XoaSanPham;
DROP PROCEDURE IF EXISTS sp_Demo_CRUD_SanPham;

DELIMITER //

-- ----------------------------------------------------------------------------
-- 3.1. Thủ tục INSERT: sp_ThemSanPham
-- ----------------------------------------------------------------------------
CREATE PROCEDURE sp_ThemSanPham(
    IN p_TenSanPham VARCHAR(200),
    IN p_MoTa TEXT,
    IN p_GiaCoSo DECIMAL(15, 2),
    IN p_TrangThaiKinhDoanh VARCHAR(30)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    -- 1. Kiểm tra tên sản phẩm không được để trống
    IF p_TenSanPham IS NULL OR TRIM(p_TenSanPham) = '' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Lỗi: Tên sản phẩm không được để trống!';
    END IF;

    -- 2. Kiểm tra giá cơ sở không được âm
    IF p_GiaCoSo IS NULL OR p_GiaCoSo < 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Lỗi: Giá cơ sở của sản phẩm phải lớn hơn hoặc bằng 0!';
    END IF;

    -- 3. Kiểm tra trạng thái kinh doanh hợp lệ
    IF p_TrangThaiKinhDoanh IS NULL OR p_TrangThaiKinhDoanh NOT IN ('Đang kinh doanh', 'Ngừng kinh doanh', 'Tạm ẩn') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Lỗi: Trạng thái kinh doanh không hợp lệ (Chỉ chấp nhận: Đang kinh doanh, Ngừng kinh doanh, Tạm ẩn)!';
    END IF;

    -- 4. Thêm dữ liệu mới
    START TRANSACTION;
        INSERT INTO `Sản phẩm` (`Tên sản phẩm`, `Mô tả`, `Giá cơ sở`, `Trạng thái kinh doanh`)
        VALUES (TRIM(p_TenSanPham), p_MoTa, p_GiaCoSo, p_TrangThaiKinhDoanh);
        
        SELECT CONCAT('Thành công: Đã thêm sản phẩm mới với Mã sản phẩm = ', LAST_INSERT_ID()) AS ThongBao;
    COMMIT;
END //

-- ----------------------------------------------------------------------------
-- 3.2. Thủ tục UPDATE: sp_CapNhatSanPham
-- ----------------------------------------------------------------------------
CREATE PROCEDURE sp_CapNhatSanPham(
    IN p_MaSanPham INT,
    IN p_TenSanPham VARCHAR(200),
    IN p_MoTa TEXT,
    IN p_GiaCoSo DECIMAL(15, 2),
    IN p_TrangThaiKinhDoanh VARCHAR(30)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    -- 1. Kiểm tra sản phẩm có tồn tại không
    IF p_MaSanPham IS NULL OR NOT EXISTS (SELECT 1 FROM `Sản phẩm` WHERE `Mã sản phẩm` = p_MaSanPham) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Lỗi: Mã sản phẩm cần cập nhật không tồn tại!';
    END IF;

    -- 2. Kiểm tra tên sản phẩm không để trống
    IF p_TenSanPham IS NULL OR TRIM(p_TenSanPham) = '' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Lỗi: Tên sản phẩm không được để trống!';
    END IF;

    -- 3. Kiểm tra giá cơ sở hợp lệ (>= 0)
    IF p_GiaCoSo IS NULL OR p_GiaCoSo < 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Lỗi: Giá cơ sở của sản phẩm phải lớn hơn hoặc bằng 0!';
    END IF;

    -- 4. Kiểm tra trạng thái kinh doanh hợp lệ
    IF p_TrangThaiKinhDoanh IS NULL OR p_TrangThaiKinhDoanh NOT IN ('Đang kinh doanh', 'Ngừng kinh doanh', 'Tạm ẩn') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Lỗi: Trạng thái kinh doanh không hợp lệ!';
    END IF;

    -- 5. Thực hiện cập nhật
    START TRANSACTION;
        UPDATE `Sản phẩm`
        SET `Tên sản phẩm` = TRIM(p_TenSanPham),
            `Mô tả` = p_MoTa,
            `Giá cơ sở` = p_GiaCoSo,
            `Trạng thái kinh doanh` = p_TrangThaiKinhDoanh
        WHERE `Mã sản phẩm` = p_MaSanPham;

        SELECT CONCAT('Thành công: Đã cập nhật thông tin sản phẩm có mã [', p_MaSanPham, '].') AS ThongBao;
    COMMIT;
END //

-- ----------------------------------------------------------------------------
-- 3.3. Thủ tục DELETE: sp_XoaSanPham
-- ----------------------------------------------------------------------------
CREATE PROCEDURE sp_XoaSanPham(
    IN p_MaSanPham INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    -- 1. Kiểm tra mã sản phẩm có tồn tại không
    IF p_MaSanPham IS NULL OR NOT EXISTS (SELECT 1 FROM `Sản phẩm` WHERE `Mã sản phẩm` = p_MaSanPham) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Lỗi: Mã sản phẩm không tồn tại!';
    END IF;

    -- 2. Kiểm tra sản phẩm đã phát sinh Biến thể chưa (liên quan đến Tồn kho, Giỏ hàng, Đơn hàng)
    IF EXISTS (SELECT 1 FROM `Biến thể sản phẩm` WHERE `Mã sản phẩm` = p_MaSanPham) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Lỗi: Không thể xóa sản phẩm này vì đã có dữ liệu trong bảng Biến thể sản phẩm!';
    END IF;

    -- 3. Kiểm tra sản phẩm có đang liên kết với Nhà cung cấp không
    IF EXISTS (SELECT 1 FROM `Cung cấp` WHERE `Mã sản phẩm` = p_MaSanPham) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Lỗi: Không thể xóa sản phẩm này vì đang có dữ liệu liên kết với Nhà cung cấp!';
    END IF;

    -- 4. Thực hiện xóa các bảng phụ trợ trực tiếp và xóa sản phẩm chính
    START TRANSACTION;
        DELETE FROM `Hình ảnh sản phẩm` WHERE `Mã sản phẩm` = p_MaSanPham;
        DELETE FROM `Phân loại sản phẩm` WHERE `Mã sản phẩm` = p_MaSanPham;
        DELETE FROM `Gắn thương hiệu` WHERE `Mã sản phẩm` = p_MaSanPham;

        DELETE FROM `Sản phẩm` WHERE `Mã sản phẩm` = p_MaSanPham;

        SELECT CONCAT('Thành công: Đã xóa sản phẩm có mã [', p_MaSanPham, '] khỏi hệ thống.') AS ThongBao;
    COMMIT;
END //

-- ----------------------------------------------------------------------------
-- 3.4. Thủ tục DEMO KIỂM THỬ TỰ ĐỘNG CẢ 3 THỦ TỤC (ĐÚNG & SAI)
-- ----------------------------------------------------------------------------
CREATE PROCEDURE sp_Demo_CRUD_SanPham()
BEGIN
    DECLARE v_TempID INT;
    DECLARE v_ErrorMessage TEXT;

    -- Bắt lỗi nghiệp vụ SQLSTATE '45000' và hiển thị thông báo chặn lỗi thành công
    DECLARE CONTINUE HANDLER FOR SQLSTATE '45000'
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_ErrorMessage = MESSAGE_TEXT;
        SELECT CONCAT('-> THÀNH CÔNG CHẶN LỖI: ', v_ErrorMessage) AS KetQuaKiemThu;
    END;

    -- ================= TEST 1: INSERT =================
    SELECT '=== CASE 1.1: [ĐÚNG] Thêm sản phẩm hợp lệ ===' AS TestCase;
    CALL sp_ThemSanPham('iPad Pro M4 11 inch', 'Màn hình Ultra Retina XDR Tandem OLED', 28990000, 'Đang kinh doanh');
    SET v_TempID = LAST_INSERT_ID();

    SELECT '=== CASE 1.2: [SAI] Thêm sản phẩm để trống tên ===' AS TestCase;
    CALL sp_ThemSanPham('   ', 'Mô tả lỗi', 1000000, 'Đang kinh doanh');

    SELECT '=== CASE 1.3: [SAI] Thêm sản phẩm giá âm ===' AS TestCase;
    CALL sp_ThemSanPham('Chuột Magic Mouse', 'Mô tả lỗi', -500000, 'Đang kinh doanh');

    -- ================= TEST 2: UPDATE =================
    SELECT '=== CASE 2.1: [ĐÚNG] Cập nhật sản phẩm vừa tạo ===' AS TestCase;
    CALL sp_CapNhatSanPham(v_TempID, 'iPad Pro M4 11 inch (Wi-Fi 256GB)', 'Đã cập nhật cấu hình chi tiết', 27990000, 'Đang kinh doanh');

    SELECT '=== CASE 2.2: [SAI] Cập nhật sản phẩm không tồn tại (ID = 99999) ===' AS TestCase;
    CALL sp_CapNhatSanPham(99999, 'Sản phẩm ảo', 'Test', 100000, 'Đang kinh doanh');

    SELECT '=== CASE 2.3: [SAI] Cập nhật giá bị âm ===' AS TestCase;
    CALL sp_CapNhatSanPham(v_TempID, 'iPad Pro M4', 'Test', -1000, 'Đang kinh doanh');

    -- ================= TEST 3: DELETE =================
    SELECT '=== CASE 3.1: [SAI] Xóa sản phẩm đang có biến thể (Mã = 1) ===' AS TestCase;
    CALL sp_XoaSanPham(1);

    SELECT '=== CASE 3.2: [SAI] Xóa sản phẩm không tồn tại (ID = 99999) ===' AS TestCase;
    CALL sp_XoaSanPham(99999);

    SELECT '=== CASE 3.3: [ĐÚNG] Xóa sản phẩm chưa phát sinh biến thể ===' AS TestCase;
    CALL sp_XoaSanPham(v_TempID);
END //

DELIMITER ;

-- Thực thi kiểm thử toàn bộ:
CALL sp_Demo_CRUD_SanPham();