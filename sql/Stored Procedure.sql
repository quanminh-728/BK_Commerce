USE ThuongMaiDienTu;

DROP PROCEDURE IF EXISTS sp_TimKiemBienTheTheoGiaVaDanhMuc;

DELIMITER //

CREATE PROCEDURE sp_TimKiemBienTheTheoGiaVaDanhMuc(
    IN p_GiaMin DECIMAL(15,2),
    IN p_GiaMax DECIMAL(15,2),
    IN p_MaDanhMuc INT
)
BEGIN
    SELECT
        bt.`Mã biến thể`,
        sp.`Mã sản phẩm`,
        sp.`Tên sản phẩm`,
        dm.`Mã danh mục`,
        dm.`Tên danh mục`,
        bt.`Màu sắc`,
        bt.`Dung lượng`,
        bt.`Kích thước`,
        bt.`Giá bán`,
        bt.`Trạng thái khả dụng`
    FROM `Biến thể sản phẩm` AS bt
    INNER JOIN `Sản phẩm` AS sp
        ON bt.`Mã sản phẩm` = sp.`Mã sản phẩm`
    INNER JOIN `Phân loại sản phẩm` AS pl
        ON sp.`Mã sản phẩm` = pl.`Mã sản phẩm`
    INNER JOIN `Danh mục` AS dm
        ON pl.`Mã danh mục` = dm.`Mã danh mục`
    WHERE
        bt.`Giá bán` BETWEEN p_GiaMin AND p_GiaMax
        AND dm.`Mã danh mục` = p_MaDanhMuc
    ORDER BY
        bt.`Giá bán` ASC,
        sp.`Tên sản phẩm` ASC,
        bt.`Mã biến thể` ASC;
END //

DELIMITER ;

-- Test 1: Điện thoại thông minh (Mã danh mục = 2)
-- Dự kiến có iPhone 16 Pro Max và Samsung Galaxy S24 Ultra
CALL sp_TimKiemBienTheTheoGiaVaDanhMuc(
    30000000,
    36000000,
    2
);

-- Test 2: Laptop & Máy tính (Mã danh mục = 3)
-- Dự kiến có MacBook Air M3
CALL sp_TimKiemBienTheTheoGiaVaDanhMuc(
    30000000,
    35000000,
    3
);

-- Test 3: Giày Sneaker (Mã danh mục = 5)
-- Dự kiến có Nike Air Force 1 07
CALL sp_TimKiemBienTheTheoGiaVaDanhMuc(
    2000000,
    4000000,
    5
);

-- Test 4: Khoảng giá không có dữ liệu
-- Dự kiến trả về 0 dòng
CALL sp_TimKiemBienTheTheoGiaVaDanhMuc(
    100000,
    500000,
    2
);
