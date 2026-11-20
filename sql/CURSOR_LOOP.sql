
DELIMITER //

CREATE FUNCTION fn_TinhTongChiTieuKhachHang(
    p_MaKhachHang INT
)
RETURNS DECIMAL(15,2)
NOT DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_TongChiTieu DECIMAL(15,2) DEFAULT 0;
    DECLARE v_SoLuong INT;
    DECLARE v_DonGia DECIMAL(15,2);
    DECLARE v_SoTienGiam DECIMAL(15,2);
    DECLARE v_HetDuLieu BOOLEAN DEFAULT FALSE;
    DECLARE v_TonTai INT DEFAULT 0;

    -- Cursor lấy các dòng hàng thuộc đơn hoàn thành
    -- và chưa được hoàn tiền hoàn tất
    DECLARE cur_ChiTiet CURSOR FOR
        SELECT
            ct.`Số lượng`,
            ct.`Đơn giá lúc mua`,
            ct.`Số tiền giảm`
        FROM `Đơn hàng` dh
        JOIN `Chi tiết đơn hàng` ct
            ON dh.`Mã đơn hàng` = ct.`Mã đơn hàng`
        WHERE dh.`Mã khách hàng` = p_MaKhachHang
          AND dh.`Trạng thái hiện tại` = 'Hoàn thành'
          AND NOT EXISTS (
              SELECT 1
              FROM `Yêu cầu bảo hành đổi trả` yc
              WHERE yc.`Mã đơn hàng` = ct.`Mã đơn hàng`
                AND yc.`Số thứ tự dòng` = ct.`Số thứ tự dòng`
                AND yc.`Loại yêu cầu` = 'Trả hàng hoàn tiền'
                AND yc.`Trạng thái xử lý` = 'Đã hoàn tất'
          );

    DECLARE CONTINUE HANDLER FOR NOT FOUND
        SET v_HetDuLieu = TRUE;

    -- 1. Kiểm tra tham số đầu vào
    IF p_MaKhachHang IS NULL OR p_MaKhachHang <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Ma khach hang khong hop le';
    END IF;

    -- 2. Kiểm tra khách hàng có tồn tại không
    SELECT COUNT(*)
    INTO v_TonTai
    FROM `Khách hàng`
    WHERE `Mã người dùng` = p_MaKhachHang;

    IF v_TonTai = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Khach hang khong ton tai';
    END IF;

    -- 3. Duyệt từng dòng chi tiết đơn hàng
    OPEN cur_ChiTiet;

    doc_du_lieu: LOOP
        FETCH cur_ChiTiet
        INTO v_SoLuong, v_DonGia, v_SoTienGiam;

        IF v_HetDuLieu THEN
            LEAVE doc_du_lieu;
        END IF;

        -- Cộng chi tiêu của dòng hàng hiện tại
        SET v_TongChiTieu = v_TongChiTieu
            + (v_SoLuong * v_DonGia - v_SoTienGiam);
    END LOOP;

    CLOSE cur_ChiTiet;

    RETURN v_TongChiTieu;
END //

DELIMITER ;




DELIMITER //

CREATE FUNCTION fn_XacDinhHangHoiVien(
    p_MaKhachHang INT
)
RETURNS VARCHAR(50)
NOT DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_TongChiTieu DECIMAL(15,2);
    DECLARE v_MucChiTieuToiThieu DECIMAL(15,2);
    DECLARE v_TenHang VARCHAR(50);
    DECLARE v_KetQua VARCHAR(50) DEFAULT NULL;
    DECLARE v_HetDuLieu BOOLEAN DEFAULT FALSE;

    -- Cursor duyệt các hạng từ cao xuống thấp
    DECLARE cur_HangHoiVien CURSOR FOR
        SELECT
            `Tên hạng`,
            `Mức chi tiêu tối thiểu`
        FROM `Hạng hội viên`
        ORDER BY `Mức chi tiêu tối thiểu` DESC;

    DECLARE CONTINUE HANDLER FOR NOT FOUND
        SET v_HetDuLieu = TRUE;

    -- 1. Tính tổng chi tiêu của khách hàng
    SET v_TongChiTieu =
        fn_TinhTongChiTieuKhachHang(p_MaKhachHang);

    -- 2. Duyệt các hạng hội viên
    OPEN cur_HangHoiVien;

    doc_hang: LOOP
        FETCH cur_HangHoiVien
        INTO v_TenHang, v_MucChiTieuToiThieu;

        IF v_HetDuLieu THEN
            LEAVE doc_hang;
        END IF;

        -- Kiểm tra khách hàng có đạt mức chi tiêu không
        IF v_TongChiTieu >= v_MucChiTieuToiThieu THEN
            SET v_KetQua = v_TenHang;
            LEAVE doc_hang;
        END IF;
    END LOOP;

    CLOSE cur_HangHoiVien;

    -- 3. Trả về kết quả
    IF v_KetQua IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Khong tim thay hang hoi vien phu hop';
    END IF;

    RETURN v_KetQua;
END //

DELIMITER ;
