import os
from contextlib import contextmanager
from decimal import Decimal, InvalidOperation

import pymysql
from flask import Flask, flash, redirect, render_template, request, url_for

app = Flask(__name__)
app.secret_key = "btl2-bk-commerce"

TRANG_THAI = ["Đang kinh doanh", "Ngừng kinh doanh", "Tạm ẩn"]


def get_conn():
    return pymysql.connect(
        host=os.getenv("DB_HOST", "localhost"),
        port=int(os.getenv("DB_PORT", "3306")),
        user=os.getenv("DB_USER", "root"),
        password="",
        database=os.getenv("DB_NAME", "ThuongMaiDienTu"),
        charset="utf8mb4",
        cursorclass=pymysql.cursors.DictCursor,
        autocommit=True,
    )


@contextmanager
def cursor():
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            yield cur
    finally:
        conn.close()


def db_error_text(exc):
    if isinstance(exc, pymysql.MySQLError) and len(exc.args) >= 2:
        return str(exc.args[1])
    return str(exc)


@app.template_filter("vnd")
def vnd(value):
    return "{:,.0f}".format(value).replace(",", ".") + " đ" if value is not None else ""


@app.template_filter("diem")
def diem(value):
    return "{:.2f}".format(value) if value is not None else "—"


@app.template_global("anh")
def anh(ma_sp):
    for ext in ("jpg", "jpeg", "png", "webp"):
        name = "img/sp%s.%s" % (ma_sp, ext)
        if os.path.exists(os.path.join(app.static_folder, name)):
            return url_for("static", filename=name)
    return None


@app.context_processor
def inject_nav():
    return {"endpoint": request.endpoint}


def call_proc(name, args):
    try:
        with cursor() as cur:
            cur.callproc(name, args)
            return True, (cur.fetchone() if cur.description else None)
    except pymysql.MySQLError as e:
        return False, db_error_text(e)


def parse_sp(f):
    errors = []
    d = {"Ten": f.get("Ten", "").strip(), "MoTa": f.get("MoTa", "").strip(),
         "Gia": f.get("Gia", "").strip(), "TrangThai": f.get("TrangThai", "")}
    if not d["Ten"]:
        errors.append("Tên sản phẩm không được để trống.")
    elif len(d["Ten"]) > 200:
        errors.append("Tên sản phẩm không được dài quá 200 ký tự.")
    try:
        if Decimal(d["Gia"]) < 0:
            errors.append("Giá cơ sở không được âm.")
    except InvalidOperation:
        errors.append("Giá cơ sở phải là một số hợp lệ.")
    if d["TrangThai"] not in TRANG_THAI:
        errors.append("Trạng thái kinh doanh không hợp lệ.")
    return d, errors


def render_san_pham(modal=None):
    products = []
    try:
        with cursor() as cur:
            cur.execute(
                "SELECT s.`Mã sản phẩm` AS ma, s.`Tên sản phẩm` AS ten, s.`Mô tả` AS mo_ta, s.`Giá cơ sở` AS gia, "
                "s.`Trạng thái kinh doanh` AS tt, s.`Điểm đánh giá TB` AS diem, "
                "(SELECT COUNT(*) FROM `Biến thể sản phẩm` b WHERE b.`Mã sản phẩm` = s.`Mã sản phẩm`) AS so_bt "
                "FROM `Sản phẩm` s ORDER BY s.`Mã sản phẩm`")
            products = cur.fetchall()
    except pymysql.MySQLError as e:
        flash("Lỗi cơ sở dữ liệu: " + db_error_text(e), "error")
    return render_template("san_pham.html", products=products, trang_thai=TRANG_THAI, modal=modal)


def sp_modal(mode, ma, data, errors):
    return {"mode": mode, "id": ma, "form": data, "errors": errors,
            "action": url_for("san_pham_sua", ma=ma) if mode == "sua" else url_for("san_pham_them"),
            "title": ("Sửa sản phẩm #%s" % ma) if mode == "sua" else "Thêm sản phẩm"}


@app.route("/")
@app.route("/san-pham")
def san_pham():
    return render_san_pham()


@app.route("/san-pham/them", methods=["POST"])
def san_pham_them():
    d, errors = parse_sp(request.form)
    if not errors:
        ok, res = call_proc("sp_ThemSanPham", (d["Ten"], d["MoTa"] or None, Decimal(d["Gia"]), d["TrangThai"]))
        if ok:
            flash(res["ThongBao"] if res else "Đã thêm sản phẩm.", "ok")
            return redirect(url_for("san_pham"))
        errors = [res]
    return render_san_pham(sp_modal("them", None, d, errors))


@app.route("/san-pham/sua/<int:ma>", methods=["POST"])
def san_pham_sua(ma):
    d, errors = parse_sp(request.form)
    if not errors:
        ok, res = call_proc("sp_CapNhatSanPham", (ma, d["Ten"], d["MoTa"] or None, Decimal(d["Gia"]), d["TrangThai"]))
        if ok:
            flash(res["ThongBao"] if res else "Đã cập nhật sản phẩm %s." % ma, "ok")
            return redirect(url_for("san_pham"))
        errors = [res]
    return render_san_pham(sp_modal("sua", ma, d, errors))


@app.route("/san-pham/xoa/<int:ma>", methods=["POST"])
def san_pham_xoa(ma):
    ok, res = call_proc("sp_XoaSanPham", (ma,))
    if ok:
        flash(res["ThongBao"] if res else "Đã xóa sản phẩm %s." % ma, "ok")
    else:
        flash(res, "error")
    return redirect(url_for("san_pham"))


@app.get("/chi-tiet-don-hang")
@app.get("/chi-tiet-don-hang/<int:ma>")
def chi_tiet_don_hang(ma=None, modal=None):
    customers, orders = [], []
    customer = request.args.get("khach_hang", type=int)
    try:
        with cursor() as cur:
            cur.execute(
                "SELECT `Mã người dùng` AS ma, CONCAT_WS(' ', `Họ`, NULLIF(`Tên đệm`, ''), `Tên`) AS ten "
                "FROM `Khách hàng` JOIN `Người dùng` USING (`Mã người dùng`) ORDER BY `Tên`, `Họ`, ma")
            customers = cur.fetchall()
            if ma is not None:
                cur.execute("SELECT `Mã khách hàng` AS ma FROM `Đơn hàng` WHERE `Mã đơn hàng` = %s", (ma,))
                owner = cur.fetchone()
                customer = owner["ma"] if owner else None
                if owner is None:
                    flash("Không tìm thấy đơn hàng.", "error")
            if customer is not None:
                cur.execute(
                    "SELECT `Mã đơn hàng` AS ma, `Tên người nhận` AS ten, "
                    "`Mã chi nhánh` AS chi_nhanh, `Trạng thái hiện tại` AS trang_thai "
                    "FROM `Đơn hàng` WHERE `Mã khách hàng` = %s ORDER BY `Mã đơn hàng` DESC",
                    (customer,))
                orders = cur.fetchall()
            variants_by_branch = {}
            for order in orders:
                cur.execute(
                    "SELECT c.`Số thứ tự dòng` AS dong, c.`Mã biến thể` AS bien_the, "
                    "c.`Số lượng` AS so_luong, t.`Số lượng tồn` AS ton, "
                    "c.`Đơn giá lúc mua` AS gia, c.`Thành tiền` AS tien, "
                    "s.`Mã sản phẩm` AS san_pham, s.`Tên sản phẩm` AS ten, s.`Điểm đánh giá TB` AS diem, "
                    "d.`Mã đánh giá` AS danh_gia, d.`Số sao (1-5)` AS sao, "
                    "d.`Nội dung nhận xét` AS nd, d.`Trạng thái hiển thị` AS hien "
                    "FROM `Chi tiết đơn hàng` c JOIN `Biến thể sản phẩm` b USING (`Mã biến thể`) "
                    "JOIN `Sản phẩm` s USING (`Mã sản phẩm`) "
                    "LEFT JOIN `Đánh giá` d USING (`Mã đơn hàng`, `Số thứ tự dòng`) "
                    "LEFT JOIN `Tồn kho` t ON t.`Mã biến thể` = c.`Mã biến thể` AND t.`Mã chi nhánh` = %s "
                    "WHERE c.`Mã đơn hàng` = %s ORDER BY c.`Số thứ tự dòng`",
                    (order["chi_nhanh"], order["ma"]))
                order["lines"] = cur.fetchall()
                branch = order["chi_nhanh"]
                if branch not in variants_by_branch:
                    cur.execute(
                    "SELECT b.`Mã biến thể` AS ma, s.`Tên sản phẩm` AS ten, b.`Màu sắc` AS mau, "
                    "b.`Kết quả xử lý` AS duyet, b.`Trạng thái khả dụng` AS kha_dung, "
                    "t.`Số lượng tồn` AS ton FROM `Biến thể sản phẩm` b "
                    "JOIN `Sản phẩm` s USING (`Mã sản phẩm`) LEFT JOIN `Tồn kho` t "
                    "ON t.`Mã biến thể` = b.`Mã biến thể` AND t.`Mã chi nhánh` = %s "
                    "ORDER BY s.`Tên sản phẩm`, b.`Mã biến thể`", (branch,))
                    variants_by_branch[branch] = cur.fetchall()
                order["variants"] = variants_by_branch[branch]
    except pymysql.MySQLError as exc:
        flash("Lỗi cơ sở dữ liệu: " + db_error_text(exc), "error")
    return render_template("chi_tiet_don_hang.html", customers=customers, customer=customer,
                           orders=orders, active_order=ma, modal=modal)


@app.post("/chi-tiet-don-hang/<int:ma>/them")
@app.post("/chi-tiet-don-hang/<int:ma>/<int:dong>/sua")
def chi_tiet_don_hang_luu(ma, dong=None):
    adding = dong is None
    title = "Thêm dòng đơn hàng" if adding else f"Sửa số lượng dòng #{dong}"
    try:
        quantity = request.form.get("SoLuong", type=int)
        variant = request.form.get("BienThe", type=int)
        if quantity is None or not 1 <= quantity <= 2147483647:
            raise ValueError("Số lượng phải là số nguyên dương hợp lệ.")
        if adding and (variant is None or not 1 <= variant <= 2147483647):
            raise ValueError("Hãy chọn một biến thể sản phẩm.")
        with cursor() as cur:
            if adding:
                conn = cur.connection
                conn.begin()
                try:
                    cur.execute("SELECT 1 FROM `Đơn hàng` WHERE `Mã đơn hàng` = %s FOR UPDATE", (ma,))
                    if not cur.fetchone():
                        raise ValueError("Đơn hàng không tồn tại.")
                    cur.execute(
                        "SELECT COALESCE(MAX(`Số thứ tự dòng`), 0) + 1 AS dong "
                        "FROM `Chi tiết đơn hàng` WHERE `Mã đơn hàng` = %s", (ma,))
                    next_line = cur.fetchone()["dong"]
                    cur.execute(
                        "INSERT INTO `Chi tiết đơn hàng` (`Mã đơn hàng`, `Số thứ tự dòng`, "
                        "`Mã biến thể`, `Số lượng`, `Đơn giá lúc mua`, `Thành tiền`) "
                        "SELECT %s, %s, `Mã biến thể`, %s, `Giá bán`, `Giá bán` * %s "
                        "FROM `Biến thể sản phẩm` WHERE `Mã biến thể` = %s",
                        (ma, next_line, quantity, quantity, variant))
                    if not cur.rowcount:
                        raise ValueError("Biến thể sản phẩm không tồn tại.")
                    conn.commit()
                except Exception:
                    conn.rollback()
                    raise
            else:
                cur.execute(
                    "UPDATE `Chi tiết đơn hàng` SET `Số lượng` = %s, "
                    "`Thành tiền` = GREATEST(0, `Đơn giá lúc mua` * %s - `Số tiền giảm`) "
                    "WHERE `Mã đơn hàng` = %s AND `Số thứ tự dòng` = %s",
                    (quantity, quantity, ma, dong))
                if not cur.rowcount:
                    cur.execute(
                        "SELECT 1 FROM `Chi tiết đơn hàng` WHERE `Mã đơn hàng` = %s AND `Số thứ tự dòng` = %s",
                        (ma, dong))
                    if not cur.fetchone():
                        raise ValueError("Dòng đơn hàng không còn tồn tại.")
    except (ValueError, pymysql.MySQLError) as exc:
        return chi_tiet_don_hang(ma, {"kind": "line", "adding": adding, "title": title,
                                    "action": request.path, "form": request.form,
                                    "error": db_error_text(exc)})
    flash("Đã thêm dòng đơn hàng." if adding else "Đã lưu số lượng.", "ok")
    return redirect(url_for("chi_tiet_don_hang", ma=ma))


@app.post("/chi-tiet-don-hang/<int:ma>/<int:dong>/danh-gia/them")
@app.post("/chi-tiet-don-hang/<int:ma>/<int:dong>/danh-gia/<int:review>/sua")
def chi_tiet_don_hang_danh_gia(ma, dong, review=None):
    title = f"{'Thêm' if review is None else 'Sửa'} đánh giá dòng #{dong}"
    try:
        stars = request.form.get("sao", type=int)
        note = request.form.get("nd", "").strip()
        visibility = request.form.get("hien")
        if stars not in range(1, 6) or visibility not in ("Hiển thị", "Ẩn"):
            raise ValueError("Hãy chọn số sao từ 1 đến 5 và trạng thái hiển thị hợp lệ.")
        with cursor() as cur:
            if review is None:
                cur.execute(
                    "INSERT INTO `Đánh giá` (`Mã đơn hàng`, `Số thứ tự dòng`, `Số sao (1-5)`, "
                    "`Nội dung nhận xét`, `Trạng thái hiển thị`) VALUES (%s, %s, %s, %s, %s)",
                    (ma, dong, stars, note or None, visibility))
            else:
                cur.execute(
                    "UPDATE `Đánh giá` SET `Số sao (1-5)` = %s, `Nội dung nhận xét` = %s, "
                    "`Trạng thái hiển thị` = %s WHERE `Mã đánh giá` = %s "
                    "AND `Mã đơn hàng` = %s AND `Số thứ tự dòng` = %s",
                    (stars, note or None, visibility, review, ma, dong))
                if not cur.rowcount:
                    cur.execute(
                        "SELECT 1 FROM `Đánh giá` WHERE `Mã đánh giá` = %s "
                        "AND `Mã đơn hàng` = %s AND `Số thứ tự dòng` = %s", (review, ma, dong))
                    if not cur.fetchone():
                        raise ValueError("Đánh giá không còn tồn tại.")
    except (ValueError, pymysql.MySQLError) as exc:
        return chi_tiet_don_hang(ma, {"kind": "review", "title": title, "action": request.path,
                                    "form": request.form, "error": db_error_text(exc)})
    flash("Đã lưu đánh giá.", "ok")
    return redirect(url_for("chi_tiet_don_hang", ma=ma))


@app.post("/chi-tiet-don-hang/<int:ma>/<int:dong>/danh-gia/<int:review>/xoa")
def chi_tiet_don_hang_xoa_danh_gia(ma, dong, review):
    try:
        with cursor() as cur:
            cur.execute(
                "DELETE FROM `Đánh giá` WHERE `Mã đánh giá` = %s AND `Mã đơn hàng` = %s "
                "AND `Số thứ tự dòng` = %s", (review, ma, dong))
            if cur.rowcount:
                flash("Đã xóa đánh giá.", "ok")
            else:
                flash("Đánh giá không còn tồn tại.", "error")
    except pymysql.MySQLError as exc:
        flash(db_error_text(exc), "error")
    return redirect(url_for("chi_tiet_don_hang", ma=ma))


if __name__ == "__main__":
    app.run(debug=True)
