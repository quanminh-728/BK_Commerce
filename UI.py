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
        password=os.getenv("DB_PASSWORD", ""),
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


@app.route("/hoi-vien", methods=["GET", "POST"])
def hoi_vien():
    ket_qua = None
    ma_khach_hang = ""
    loi = None

    if request.method == "POST":
        ma_khach_hang = request.form.get("ma_khach_hang", "").strip()
        try:
            if not ma_khach_hang:
                raise ValueError("Vui lòng nhập mã khách hàng.")
            if not ma_khach_hang.isdigit() or int(ma_khach_hang) <= 0:
                raise ValueError("Mã khách hàng phải là số nguyên dương.")

            with cursor() as cur:
                cur.execute(
                    "SELECT 1 FROM `Khách hàng` WHERE `Mã người dùng` = %s LIMIT 1",
                    (int(ma_khach_hang),),
                )
                if cur.fetchone() is None:
                    raise ValueError("Không tìm thấy khách hàng có mã %s." % ma_khach_hang)

                # Hai hàm được gọi trực tiếp từ MySQL, không tính toán lại ở Python.
                cur.execute(
                    "SELECT fn_TinhTongChiTieuKhachHang(%s) AS tong_chi_tieu, "
                    "fn_XacDinhHangHoiVien(%s) AS hang_hoi_vien",
                    (int(ma_khach_hang), int(ma_khach_hang)),
                )
                ket_qua = cur.fetchone()
        except ValueError as e:
            loi = str(e)
        except pymysql.MySQLError as e:
            loi = "Không thể truy vấn dữ liệu: " + db_error_text(e)

    return render_template(
        "hoi_vien.html", ma_khach_hang=ma_khach_hang, ket_qua=ket_qua, loi=loi
    )


if __name__ == "__main__":
    app.run(debug=True)
