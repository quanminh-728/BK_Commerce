/* ============================================================
   SP2 - Thống kê doanh thu theo chi nhánh (MySQL)
   Chạy SAU Part1_CSDL.sql (cần DB ThuongMaiDienTu + dữ liệu mẫu).
   Doanh thu = tổng `Tổng thanh toán` của các đơn ở trạng thái 'Hoàn thành'.
   ============================================================ */
USE ThuongMaiDienTu;

DROP PROCEDURE IF EXISTS sp_ThongKeDoanhThu;

DELIMITER $$

CREATE PROCEDURE sp_ThongKeDoanhThu(
    IN p_TuNgay            DATE,           -- bắt buộc
    IN p_DenNgay           DATE,           -- bắt buộc
    IN p_MaChiNhanh        INT,            -- NULL = tất cả chi nhánh
    IN p_DoanhThuToiThieu  DECIMAL(15,2)   -- điều kiện HAVING, NULL = 0
)
BEGIN
    IF p_TuNgay IS NULL OR p_DenNgay IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Lỗi: Phải nhập đủ Từ ngày và Đến ngày để thống kê!';
    END IF;

    IF p_TuNgay > p_DenNgay THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Lỗi: Từ ngày không được lớn hơn Đến ngày!';
    END IF;

    IF p_DoanhThuToiThieu IS NOT NULL AND p_DoanhThuToiThieu < 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Lỗi: Doanh thu tối thiểu không được âm!';
    END IF;

    IF p_MaChiNhanh IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM `Chi nhánh` WHERE `Mã chi nhánh` = p_MaChiNhanh) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Lỗi: Mã chi nhánh không tồn tại!';
    END IF;

    SELECT
        cn.`Mã chi nhánh`                 AS MaChiNhanh,
        cn.`Tên chi nhánh`                AS TenChiNhanh,
        COUNT(dh.`Mã đơn hàng`)           AS SoDon,
        IFNULL(SUM(sl.SoLuong), 0)        AS SoLuongBan,
        SUM(dh.`Tổng tiền hàng`)          AS TongTienHang,
        SUM(dh.`Số tiền giảm`)            AS TongGiam,
        SUM(dh.`Phí vận chuyển`)          AS TongPhiVanChuyen,
        SUM(dh.`Tổng thanh toán`)         AS DoanhThu,
        AVG(dh.`Tổng thanh toán`)         AS GiaTriTrungBinh
    FROM `Đơn hàng` AS dh
    INNER JOIN `Chi nhánh` AS cn
        ON cn.`Mã chi nhánh` = dh.`Mã chi nhánh`
    LEFT JOIN (
        SELECT `Mã đơn hàng`, SUM(`Số lượng`) AS SoLuong
        FROM `Chi tiết đơn hàng`
        GROUP BY `Mã đơn hàng`
    ) AS sl ON sl.`Mã đơn hàng` = dh.`Mã đơn hàng`
    WHERE dh.`Trạng thái hiện tại` = 'Hoàn thành'
      AND dh.`Ngày đặt hàng` >= p_TuNgay
      AND dh.`Ngày đặt hàng` <  DATE_ADD(p_DenNgay, INTERVAL 1 DAY)
      AND (p_MaChiNhanh IS NULL OR dh.`Mã chi nhánh` = p_MaChiNhanh)
    GROUP BY cn.`Mã chi nhánh`, cn.`Tên chi nhánh`
    HAVING SUM(dh.`Tổng thanh toán`) >= IFNULL(p_DoanhThuToiThieu, 0)
    ORDER BY DoanhThu DESC, cn.`Mã chi nhánh` ASC;
END $$

DELIMITER ;

/* ---------- Câu lệnh minh họa khi báo cáo (dữ liệu mẫu của Part1) ---------- */
-- 1) Tất cả chi nhánh, T10-T11/2026  -> 3 chi nhánh có đơn 'Hoàn thành'
CALL sp_ThongKeDoanhThu('2026-10-01', '2026-11-30', NULL, 0);
-- 2) Có HAVING: chỉ giữ chi nhánh doanh thu >= 32 triệu -> chỉ còn chi nhánh 1
CALL sp_ThongKeDoanhThu('2026-10-01', '2026-11-30', NULL, 32000000);
-- 3) Một chi nhánh cụ thể
CALL sp_ThongKeDoanhThu('2026-10-01', '2026-11-30', 2, 0);
-- 4) Khoảng ngày không có đơn hoàn thành -> 0 dòng
CALL sp_ThongKeDoanhThu('2026-11-01', '2026-11-30', NULL, 0);
-- 5) Các trường hợp báo lỗi (chạy từng dòng)
-- CALL sp_ThongKeDoanhThu('2026-12-01', '2026-10-01', NULL, 0);   -- Từ ngày > Đến ngày
-- CALL sp_ThongKeDoanhThu('2026-10-01', '2026-11-30', 999, 0);    -- chi nhánh không tồn tại
-- CALL sp_ThongKeDoanhThu('2026-10-01', '2026-11-30', NULL, -5);  -- doanh thu tối thiểu âm
