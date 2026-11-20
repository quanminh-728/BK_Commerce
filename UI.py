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


def call_proc_rows(name, args):
    """Gọi thủ tục và lấy TOÀN BỘ dòng của result set đầu tiên."""
    try:
        with cursor() as cur:
            cur.callproc(name, args)
            return True, list(cur.fetchall())
    except pymysql.MySQLError as e:
        return False, db_error_text(e)


def back_to(default):
    """Quay lại trang đã gọi (trường ẩn `next`), mặc định về trang `default`."""
    nxt = request.form.get("next", "")
    if nxt.startswith("/") and not nxt.startswith("//"):
        return redirect(nxt)
    return redirect(url_for(default))


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
            return back_to("san_pham")
        errors = [res]
    if request.form.get("next"):          # gọi từ trang Biến thể: báo lỗi rồi quay lại
        for e in errors:
            flash(e, "error")
        return back_to("san_pham")
    return render_san_pham(sp_modal("sua", ma, d, errors))


@app.route("/san-pham/xoa/<int:ma>", methods=["POST"])
def san_pham_xoa(ma):
    ok, res = call_proc("sp_XoaSanPham", (ma,))
    if ok:
        flash(res["ThongBao"] if res else "Đã xóa sản phẩm %s." % ma, "ok")
    else:
        flash(res, "error")
    return back_to("san_pham")


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


GIA_MAX = Decimal("9999999999999")
KHA_DUNG = ["Khả dụng", "Không khả dụng"]
SAP_XEP = {
    "gia_tang": ("Giá bán", False, "Giá bán: thấp → cao"),
    "gia_giam": ("Giá bán", True, "Giá bán: cao → thấp"),
    "ten_az": ("Tên sản phẩm", False, "Tên sản phẩm: A → Z"),
    "ten_za": ("Tên sản phẩm", True, "Tên sản phẩm: Z → A"),
    "ma_bt": ("Mã biến thể", False, "Mã biến thể"),
}


def parse_gia(raw, nhan, errors):
    raw = (raw or "").strip()
    if not raw:
        return None
    try:
        v = Decimal(raw)
        if not v.is_finite():
            raise InvalidOperation
    except InvalidOperation:
        errors.append("%s phải là một số hợp lệ." % nhan)
        return None
    if v < 0:
        errors.append("%s không được âm." % nhan)
        return None
    if v > GIA_MAX:
        errors.append("%s vượt quá giới hạn cho phép." % nhan)
        return None
    return v


@app.route("/bien-the")
def bien_the():
    """Danh sách biến thể: gọi sp_TimKiemBienTheTheoGiaVaDanhMuc (lọc theo giá + danh mục),
    tìm kiếm/lọc trạng thái/sắp xếp bổ sung, sửa/xóa sản phẩm qua thủ tục của thành viên 1."""
    a = request.args
    f = {"dm": a.get("dm", "").strip(), "gia_min": a.get("gia_min", "").strip(),
         "gia_max": a.get("gia_max", "").strip(), "q": a.get("q", "").strip(),
         "tt": a.get("tt", "").strip(), "sort": a.get("sort", "gia_tang")}
    if f["sort"] not in SAP_XEP:
        f["sort"] = "gia_tang"
    errors, rows, enrich = [], [], {}

    danh_muc = []
    try:
        with cursor() as cur:
            cur.execute("SELECT `Mã danh mục` AS ma, `Tên danh mục` AS ten FROM `Danh mục` ORDER BY `Mã danh mục`")
            danh_muc = cur.fetchall()
    except pymysql.MySQLError as e:
        errors.append("Không tải được danh mục: " + db_error_text(e))

    gmin = parse_gia(f["gia_min"], "Giá từ", errors)
    gmax = parse_gia(f["gia_max"], "Giá đến", errors)
    if gmin is not None and gmax is not None and gmin > gmax:
        errors.append("Giá từ không được lớn hơn Giá đến.")
    ma_dm = {d["ma"] for d in danh_muc}
    if f["dm"] and (not f["dm"].isdigit() or int(f["dm"]) not in ma_dm):
        errors.append("Danh mục không tồn tại.")

    if not errors:
        # Thủ tục nhận đúng 1 danh mục: chọn "Tất cả" = gọi lần lượt từng danh mục.
        for ma in ([int(f["dm"])] if f["dm"] else sorted(ma_dm)):
            ok, res = call_proc_rows("sp_TimKiemBienTheTheoGiaVaDanhMuc",
                                     (gmin if gmin is not None else Decimal(0), gmax if gmax is not None else GIA_MAX, ma))
            if not ok:
                errors.append(res)
                break
            rows += res

    if rows:
        q = f["q"].casefold()
        rows = [r for r in rows
                if (not q or q in " ".join(str(r[k] or "") for k in ("Tên sản phẩm", "Màu sắc", "Dung lượng", "Kích thước")).casefold())
                and (not f["tt"] or r["Trạng thái khả dụng"] == f["tt"])]
        khoa, giam, _ = SAP_XEP[f["sort"]]
        rows.sort(key=lambda r: ((r[khoa].casefold() if isinstance(r[khoa], str) else r[khoa]), r["Mã biến thể"]), reverse=giam)
        ids = sorted({r["Mã sản phẩm"] for r in rows})
        if ids:
            try:
                with cursor() as cur:
                    cur.execute(
                        "SELECT s.`Mã sản phẩm` AS ma, s.`Mô tả` AS mo_ta, s.`Giá cơ sở` AS gia, s.`Trạng thái kinh doanh` AS tt "
                        "FROM `Sản phẩm` s WHERE s.`Mã sản phẩm` IN (%s)" % ",".join(["%s"] * len(ids)), ids)
                    enrich = {r["ma"]: r for r in cur.fetchall()}
            except pymysql.MySQLError as e:
                errors.append("Lỗi cơ sở dữ liệu: " + db_error_text(e))

    return render_template("bien_the.html", f=f, rows=rows, enrich=enrich, danh_muc=danh_muc, errors=errors,
                           kha_dung=KHA_DUNG, sap_xep=SAP_XEP, trang_thai=TRANG_THAI,
                           so_sp=len({r["Mã sản phẩm"] for r in rows}),
                           next_url=request.full_path.rstrip("?"))


if __name__ == "__main__":
    app.run(debug=True)
