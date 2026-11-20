USE ThuongMaiDienTu;
SET NAMES utf8mb4;

UPDATE `Biến thể sản phẩm`
SET `Kết quả xử lý` = 'Đã duyệt', `Trạng thái khả dụng` = 'Khả dụng'
WHERE `Mã biến thể` > 0;

ALTER TABLE `Biến thể sản phẩm`
    ALTER COLUMN `Kết quả xử lý` SET DEFAULT 'Chờ duyệt',
    ALTER COLUMN `Trạng thái khả dụng` SET DEFAULT 'Không khả dụng';

ALTER TABLE `Biến thể sản phẩm`
    ADD CONSTRAINT chk_bienthe_ketqua
        CHECK (`Kết quả xử lý` IN ('Chờ duyệt', 'Đã duyệt', 'Cần chỉnh sửa')),
    ADD CONSTRAINT chk_bienthe_trangthai
        CHECK (`Trạng thái khả dụng` IN ('Khả dụng', 'Không khả dụng')),
    ADD CONSTRAINT chk_bienthe_khadung
        CHECK (`Trạng thái khả dụng` <> 'Khả dụng' OR COALESCE(`Kết quả xử lý`, '') = 'Đã duyệt');

DELIMITER $$

DROP PROCEDURE IF EXISTS sp_KiemTraChiTietDonHang$$
CREATE PROCEDURE sp_KiemTraChiTietDonHang(
    IN p_MaDonHang INT, IN p_MaBienThe INT, IN p_SoLuong INT)
BEGIN
    DECLARE v_Dem INT DEFAULT 0;
    DECLARE v_KetQuaXuLy VARCHAR(50);
    DECLARE v_TrangThaiKhaDung VARCHAR(50);
    DECLARE v_MaChiNhanh INT;
    DECLARE v_SoLuongTon INT DEFAULT 0;
    DECLARE v_Msg VARCHAR(128);

    SELECT COUNT(*), MAX(`Mã chi nhánh`) INTO v_Dem, v_MaChiNhanh
    FROM `Đơn hàng` WHERE `Mã đơn hàng` = p_MaDonHang;
    IF v_Dem = 0 THEN
        SET v_Msg = CONCAT('Don hang ', p_MaDonHang, ' khong ton tai.');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_Msg;
    END IF;

    SELECT COUNT(*), MAX(`Kết quả xử lý`), MAX(`Trạng thái khả dụng`)
      INTO v_Dem, v_KetQuaXuLy, v_TrangThaiKhaDung
    FROM `Biến thể sản phẩm` WHERE `Mã biến thể` = p_MaBienThe;
    IF v_Dem = 0 THEN
        SET v_Msg = CONCAT('Bien the ', p_MaBienThe, ' khong ton tai.');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_Msg;
    END IF;
    IF NOT (v_KetQuaXuLy <=> 'Đã duyệt') THEN
        SET v_Msg = CONCAT('Bien the ', p_MaBienThe, ' chua duoc duyet (',
                           COALESCE(v_KetQuaXuLy, 'chua xu ly'), '), khong the dat hang.');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_Msg;
    END IF;
    IF NOT (v_TrangThaiKhaDung <=> 'Khả dụng') THEN
        SET v_Msg = CONCAT('Bien the ', p_MaBienThe, ' hien khong kha dung, khong the dat hang.');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_Msg;
    END IF;

    SELECT COUNT(*), COALESCE(MAX(`Số lượng tồn`), 0) INTO v_Dem, v_SoLuongTon
    FROM `Tồn kho` WHERE `Mã chi nhánh` = v_MaChiNhanh AND `Mã biến thể` = p_MaBienThe;
    IF v_Dem = 0 THEN
        SET v_Msg = CONCAT('Chi nhanh ', v_MaChiNhanh, ' khong co ton kho bien the ', p_MaBienThe, '.');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_Msg;
    END IF;
    IF v_SoLuongTon < p_SoLuong THEN
        SET v_Msg = CONCAT('Ton kho chi nhanh ', v_MaChiNhanh, ' chi con ', v_SoLuongTon,
                           ', khong du dat ', p_SoLuong, '.');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_Msg;
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_CTDH_BeforeInsert$$
CREATE TRIGGER trg_CTDH_BeforeInsert BEFORE INSERT ON `Chi tiết đơn hàng`
FOR EACH ROW
BEGIN
    CALL sp_KiemTraChiTietDonHang(NEW.`Mã đơn hàng`, NEW.`Mã biến thể`, NEW.`Số lượng`);
END$$

DROP TRIGGER IF EXISTS trg_CTDH_BeforeUpdate$$
CREATE TRIGGER trg_CTDH_BeforeUpdate BEFORE UPDATE ON `Chi tiết đơn hàng`
FOR EACH ROW
BEGIN
    IF NOT (NEW.`Mã đơn hàng` <=> OLD.`Mã đơn hàng`)
       OR NOT (NEW.`Mã biến thể` <=> OLD.`Mã biến thể`)
       OR NOT (NEW.`Số lượng` <=> OLD.`Số lượng`) THEN
        CALL sp_KiemTraChiTietDonHang(NEW.`Mã đơn hàng`, NEW.`Mã biến thể`, NEW.`Số lượng`);
    END IF;
END$$

DROP PROCEDURE IF EXISTS sp_CapNhatDiemTBSanPham$$
CREATE PROCEDURE sp_CapNhatDiemTBSanPham(IN p_MaDonHang INT, IN p_SoThuTuDong INT)
BEGIN
    DECLARE v_MaSanPham INT;

    SELECT MAX(bt.`Mã sản phẩm`) INTO v_MaSanPham
    FROM `Chi tiết đơn hàng` ct
    JOIN `Biến thể sản phẩm` bt ON bt.`Mã biến thể` = ct.`Mã biến thể`
    WHERE ct.`Mã đơn hàng` = p_MaDonHang AND ct.`Số thứ tự dòng` = p_SoThuTuDong;

    IF v_MaSanPham IS NOT NULL THEN
        UPDATE `Sản phẩm`
        SET `Điểm đánh giá TB` = (
                SELECT ROUND(COALESCE(AVG(dg.`Số sao (1-5)`), 0), 2)
                FROM `Đánh giá` dg
                JOIN `Chi tiết đơn hàng` ct ON ct.`Mã đơn hàng` = dg.`Mã đơn hàng`
                                           AND ct.`Số thứ tự dòng` = dg.`Số thứ tự dòng`
                JOIN `Biến thể sản phẩm` bt ON bt.`Mã biến thể` = ct.`Mã biến thể`
                WHERE bt.`Mã sản phẩm` = v_MaSanPham
                  AND dg.`Trạng thái hiển thị` = 'Hiển thị')
        WHERE `Mã sản phẩm` = v_MaSanPham;
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_DANHGIA_AfterInsert$$
CREATE TRIGGER trg_DANHGIA_AfterInsert AFTER INSERT ON `Đánh giá`
FOR EACH ROW
BEGIN
    CALL sp_CapNhatDiemTBSanPham(NEW.`Mã đơn hàng`, NEW.`Số thứ tự dòng`);
END$$

DROP TRIGGER IF EXISTS trg_DANHGIA_AfterUpdate$$
CREATE TRIGGER trg_DANHGIA_AfterUpdate AFTER UPDATE ON `Đánh giá`
FOR EACH ROW
BEGIN
    IF NOT (NEW.`Số sao (1-5)` <=> OLD.`Số sao (1-5)`)
       OR NOT (NEW.`Trạng thái hiển thị` <=> OLD.`Trạng thái hiển thị`)
       OR NOT (NEW.`Mã đơn hàng` <=> OLD.`Mã đơn hàng`)
       OR NOT (NEW.`Số thứ tự dòng` <=> OLD.`Số thứ tự dòng`) THEN
        CALL sp_CapNhatDiemTBSanPham(NEW.`Mã đơn hàng`, NEW.`Số thứ tự dòng`);
        IF NOT (NEW.`Mã đơn hàng` <=> OLD.`Mã đơn hàng`)
           OR NOT (NEW.`Số thứ tự dòng` <=> OLD.`Số thứ tự dòng`) THEN
            CALL sp_CapNhatDiemTBSanPham(OLD.`Mã đơn hàng`, OLD.`Số thứ tự dòng`);
        END IF;
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_DANHGIA_AfterDelete$$
CREATE TRIGGER trg_DANHGIA_AfterDelete AFTER DELETE ON `Đánh giá`
FOR EACH ROW
BEGIN
    CALL sp_CapNhatDiemTBSanPham(OLD.`Mã đơn hàng`, OLD.`Số thứ tự dòng`);
END$$

DELIMITER ;

UPDATE `Sản phẩm` sp
SET sp.`Điểm đánh giá TB` = (
        SELECT ROUND(COALESCE(AVG(dg.`Số sao (1-5)`), 0), 2)
        FROM `Đánh giá` dg
        JOIN `Chi tiết đơn hàng` ct ON ct.`Mã đơn hàng` = dg.`Mã đơn hàng`
                                   AND ct.`Số thứ tự dòng` = dg.`Số thứ tự dòng`
        JOIN `Biến thể sản phẩm` bt ON bt.`Mã biến thể` = ct.`Mã biến thể`
        WHERE bt.`Mã sản phẩm` = sp.`Mã sản phẩm`
          AND dg.`Trạng thái hiển thị` = 'Hiển thị')
WHERE sp.`Mã sản phẩm` > 0;

DELIMITER $$

DROP PROCEDURE IF EXISTS sp_Demo_Trigger$$
CREATE PROCEDURE sp_Demo_Trigger()
BEGIN
    DECLARE v_dh   INT DEFAULT 5;
    DECLARE v_stt  INT DEFAULT 99;
    DECLARE v_bt_ok INT DEFAULT 5;
    DECLARE v_sp   INT DEFAULT 5;
    DECLARE v_bt_chua_duyet INT;
    DECLARE v_bt_ngung_ban  INT;
    DECLARE v_bt_khong_ton  INT;
    DECLARE v_ton  INT;
    DECLARE v_mdg  INT;
    DECLARE v_buoc VARCHAR(150);
    DECLARE v_loi  BOOLEAN DEFAULT FALSE;
    DECLARE v_msg  TEXT;

    DECLARE CONTINUE HANDLER FOR SQLSTATE '45000'
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT;
        SET v_loi = TRUE;
    END;

    DROP TEMPORARY TABLE IF EXISTS tmp_kq_demo;
    CREATE TEMPORARY TABLE tmp_kq_demo (
        stt INT AUTO_INCREMENT PRIMARY KEY,
        buoc VARCHAR(150),
        ky_vong VARCHAR(10),
        ket_qua VARCHAR(300),
        diem_tb DECIMAL(3,2) NULL
    ) DEFAULT CHARSET = utf8mb4;

    DELETE FROM `Chi tiết đơn hàng` WHERE `Mã đơn hàng` = v_dh AND `Số thứ tự dòng` IN (98, 99);
    DELETE FROM `Biến thể sản phẩm` WHERE `Mã biến thể` > 0 AND `Màu sắc` LIKE 'Demo %';

    INSERT INTO `Biến thể sản phẩm` (`Mã sản phẩm`, `Màu sắc`, `Kết quả xử lý`, `Giá bán`, `Trạng thái khả dụng`)
    VALUES (v_sp, 'Demo chờ duyệt', 'Chờ duyệt', 2900000, 'Không khả dụng');
    SET v_bt_chua_duyet = LAST_INSERT_ID();
    INSERT INTO `Biến thể sản phẩm` (`Mã sản phẩm`, `Màu sắc`, `Kết quả xử lý`, `Giá bán`, `Trạng thái khả dụng`)
    VALUES (v_sp, 'Demo ngừng bán', 'Đã duyệt', 2900000, 'Không khả dụng');
    SET v_bt_ngung_ban = LAST_INSERT_ID();
    INSERT INTO `Biến thể sản phẩm` (`Mã sản phẩm`, `Màu sắc`, `Kết quả xử lý`, `Giá bán`, `Trạng thái khả dụng`)
    VALUES (v_sp, 'Demo không tồn kho', 'Đã duyệt', 2900000, 'Khả dụng');
    SET v_bt_khong_ton = LAST_INSERT_ID();

    SET v_ton = (SELECT tk.`Số lượng tồn` FROM `Tồn kho` tk JOIN `Đơn hàng` dh ON dh.`Mã chi nhánh` = tk.`Mã chi nhánh`
                 WHERE dh.`Mã đơn hàng` = v_dh AND tk.`Mã biến thể` = v_bt_ok);

    SET v_buoc = '1.2 Thêm dòng đơn với biến thể CHƯA DUYỆT'; SET v_loi = FALSE;
    INSERT INTO `Chi tiết đơn hàng` (`Mã đơn hàng`, `Số thứ tự dòng`, `Mã biến thể`, `Số lượng`, `Đơn giá lúc mua`, `Số tiền giảm`, `Thành tiền`)
    VALUES (v_dh, v_stt, v_bt_chua_duyet, 1, 2900000, 0, 2900000);
    INSERT INTO tmp_kq_demo (buoc, ky_vong, ket_qua) VALUES (v_buoc, 'LỖI', IF(v_loi, CONCAT('Bị chặn: ', v_msg), 'Được thực hiện'));

    SET v_buoc = '1.3 Thêm dòng đơn với biến thể ĐÃ DUYỆT nhưng KHÔNG KHẢ DỤNG'; SET v_loi = FALSE;
    INSERT INTO `Chi tiết đơn hàng` (`Mã đơn hàng`, `Số thứ tự dòng`, `Mã biến thể`, `Số lượng`, `Đơn giá lúc mua`, `Số tiền giảm`, `Thành tiền`)
    VALUES (v_dh, v_stt, v_bt_ngung_ban, 1, 2900000, 0, 2900000);
    INSERT INTO tmp_kq_demo (buoc, ky_vong, ket_qua) VALUES (v_buoc, 'LỖI', IF(v_loi, CONCAT('Bị chặn: ', v_msg), 'Được thực hiện'));

    SET v_buoc = '1.4 Thêm dòng đơn, chi nhánh xử lý KHÔNG CÓ TỒN KHO biến thể'; SET v_loi = FALSE;
    INSERT INTO `Chi tiết đơn hàng` (`Mã đơn hàng`, `Số thứ tự dòng`, `Mã biến thể`, `Số lượng`, `Đơn giá lúc mua`, `Số tiền giảm`, `Thành tiền`)
    VALUES (v_dh, v_stt, v_bt_khong_ton, 1, 2900000, 0, 2900000);
    INSERT INTO tmp_kq_demo (buoc, ky_vong, ket_qua) VALUES (v_buoc, 'LỖI', IF(v_loi, CONCAT('Bị chặn: ', v_msg), 'Được thực hiện'));

    SET v_buoc = CONCAT('1.5 Đặt VƯỢT tồn kho (tồn = ', v_ton, ', đặt ', v_ton + 1, ')'); SET v_loi = FALSE;
    INSERT INTO `Chi tiết đơn hàng` (`Mã đơn hàng`, `Số thứ tự dòng`, `Mã biến thể`, `Số lượng`, `Đơn giá lúc mua`, `Số tiền giảm`, `Thành tiền`)
    VALUES (v_dh, v_stt, v_bt_ok, v_ton + 1, 2900000, 0, 2900000);
    INSERT INTO tmp_kq_demo (buoc, ky_vong, ket_qua) VALUES (v_buoc, 'LỖI', IF(v_loi, CONCAT('Bị chặn: ', v_msg), 'Được thực hiện'));

    SET v_buoc = '1.6 Thêm dòng đơn HỢP LỆ (1 sản phẩm, đủ tồn)'; SET v_loi = FALSE;
    INSERT INTO `Chi tiết đơn hàng` (`Mã đơn hàng`, `Số thứ tự dòng`, `Mã biến thể`, `Số lượng`, `Đơn giá lúc mua`, `Số tiền giảm`, `Thành tiền`)
    VALUES (v_dh, v_stt, v_bt_ok, 1, 2900000, 0, 2900000);
    INSERT INTO tmp_kq_demo (buoc, ky_vong, ket_qua) VALUES (v_buoc, 'OK', IF(v_loi, CONCAT('Bị chặn: ', v_msg), 'Được thực hiện'));

    SET v_buoc = CONCAT('1.7 UPDATE số lượng lên ', v_ton + 1, ' (VƯỢT tồn kho)'); SET v_loi = FALSE;
    UPDATE `Chi tiết đơn hàng` SET `Số lượng` = v_ton + 1 WHERE `Mã đơn hàng` = v_dh AND `Số thứ tự dòng` = v_stt;
    INSERT INTO tmp_kq_demo (buoc, ky_vong, ket_qua) VALUES (v_buoc, 'LỖI', IF(v_loi, CONCAT('Bị chặn: ', v_msg), 'Được thực hiện'));

    SET v_buoc = '1.8 UPDATE số lượng lên 2 (HỢP LỆ)'; SET v_loi = FALSE;
    UPDATE `Chi tiết đơn hàng` SET `Số lượng` = 2 WHERE `Mã đơn hàng` = v_dh AND `Số thứ tự dòng` = v_stt;
    INSERT INTO tmp_kq_demo (buoc, ky_vong, ket_qua) VALUES (v_buoc, 'OK', IF(v_loi, CONCAT('Bị chặn: ', v_msg), 'Được thực hiện'));

    DELETE FROM `Chi tiết đơn hàng` WHERE `Mã đơn hàng` = v_dh AND `Số thứ tự dòng` = v_stt;

    INSERT INTO `Chi tiết đơn hàng` (`Mã đơn hàng`, `Số thứ tự dòng`, `Mã biến thể`, `Số lượng`, `Đơn giá lúc mua`, `Số tiền giảm`, `Thành tiền`)
    VALUES (v_dh, 98, v_bt_ok, 1, 2900000, 0, 2900000);

    INSERT INTO tmp_kq_demo (buoc, ky_vong, ket_qua, diem_tb)
    SELECT '2.0 Điểm ban đầu của sản phẩm 5 (1 đánh giá 5 sao có sẵn)', '5.00', 'Chưa thao tác', `Điểm đánh giá TB`
    FROM `Sản phẩm` WHERE `Mã sản phẩm` = v_sp;

    SET v_loi = FALSE;
    INSERT INTO `Đánh giá` (`Mã đơn hàng`, `Số thứ tự dòng`, `Số sao (1-5)`, `Nội dung nhận xét`, `Thời điểm đánh giá`, `Trạng thái hiển thị`)
    VALUES (v_dh, 98, 2, 'Giao hơi chậm', NOW(), 'Hiển thị');
    SET v_mdg = LAST_INSERT_ID();
    INSERT INTO tmp_kq_demo (buoc, ky_vong, ket_qua, diem_tb)
    SELECT '2.1 INSERT đánh giá 2 sao', '3.50', 'Đã thêm đánh giá', `Điểm đánh giá TB` FROM `Sản phẩm` WHERE `Mã sản phẩm` = v_sp;

    UPDATE `Đánh giá` SET `Số sao (1-5)` = 4 WHERE `Mã đánh giá` = v_mdg;
    INSERT INTO tmp_kq_demo (buoc, ky_vong, ket_qua, diem_tb)
    SELECT '2.2 UPDATE số sao 2 -> 4', '4.50', 'Đã sửa số sao', `Điểm đánh giá TB` FROM `Sản phẩm` WHERE `Mã sản phẩm` = v_sp;

    UPDATE `Đánh giá` SET `Trạng thái hiển thị` = 'Ẩn' WHERE `Mã đánh giá` = v_mdg;
    INSERT INTO tmp_kq_demo (buoc, ky_vong, ket_qua, diem_tb)
    SELECT '2.3 Ẩn đánh giá (không tính nữa)', '5.00', 'Đã ẩn đánh giá', `Điểm đánh giá TB` FROM `Sản phẩm` WHERE `Mã sản phẩm` = v_sp;

    UPDATE `Đánh giá` SET `Trạng thái hiển thị` = 'Hiển thị' WHERE `Mã đánh giá` = v_mdg;
    INSERT INTO tmp_kq_demo (buoc, ky_vong, ket_qua, diem_tb)
    SELECT '2.4 Hiển thị lại đánh giá', '4.50', 'Đã hiển thị lại', `Điểm đánh giá TB` FROM `Sản phẩm` WHERE `Mã sản phẩm` = v_sp;

    DELETE FROM `Đánh giá` WHERE `Mã đánh giá` = v_mdg;
    INSERT INTO tmp_kq_demo (buoc, ky_vong, ket_qua, diem_tb)
    SELECT '2.5 DELETE đánh giá', '5.00', 'Đã xóa đánh giá', `Điểm đánh giá TB` FROM `Sản phẩm` WHERE `Mã sản phẩm` = v_sp;

    DELETE FROM `Chi tiết đơn hàng` WHERE `Mã đơn hàng` = v_dh AND `Số thứ tự dòng` = 98;
    DELETE FROM `Biến thể sản phẩm` WHERE `Mã biến thể` IN (v_bt_chua_duyet, v_bt_ngung_ban, v_bt_khong_ton);

    SELECT buoc AS `Bước`, ky_vong AS `Kỳ vọng`, ket_qua AS `Kết quả`, diem_tb AS `Điểm TB sản phẩm`
    FROM tmp_kq_demo ORDER BY stt;
    DROP TEMPORARY TABLE tmp_kq_demo;
END$$

DELIMITER ;

CALL sp_Demo_Trigger();
