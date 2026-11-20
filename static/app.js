document.querySelectorAll("[data-submit-on-change]").forEach(function (field) {
  field.addEventListener("change", function () {
    if (field.form) field.form.requestSubmit();
  });
});

document.querySelectorAll("[data-open]").forEach(function (b) {
  b.addEventListener("click", function () {
    var d = document.getElementById(b.dataset.open);
    if (!d) return;
    var f = d.querySelector("form");
    if (b.dataset.action) f.action = b.dataset.action;
    ["sao", "nd", "hien"].forEach(function (k) {
      if (b.dataset[k] !== undefined && f.elements[k]) f.elements[k].value = b.dataset[k];
    });
    Object.keys(b.dataset).forEach(function (k) {
      if (/^f[A-Z]/.test(k)) {
        var n = k.slice(1).toLowerCase();
        Array.prototype.forEach.call(f.elements, function (el) { if (el.name && el.name.toLowerCase() === n) el.value = b.dataset[k]; });
      }
    });
    var t = d.querySelector("[data-title]");
    if (t && b.dataset.title) t.textContent = b.dataset.title;
    d.showModal();
  });
});
document.querySelectorAll("[data-close]").forEach(function (b) {
  b.addEventListener("click", function () { b.closest("dialog").close(); });
});
document.querySelectorAll("dialog").forEach(function (d) {
  d.addEventListener("click", function (e) { if (e.target === d) d.close(); });
});
document.querySelectorAll("form[data-confirm]").forEach(function (f) {
  f.addEventListener("submit", function (e) { if (!confirm(f.dataset.confirm)) e.preventDefault(); });
});
var hl = document.querySelector(".score.hl");
if (hl) hl.scrollIntoView({ block: "nearest", behavior: "smooth" });

document.querySelectorAll("dialog[data-autoopen]").forEach(function (d) { d.showModal(); });
