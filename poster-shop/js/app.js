(function () {
  "use strict";

  const SHOP = window.SHOP;
  const $ = (sel, root = document) => root.querySelector(sel);
  const $$ = (sel, root = document) => Array.from(root.querySelectorAll(sel));

  const gsap = window.gsap;
  const ScrollTrigger = window.ScrollTrigger;
  const Flip = window.Flip;
  const reduceQuery = window.matchMedia("(prefers-reduced-motion: reduce)");
  const motion = !!(gsap && ScrollTrigger) && !reduceQuery.matches;
  if (gsap) gsap.registerPlugin(...[ScrollTrigger, Flip].filter(Boolean));
  if (motion) document.documentElement.classList.add("has-motion");

  // ---------- Formatierung ----------
  const money = (n) =>
    new Intl.NumberFormat("de-DE", {
      style: "currency",
      currency: SHOP.currency,
      minimumFractionDigits: n % 1 ? 2 : 0,
      maximumFractionDigits: 2,
    }).format(n);
  const money2 = (n) =>
    new Intl.NumberFormat("de-DE", { style: "currency", currency: SHOP.currency }).format(n);

  const byId = (list, id) => list.find((x) => x.id === id);
  const printById = (id) => byId(SHOP.prints, id);
  const sizeById = (id) => byId(SHOP.sizes, id);
  const materialById = (id) => byId(SHOP.materials, id);
  const priceOf = (sizeId, matId) => SHOP.prices[sizeId][matId];
  const minPrice = Math.min(...SHOP.sizes.flatMap((s) => SHOP.materials.map((m) => priceOf(s.id, m.id))));
  const dims = (size, orientation) =>
    orientation === "landscape" ? { w: size.long, h: size.short } : { w: size.short, h: size.long };
  const sizeLabel = (size, orientation) => {
    const d = dims(size, orientation);
    return `${d.w} × ${d.h} cm`;
  };
  const img = (id, small) => `img/prints/${id}${small ? "-sm" : ""}.jpg`;
  const categoryLabel = (id) => (byId(SHOP.categories, id) || {}).label || id;
  const esc = (s) =>
    String(s).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);

  // ---------- Stammdaten in die Seite schreiben ----------
  $$("[data-brand]").forEach((el) => (el.textContent = SHOP.brand));
  $$("[data-email]").forEach((el) => (el.textContent = SHOP.email));
  $$("[data-email-link]").forEach((el) => (el.href = `mailto:${SHOP.email}`));
  $$("[data-instagram]").forEach((el) => (el.href = SHOP.instagram));
  $$("[data-tax-note]").forEach((el) => (el.textContent = `Zzgl. Versand · ${SHOP.taxNoteShort || SHOP.taxNote}`));
  const shippingText = `Versand nach Deutschland, Österreich und in die Schweiz: ${money2(SHOP.shipping.flat)}, ab ${money(SHOP.shipping.freeFrom)} kostenlos. ${SHOP.taxNote}`;
  $$("[data-shipping-note]").forEach((el) => (el.textContent = shippingText));

  // ---------- Toast ----------
  const toastEl = $("[data-toast]");
  let toastTimer = 0;
  function toast(msg) {
    toastEl.textContent = msg;
    toastEl.classList.add("is-visible");
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => toastEl.classList.remove("is-visible"), 2600);
  }

  // ---------- Galerie ----------
  const grid = $("[data-grid]");
  grid.innerHTML = SHOP.prints
    .map((p) => {
      return `
      <li class="tile" data-id="${p.id}" data-category="${p.category}">
        <button class="tile__hit" type="button" data-open-print="${p.id}" aria-label="${esc(p.title)} ansehen, ab ${money(minPrice)}">
          <div class="tile__wall">
            <div class="tile__poster is-${p.orientation}">
              <img src="${img(p.id, true)}" alt="${esc(p.title)} (${esc(p.catalog)})" width="${p.orientation === "landscape" ? 1000 : 667}" height="${p.orientation === "landscape" ? 667 : 1000}" loading="lazy" decoding="async">
              <div class="mount-caption" aria-hidden="true"><span>${esc(p.title)}</span><span>${esc(p.catalog)}</span></div>
            </div>
          </div>
          <div class="tile__meta">
            <span class="tile__title">${esc(p.title)}</span>
            <span class="tile__price">ab ${money(minPrice)}</span>
            <span class="tile__sub">${esc(p.catalog)} · ${esc(categoryLabel(p.category))}</span>
          </div>
        </button>
      </li>`;
    })
    .join("");

  // Vorschaubilder blenden sanft ein, sobald sie geladen sind
  if (motion) {
    $$(".tile__poster img", grid).forEach((im) => {
      const show = () => im.classList.add("is-loaded");
      if (im.complete && im.naturalWidth) show();
      else {
        im.addEventListener("load", show, { once: true });
        im.addEventListener("error", show, { once: true });
      }
    });
  }

  // Filter
  const filters = $("[data-filters]");
  const counts = SHOP.prints.reduce((acc, p) => ((acc[p.category] = (acc[p.category] || 0) + 1), acc), {});
  const chips = [{ id: "alle", label: "Alle", n: SHOP.prints.length }].concat(
    SHOP.categories.filter((c) => counts[c.id]).map((c) => ({ id: c.id, label: c.label, n: counts[c.id] }))
  );
  filters.innerHTML = chips
    .map(
      (c, i) =>
        `<button class="chip" type="button" data-filter="${c.id}" aria-pressed="${i === 0}">${esc(c.label)}<sup>${c.n}</sup></button>`
    )
    .join("");

  let revealTriggers = [];
  let currentFilter = "alle";

  function setFilter(cat) {
    if (cat === currentFilter) return;
    currentFilter = cat;
    $$("[data-filter]", filters).forEach((b) => b.setAttribute("aria-pressed", String(b.dataset.filter === cat)));
    const tiles = $$(".tile", grid);

    if (revealTriggers.length) {
      revealTriggers.forEach((t) => t.kill());
      revealTriggers = [];
      gsap.set(tiles, { clearProps: "opacity,transform" });
    }

    const state = motion && Flip ? Flip.getState(tiles) : null;
    tiles.forEach((t) => t.classList.toggle("is-out", !(cat === "alle" || t.dataset.category === cat)));
    if (!state) return;

    Flip.from(state, {
      duration: 0.6,
      ease: "power3.inOut",
      absolute: true,
      stagger: 0.012,
      onEnter: (els) =>
        gsap.fromTo(els, { opacity: 0, scale: 0.94, y: 16 }, { opacity: 1, scale: 1, y: 0, duration: 0.55, delay: 0.12, ease: "power3.out" }),
      onLeave: (els) => gsap.to(els, { opacity: 0, scale: 0.94, duration: 0.28, ease: "power2.in" }),
      onComplete: () => ScrollTrigger.refresh(),
    });
  }
  filters.addEventListener("click", (e) => {
    const b = e.target.closest("[data-filter]");
    if (b) setFilter(b.dataset.filter);
  });

  // ---------- Preistabelle ----------
  $("[data-price-table]").innerHTML = `
    <thead><tr><th scope="col">Format</th>${SHOP.materials
      .map((m) => `<th scope="col">${esc(m.label)}<small>${esc(m.note)}</small></th>`)
      .join("")}</tr></thead>
    <tbody>${SHOP.sizes
      .map(
        (s) =>
          `<tr><th scope="row">${s.short} × ${s.long} cm<span>${esc(s.hint || "")}</span></th>${SHOP.materials
            .map((m) => `<td>${money(priceOf(s.id, m.id))}</td>`)
            .join("")}</tr>`
      )
      .join("")}</tbody>`;

  // ---------- Dialog-Helfer ----------
  const html = document.documentElement;
  function lock() { html.classList.add("is-locked"); }
  function unlock() { if (!$("dialog[open]")) html.classList.remove("is-locked"); }

  function openDialog(dlg, panel, from) {
    dlg.classList.remove("is-closing");
    if (!dlg.open) dlg.showModal();
    lock();
    if (motion) gsap.fromTo(panel, from, { opacity: 1, x: 0, y: 0, scale: 1, duration: from.x ? 0.5 : 0.42, ease: from.x ? "expo.out" : "power3.out", overwrite: true });
  }
  function closeDialog(dlg, panel, to) {
    return new Promise((resolve) => {
      if (!dlg.open) return resolve();
      const done = () => {
        dlg.close();
        dlg.classList.remove("is-closing");
        if (gsap) gsap.set(panel, { clearProps: "all" });
        unlock();
        resolve();
      };
      if (!motion) return done();
      dlg.classList.add("is-closing");
      gsap.to(panel, Object.assign({ duration: 0.22, ease: "power2.in", overwrite: true, onComplete: done }, to));
    });
  }
  function wireDialog(dlg, close) {
    dlg.addEventListener("cancel", (e) => { e.preventDefault(); close(); });
    dlg.addEventListener("click", (e) => {
      if (e.target === dlg) return close();
      const c = e.target.closest("[data-close]");
      if (!c) return;
      e.preventDefault();
      const href = c.getAttribute("href");
      close().then(() => {
        if (href && href.startsWith("#")) document.querySelector(href).scrollIntoView({ behavior: motion ? "smooth" : "auto" });
      });
    });
  }

  // ---------- Produkt-Dialog ----------
  const sheet = $("[data-product]");
  const sheetPanel = $(".sheet__panel", sheet);
  const form = $("[data-product-form]");
  const view = $(".product__view", sheet);
  const productImg = $("[data-product-img]");
  const zoomBtn = $("[data-zoom]");
  const roomPoster = $("[data-room-poster]");
  const roomImg = $("[data-room-img]");
  const sel = { print: null, size: "40x60", material: "papier" };

  // Verlauf: Jeder geöffnete Print bekommt einen eigenen Link (#print-…),
  // die Zurück-Taste am Handy schließt dann die Detailansicht statt die Seite.
  const HKEY = "lichtjahrPrint";
  let pushedState = false;
  let ignorePop = false;
  const safely = (fn) => { try { fn(); } catch (_) { /* z. B. in einer Sandbox ohne History-API */ } };
  const printUrl = (id) => `${location.pathname}${location.search}#print-${id}`;
  function pushPrintState(id) { safely(() => { history.pushState({ [HKEY]: id }, "", printUrl(id)); pushedState = true; }); }
  function replacePrintState(id) { safely(() => history.replaceState({ [HKEY]: id }, "", printUrl(id))); }
  function leavePrintState() {
    if (pushedState) {
      pushedState = false;
      ignorePop = true;
      safely(() => history.back());
    } else if (location.hash.startsWith("#print-")) {
      safely(() => history.replaceState(null, "", location.pathname + location.search));
    }
  }

  let sheetClosing = null;
  function closeSheet(opts = {}) {
    if (sheetClosing) return sheetClosing;
    if (!sheet.open) return Promise.resolve();
    if (!opts.fromHistory) leavePrintState();
    const p = sel.print;
    sheetClosing = closeDialog(sheet, sheetPanel, { opacity: 0, y: 12, scale: 0.985 }).then(() => {
      sheetClosing = null;
      setZoom(false);
      focusTile(p);
    });
    return sheetClosing;
  }
  wireDialog(sheet, () => closeSheet());

  // Nach dem Schließen landet der Fokus auf der Kachel des zuletzt angesehenen Prints
  function focusTile(p) {
    const hit = p && grid.querySelector(`[data-open-print="${p.id}"]`);
    if (!hit || hit.closest(".tile").classList.contains("is-out")) return;
    hit.focus({ preventScroll: true });
    const r = hit.getBoundingClientRect();
    if (r.bottom < 0 || r.top > window.innerHeight) hit.scrollIntoView({ block: "center" });
  }

  function setTab(name) {
    $$("[data-tab]", sheet).forEach((t) => t.setAttribute("aria-selected", String(t.dataset.tab === name)));
    $$("[data-pane]", sheet).forEach((p) => {
      const on = p.dataset.pane === name;
      p.hidden = !on;
      if (on && motion) gsap.fromTo(p, { opacity: 0 }, { opacity: 1, duration: 0.3, ease: "power1.out" });
    });
    if (name !== "motiv") setZoom(false);
  }
  $(".tabs", sheet).addEventListener("click", (e) => {
    const t = e.target.closest("[data-tab]");
    if (t) setTab(t.dataset.tab);
  });
  $(".tabs", sheet).addEventListener("keydown", (e) => {
    if (e.key !== "ArrowLeft" && e.key !== "ArrowRight") return;
    e.stopPropagation();
    const tabs = $$("[data-tab]", sheet);
    const i = tabs.findIndex((t) => t.getAttribute("aria-selected") === "true");
    const next = tabs[(i + (e.key === "ArrowRight" ? 1 : tabs.length - 1)) % tabs.length];
    setTab(next.dataset.tab);
    next.focus();
  });

  function renderOptions() {
    const p = sel.print;
    $("[data-size-options]").innerHTML = SHOP.sizes
      .map(
        (s) => `<label class="opt"><input type="radio" name="size" value="${s.id}" ${s.id === sel.size ? "checked" : ""}><span>${sizeLabel(s, p.orientation).replace(" cm", "")}</span></label>`
      )
      .join("");
    $("[data-material-options]").innerHTML = SHOP.materials
      .map(
        (m) => `<label class="opt"><input type="radio" name="material" value="${m.id}" ${m.id === sel.material ? "checked" : ""}><span><b>${esc(m.label)}<i class="opt__price" data-mat-price="${m.id}"></i></b><small>${esc(m.note)}</small></span></label>`
      )
      .join("");
  }

  function updateProduct() {
    const p = sel.print;
    const size = sizeById(sel.size);
    $("[data-product-price]").textContent = money(priceOf(sel.size, sel.material));
    $$("[data-mat-price]", sheet).forEach((el) => (el.textContent = money(priceOf(sel.size, el.dataset.matPrice))));
    // Raumansicht: Wand = 360 × 270 cm
    const d = dims(size, p.orientation);
    roomPoster.style.width = `${(d.w / 360) * 100}%`;
    roomPoster.style.height = `${(d.h / 270) * 100}%`;
    roomPoster.style.padding = sel.material === "papier" ? `${(2 / 360) * 100}%` : "0";
    roomPoster.dataset.material = sel.material;
  }

  form.addEventListener("change", (e) => {
    if (e.target.name === "size") sel.size = e.target.value;
    if (e.target.name === "material") sel.material = e.target.value;
    updateProduct();
  });

  // Blättern bezieht sich auf die gerade gefilterten Prints
  function browseList() {
    const list = SHOP.prints.filter((p) => currentFilter === "alle" || p.category === currentFilter);
    return sel.print && !list.includes(sel.print) ? SHOP.prints : list;
  }

  function fillPrint(p) {
    sel.print = p;
    $("[data-product-eyebrow]").textContent = `${p.catalog} · ${categoryLabel(p.category)}`;
    $("[data-product-title]").textContent = p.title;
    $("[data-product-light]").textContent = p.light ? `Das Licht in diesem Bild war ${p.light} unterwegs.` : "";
    $("[data-product-text]").textContent = p.text;
    $("[data-product-specs]").innerHTML = p.data.map(([k, v]) => `<div><dt>${esc(k)}</dt><dd>${esc(v)}</dd></div>`).join("");

    setZoom(false);
    productImg.alt = `${p.title} (${p.catalog}), ${p.coords}`;
    zoomBtn.setAttribute("aria-label", `${p.title} vergrößern`);
    productImg.src = img(p.id, true);
    const full = new Image();
    full.onload = () => { if (sel.print === p) productImg.src = full.src; };
    full.src = img(p.id, false);
    roomImg.src = img(p.id, true);
    roomImg.alt = `${p.title} als Poster über einem Sofa`;

    renderOptions();
    updateProduct();
    const list = browseList();
    $("[data-pager-count]").textContent = `${list.indexOf(p) + 1} / ${list.length}`;
    $$("[data-step-print]", sheet).forEach((b) => (b.disabled = list.length < 2));
  }

  function openPrint(id, opts = {}) {
    const p = printById(id);
    if (!p) return;
    fillPrint(p);
    setTab("motiv");
    sheetPanel.scrollTop = 0;
    if (opts.history === "push") pushPrintState(p.id);
    if (opts.history === "replace") replacePrintState(p.id);
    openDialog(sheet, sheetPanel, { opacity: 0, y: 28, scale: 0.985 });
  }

  function stepPrint(dir) {
    const list = browseList();
    if (list.length < 2) return;
    const i = Math.max(0, list.indexOf(sel.print));
    const next = list[(i + dir + list.length) % list.length];
    fillPrint(next);
    replacePrintState(next.id);
    if (!motion) return;
    gsap.fromTo([productImg, roomImg], { opacity: 0 }, { opacity: 1, duration: 0.4, ease: "power1.out" });
    gsap.fromTo(
      $$("[data-product-eyebrow], [data-product-title], [data-product-light], [data-product-text], [data-product-specs]", sheet),
      { opacity: 0, x: 14 * dir },
      { opacity: 1, x: 0, duration: 0.42, stagger: 0.025, ease: "power3.out", clearProps: "transform" }
    );
  }

  sheet.addEventListener("click", (e) => {
    const b = e.target.closest("[data-step-print]");
    if (b) stepPrint(+b.dataset.stepPrint);
  });
  sheet.addEventListener("keydown", (e) => {
    if (e.key === "Escape" && zoomed) {
      e.preventDefault();
      setZoom(false);
      return;
    }
    if (e.key !== "ArrowLeft" && e.key !== "ArrowRight") return;
    if (e.target.closest("input, select, textarea")) return;
    e.preventDefault();
    stepPrint(e.key === "ArrowRight" ? 1 : -1);
  });

  // Wischen auf dem Bild blättert weiter (nur Touch, nicht im Zoom)
  let swipe = null;
  view.addEventListener("pointerdown", (e) => {
    swipe = e.pointerType !== "mouse" && !zoomed ? { x: e.clientX, y: e.clientY } : null;
  });
  view.addEventListener("pointerup", (e) => {
    if (!swipe || zoomed) return (swipe = null);
    const dx = e.clientX - swipe.x;
    const dy = e.clientY - swipe.y;
    swipe = null;
    if (Math.abs(dx) > 50 && Math.abs(dx) > Math.abs(dy) * 1.5) stepPrint(dx < 0 ? 1 : -1);
  });
  view.addEventListener("pointercancel", () => (swipe = null));

  // ---------- Zoom in die volle Auflösung ----------
  let zoomed = false;
  let drag = null;
  const clamp = (n) => Math.min(100, Math.max(0, n));

  function zoomScale() {
    const box = zoomBtn.getBoundingClientRect();
    const cs = getComputedStyle(productImg);
    const bw = box.width - parseFloat(cs.paddingLeft) - parseFloat(cs.paddingRight);
    const bh = box.height - parseFloat(cs.paddingTop) - parseFloat(cs.paddingBottom);
    const ratio = sel.print.orientation === "landscape" ? 1.5 : 2 / 3;
    const shown = Math.min(bw, bh * ratio);
    const natural = productImg.naturalWidth || 2000;
    return Math.min(3, Math.max(1.8, natural / shown));
  }
  function setOrigin(x, y) {
    productImg.style.setProperty("--zx", `${x}%`);
    productImg.style.setProperty("--zy", `${y}%`);
  }
  function originAt(e) {
    const r = zoomBtn.getBoundingClientRect();
    return [clamp(((e.clientX - r.left) / r.width) * 100), clamp(((e.clientY - r.top) / r.height) * 100)];
  }
  function setZoom(on, e) {
    if (on && !sel.print) return;
    if (on) {
      productImg.style.setProperty("--zs", zoomScale().toFixed(2));
      if (e) setOrigin(...originAt(e)); else setOrigin(50, 50);
    }
    zoomed = on;
    zoomBtn.classList.toggle("is-zoomed", on);
    zoomBtn.setAttribute("aria-pressed", String(on));
  }

  zoomBtn.addEventListener("pointerdown", (e) => {
    const zx = parseFloat(productImg.style.getPropertyValue("--zx")) || 50;
    const zy = parseFloat(productImg.style.getPropertyValue("--zy")) || 50;
    drag = { x: e.clientX, y: e.clientY, zx, zy, moved: false };
    if (zoomed && e.pointerType !== "mouse") zoomBtn.setPointerCapture(e.pointerId);
  });
  zoomBtn.addEventListener("pointermove", (e) => {
    if (drag && Math.hypot(e.clientX - drag.x, e.clientY - drag.y) > 8) drag.moved = true;
    if (!zoomed) return;
    if (e.pointerType === "mouse") return setOrigin(...originAt(e));
    if (!drag) return;
    // Touch: Bild mit dem Finger verschieben
    const r = zoomBtn.getBoundingClientRect();
    setOrigin(clamp(drag.zx - ((e.clientX - drag.x) / r.width) * 140), clamp(drag.zy - ((e.clientY - drag.y) / r.height) * 140));
  });
  zoomBtn.addEventListener("pointerup", (e) => {
    const d = drag;
    drag = null;
    if (d && d.moved) return;
    setZoom(!zoomed, e);
  });
  zoomBtn.addEventListener("pointercancel", () => (drag = null));
  zoomBtn.addEventListener("click", (e) => { if (e.detail === 0) setZoom(!zoomed); }); // Enter/Leertaste

  grid.addEventListener("click", (e) => {
    const b = e.target.closest("[data-open-print]");
    if (b) openPrint(b.dataset.openPrint, { history: "push" });
  });

  window.addEventListener("popstate", (e) => {
    if (ignorePop) { ignorePop = false; return; }
    const fromHash = location.hash.match(/^#print-(.+)$/);
    const id = (e.state && e.state[HKEY]) || (fromHash && fromHash[1]);
    if (id && printById(id)) {
      if (sheet.open) fillPrint(printById(id));
      else { pushedState = true; openPrint(id); }
    } else if (sheet.open) {
      pushedState = false;
      closeSheet({ fromHistory: true });
    }
  });

  // ---------- Warenkorb ----------
  const KEY = "lichtjahr-cart-v1";
  let cart = [];
  try { cart = JSON.parse(localStorage.getItem(KEY) || "[]").filter((i) => printById(i.id) && sizeById(i.size) && materialById(i.material)); } catch (_) { cart = []; }
  const save = () => { try { localStorage.setItem(KEY, JSON.stringify(cart)); } catch (_) { /* privat/gesperrt: Warenkorb lebt nur in dieser Sitzung */ } };

  const lineTotal = (i) => priceOf(i.size, i.material) * i.qty;
  const subtotal = () => cart.reduce((s, i) => s + lineTotal(i), 0);
  const shipping = () => (cart.length === 0 || subtotal() >= SHOP.shipping.freeFrom ? 0 : SHOP.shipping.flat);
  const count = () => cart.reduce((s, i) => s + i.qty, 0);

  const drawer = $("[data-cart]");
  const drawerPanel = $(".drawer__panel", drawer);
  const cartBtn = $("[data-open-cart]");
  const countEl = $("[data-cart-count]");

  function renderCart() {
    const n = count();
    countEl.textContent = n;
    cartBtn.classList.toggle("has-items", n > 0);
    cartBtn.setAttribute("aria-label", n ? `Warenkorb öffnen, ${n} ${n === 1 ? "Print" : "Prints"}` : "Warenkorb öffnen, leer");

    $("[data-cart-list]").innerHTML = cart
      .map((i, idx) => {
        const p = printById(i.id);
        return `<li class="cart-item">
          <div class="cart-item__thumb ${p.orientation === "landscape" ? "is-landscape" : ""}"><img src="${img(p.id, true)}" alt=""></div>
          <div>
            <div class="cart-item__title">${esc(p.title)}</div>
            <div class="cart-item__opts">${sizeLabel(sizeById(i.size), p.orientation)} · ${esc(materialById(i.material).label)}</div>
          </div>
          <div class="cart-item__price">${money2(lineTotal(i))}</div>
          <div class="cart-item__row">
            <div class="qty" role="group" aria-label="Anzahl ${esc(p.title)}">
              <button type="button" data-qty="-1" data-idx="${idx}" aria-label="Eins weniger">−</button>
              <output aria-live="polite">${i.qty}</output>
              <button type="button" data-qty="1" data-idx="${idx}" aria-label="Eins mehr">+</button>
            </div>
            <button class="remove" type="button" data-remove="${idx}">Entfernen</button>
          </div>
        </li>`;
      })
      .join("");

    const empty = cart.length === 0;
    $("[data-cart-empty]").hidden = !empty;
    $("[data-cart-foot]").hidden = empty;
    $("[data-subtotal]").textContent = money2(subtotal());
    $("[data-shipping]").textContent = shipping() ? money2(shipping()) : "kostenlos";
    $("[data-total]").textContent = money2(subtotal() + shipping());
    $("[data-total-2]").textContent = money2(subtotal() + shipping());
    const missing = SHOP.shipping.freeFrom - subtotal();
    $("[data-free-hint]").textContent = missing > 0 ? `Noch ${money2(missing)} bis zum kostenlosen Versand.` : "Der Versand ist kostenlos.";
  }

  $("[data-cart-list]").addEventListener("click", (e) => {
    const q = e.target.closest("[data-qty]");
    const r = e.target.closest("[data-remove]");
    if (q) {
      const i = cart[+q.dataset.idx];
      i.qty = Math.max(0, Math.min(20, i.qty + +q.dataset.qty));
      if (i.qty === 0) cart.splice(+q.dataset.idx, 1);
    } else if (r) {
      cart.splice(+r.dataset.remove, 1);
    } else return;
    save();
    renderCart();
  });

  function showStep(name) {
    $$("[data-step]", drawer).forEach((s) => (s.hidden = s.dataset.step !== name));
    $("[data-cart-title]").textContent = name === "checkout" ? "Bestellung" : name === "done" ? "Danke" : "Warenkorb";
    drawerPanel.scrollTop = 0;
    if (motion) gsap.fromTo($(`[data-step="${name}"]`, drawer), { opacity: 0, x: 16 }, { opacity: 1, x: 0, duration: 0.35, ease: "power3.out" });
  }

  const closeDrawer = () => closeDialog(drawer, drawerPanel, { x: "100%", duration: 0.28 });
  wireDialog(drawer, closeDrawer);

  function openCart() {
    renderCart();
    showStep("cart");
    openDialog(drawer, drawerPanel, { x: "100%", opacity: 1 });
  }
  cartBtn.addEventListener("click", openCart);
  $("[data-to-checkout]").addEventListener("click", () => showStep("checkout"));
  $("[data-back]").addEventListener("click", () => showStep("cart"));

  function bumpCount() {
    if (!motion) return;
    gsap.fromTo(countEl, { scale: 1 }, { scale: 1.35, duration: 0.16, ease: "power2.out", yoyo: true, repeat: 1 });
  }

  // Thumbnail fliegt vom Bild in den Warenkorb
  function flyToCart(fromRect, src) {
    if (!motion || !fromRect.width) return bumpCount();
    const to = cartBtn.getBoundingClientRect();
    const fly = document.createElement("figure");
    fly.className = "fly";
    fly.innerHTML = `<img src="${src}" alt="">`;
    Object.assign(fly.style, { left: `${fromRect.left}px`, top: `${fromRect.top}px`, width: `${fromRect.width}px`, height: `${fromRect.height}px` });
    document.body.appendChild(fly);
    const dx = to.left + to.width / 2 - (fromRect.left + fromRect.width / 2);
    const dy = to.top + to.height / 2 - (fromRect.top + fromRect.height / 2);
    const s = Math.max(0.06, 40 / Math.max(fromRect.width, fromRect.height));
    gsap.timeline({ onComplete: () => { fly.remove(); bumpCount(); } })
      .to(fly, { x: dx, duration: 0.7, ease: "power2.inOut" }, 0)
      .to(fly, { y: dy, duration: 0.7, ease: "back.in(1.2)" }, 0)
      .to(fly, { scale: s, rotation: -6, duration: 0.7, ease: "power3.in" }, 0)
      .to(fly, { opacity: 0, duration: 0.12 }, 0.6);
  }

  function visibleImageRect() {
    const wall = !$('[data-pane="wand"]', sheet).hidden;
    if (wall) return roomPoster.getBoundingClientRect();
    const r = productImg.getBoundingClientRect();
    const ratio = sel.print.orientation === "landscape" ? 1.5 : 2 / 3;
    let w = r.width, h = r.height;
    if (w / h > ratio) w = h * ratio; else h = w / ratio;
    return { left: r.left + (r.width - w) / 2, top: r.top + (r.height - h) / 2, width: w, height: h };
  }

  form.addEventListener("submit", (e) => {
    e.preventDefault();
    const p = sel.print;
    const existing = cart.find((i) => i.id === p.id && i.size === sel.size && i.material === sel.material);
    if (existing) existing.qty = Math.min(20, existing.qty + 1);
    else cart.push({ id: p.id, size: sel.size, material: sel.material, qty: 1 });
    save();
    renderCart();
    const rect = visibleImageRect();
    closeSheet().then(() => {
      flyToCart(rect, img(p.id, true));
      toast(`${p.title} liegt im Warenkorb`);
    });
  });

  // ---------- Bestellanfrage ----------
  const checkout = $("[data-checkout]");
  const errorEl = $("[data-form-error]");
  let lastOrderText = "";

  function orderText(data) {
    const lines = [];
    lines.push(`Bestellanfrage über ${SHOP.brand}`, "".padEnd(32, "-"));
    cart.forEach((i) => {
      const p = printById(i.id);
      lines.push(`${i.qty} × ${p.title} (${p.catalog})`);
      lines.push(`    ${sizeLabel(sizeById(i.size), p.orientation)} · ${materialById(i.material).label} · ${money2(lineTotal(i))}`);
    });
    lines.push("", `Zwischensumme: ${money2(subtotal())}`, `Versand: ${shipping() ? money2(shipping()) : "kostenlos"}`, `Gesamt: ${money2(subtotal() + shipping())}`);
    lines.push("", "Lieferadresse:", data.name, data.street, `${data.zip} ${data.city}`, data.country, "", `E-Mail: ${data.email}`);
    if (data.note) lines.push("", "Nachricht:", data.note);
    return lines.join("\n");
  }

  function validate() {
    let firstBad = null;
    $$("input[required]", checkout).forEach((el) => {
      const ok = el.type === "checkbox" ? el.checked : el.value.trim() && el.checkValidity();
      el.setAttribute("aria-invalid", String(!ok));
      if (!ok && !firstBad) firstBad = el;
    });
    if (!firstBad) { errorEl.hidden = true; return true; }
    errorEl.textContent =
      firstBad.type === "checkbox"
        ? "Bitte bestätige, dass du Widerrufsbelehrung und Datenschutz gelesen hast."
        : firstBad.type === "email" && firstBad.value
          ? "Die E-Mail-Adresse sieht unvollständig aus. Prüf sie bitte noch einmal."
          : "Bitte füll alle Pflichtfelder aus, damit ich weiß, wohin der Print soll.";
    errorEl.hidden = false;
    firstBad.focus();
    return false;
  }
  checkout.addEventListener("input", (e) => {
    if (e.target.getAttribute("aria-invalid") === "true") e.target.removeAttribute("aria-invalid");
    errorEl.hidden = true;
  });

  checkout.addEventListener("submit", async (e) => {
    e.preventDefault();
    if (!cart.length || !validate()) return;
    const data = Object.fromEntries(new FormData(checkout).entries());
    const text = orderText(data);
    const sendBtn = $("[data-send]");

    if (SHOP.orderEndpoint) {
      sendBtn.disabled = true;
      sendBtn.textContent = "Wird gesendet …";
      try {
        const res = await fetch(SHOP.orderEndpoint, {
          method: "POST",
          headers: { "Content-Type": "application/json", Accept: "application/json" },
          body: JSON.stringify({ _subject: `Bestellanfrage ${SHOP.brand}`, email: data.email, name: data.name, bestellung: text }),
        });
        if (!res.ok) throw new Error(String(res.status));
        finish(text, true, data.email);
      } catch (_) {
        errorEl.textContent = `Die Anfrage ist nicht angekommen. Prüf deine Verbindung und versuch es noch einmal, oder schreib direkt an ${SHOP.email}.`;
        errorEl.hidden = false;
      } finally {
        sendBtn.disabled = false;
        sendBtn.textContent = "Bestellung anfragen";
      }
      return;
    }

    // Ohne Endpunkt: fertige E-Mail im Mailprogramm öffnen
    const mailto = `mailto:${SHOP.email}?subject=${encodeURIComponent(`Bestellanfrage ${SHOP.brand}`)}&body=${encodeURIComponent(text)}`;
    finish(text, false, data.email);
    window.location.href = mailto;
  });

  function finish(text, sent, email) {
    lastOrderText = text;
    $("[data-done-order]").textContent = text;
    if (sent) {
      $("[data-done-eyebrow]").textContent = "Anfrage gesendet";
      $("[data-done-title]").textContent = "Danke, ist angekommen";
      $("[data-done-text]").textContent = `Ich melde mich innerhalb von 24 Stunden bei ${email} mit den Zahlungsinfos.`;
    } else {
      $("[data-done-eyebrow]").textContent = "Anfrage vorbereitet";
      $("[data-done-title]").textContent = "Jetzt nur noch absenden";
      $("[data-done-text]").textContent = `Dein Mailprogramm öffnet sich mit der fertigen Bestellung an ${SHOP.email}. Schick die Mail ab, dann melde ich mich mit den Zahlungsinfos. Falls sich nichts öffnet, kopier die Bestellung und schick sie selbst.`;
    }
    cart = [];
    save();
    renderCart();
    checkout.reset();
    showStep("done");
  }

  $("[data-copy-order]").addEventListener("click", () => {
    const pre = $("[data-done-order]");
    const fallback = () => {
      const range = document.createRange();
      range.selectNodeContents(pre);
      const s = window.getSelection();
      s.removeAllRanges();
      s.addRange(range);
      toast("Bestellung markiert, jetzt kopieren");
    };
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(lastOrderText).then(() => toast("Bestellung kopiert"), fallback);
    } else fallback();
  });

  renderCart();

  // ---------- Navigation ----------
  const nav = $("[data-nav]");
  let navTick = false;
  const updateNav = () => { nav.classList.toggle("is-solid", window.scrollY > 60); navTick = false; };
  window.addEventListener("scroll", () => { if (!navTick) { navTick = true; requestAnimationFrame(updateNav); } }, { passive: true });
  updateNav();

  // ---------- Hero: Scrollen = Belichtung ----------
  const Sky = window.Sky;
  const expoEl = $("[data-exposure]");
  const rotEl = $("[data-rotation]");
  const hint = $("[data-hero-hint]");
  const MAX_EXPOSURE = 1.36; // rad, ~78° bzw. 5 h 12 min
  const heroState = { intro: 0, scroll: 0 };

  function pad(n) { return String(n).padStart(2, "0"); }
  function setExposure(rad) {
    if (!Sky) return;
    Sky.state.exposure = rad;
    const deg = (rad * 180) / Math.PI;
    const secs = Math.round((deg / 15) * 3600);
    expoEl.textContent = `${pad(Math.floor(secs / 3600))}:${pad(Math.floor((secs % 3600) / 60))}:${pad(secs % 60)}`;
    rotEl.textContent = `${deg.toFixed(1).replace(".", ",")}°`;
    if (!motion) Sky.draw();
  }
  function heroUpdate() {
    const start = 0.004 + 0.09 * heroState.intro;
    const t = heroState.scroll;
    const eased = t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2;
    setExposure(start + (MAX_EXPOSURE - start) * eased);
  }

  if (!motion) {
    setExposure(MAX_EXPOSURE * 0.75);
  } else {
    // Auftakt: Verschluss öffnet sich, Text steigt ein
    const tl = gsap.timeline({ defaults: { ease: "power4.out" } });
    tl.from(nav, { y: -20, opacity: 0, duration: 0.8 }, 0.1)
      .from(".hero__title .line > span", { yPercent: 110, duration: 1.2, stagger: 0.09 }, 0.15)
      .from(".hero__copy .eyebrow, .hero__lede, .hero__actions", { y: 18, opacity: 0, duration: 1, stagger: 0.08 }, 0.35)
      .from(".hero__readout", { opacity: 0, duration: 0.8 }, 0.6)
      .to(heroState, { intro: 1, duration: 2.6, ease: "power2.out", onUpdate: heroUpdate }, 0);

    gsap.to(heroState, {
      scroll: 1,
      ease: "none",
      onUpdate: heroUpdate,
      scrollTrigger: { trigger: "[data-hero]", start: "top top", end: "bottom bottom", scrub: 0.6 },
    });
    ScrollTrigger.create({
      trigger: "[data-hero]",
      start: "top top-=40",
      onEnter: () => gsap.to(hint, { opacity: 0, duration: 0.3 }),
      onLeaveBack: () => gsap.to(hint, { opacity: 1, duration: 0.3 }),
    });
  }

  // ---------- Galerie-Einblendung ----------
  if (motion) {
    const tiles = $$(".tile", grid);
    gsap.set(tiles, { opacity: 0, y: 48 });
    revealTriggers = ScrollTrigger.batch(tiles, {
      start: "top 92%",
      once: true,
      onEnter: (batch) => gsap.to(batch, { opacity: 1, y: 0, duration: 1, stagger: 0.08, ease: "power3.out", overwrite: true }),
    });

    $$(".section-head, .about__text, .gear, .faq__list, .table-scroll").forEach((el) => {
      gsap.from(el, { y: 32, opacity: 0, duration: 1, ease: "power3.out", scrollTrigger: { trigger: el, start: "top 88%", once: true } });
    });
  }

  // ---------- Vom Bild zur Wand ----------
  if (motion) {
    const wall = $("[data-wall]");
    const stage = $(".wall__stage", wall);
    const slot = $("[data-wall-slot]", wall);
    const poster = $("[data-wall-poster]", wall);
    const room = $("[data-wall-room]", wall);
    const sofa = $("[data-wall-sofa]", wall);
    const caption = $("[data-wall-caption]", wall);
    const title = $(".wall__title", wall);
    const points = $$(".wall__points > div", wall);
    poster.classList.add("is-driven");

    const target = () => {
      const s = stage.getBoundingClientRect();
      const r = slot.getBoundingClientRect();
      return { left: r.left - s.left, top: r.top - s.top, width: r.width, height: r.height };
    };

    const mm = gsap.matchMedia();
    mm.add({ wide: "(min-width: 861px)", narrow: "(max-width: 860px)" }, (ctx) => {
      const tl = gsap.timeline({
        scrollTrigger: { trigger: wall, start: "top top", end: "bottom bottom", scrub: 0.6, invalidateOnRefresh: true },
      });
      tl.fromTo(
        poster,
        { left: 0, top: 0, width: () => stage.clientWidth, height: () => stage.clientHeight, "--pad-k": 0 },
        {
          left: () => target().left,
          top: () => target().top,
          width: () => target().width,
          height: () => target().height,
          "--pad-k": 1,
          ease: "power2.inOut",
          duration: 1,
        },
        0
      )
        .fromTo(room, { opacity: 0 }, { opacity: 1, duration: 0.6, ease: "none" }, 0.3)
        .fromTo(sofa, { y: 24, opacity: 0 }, { y: 0, opacity: 1, duration: 0.45, ease: "power2.out" }, 0.55)
        .fromTo(caption, { opacity: 0 }, { opacity: 1, duration: 0.3 }, 0.75)
        .fromTo(title, { opacity: 0, y: 24 }, { opacity: 1, y: 0, duration: 0.35, ease: "power2.out" }, 0.95);

      if (ctx.conditions.wide) {
        gsap.set(points, { opacity: 0, y: 24 });
        tl.to(points, { opacity: 1, y: 0, duration: 0.3, stagger: 0.18, ease: "power2.out" }, 1.1);
        tl.to({}, { duration: 0.5 });
      } else {
        gsap.set(points, { opacity: 0, y: 16 });
        points.forEach((pt, i) => {
          const at = 1.15 + i * 0.55;
          tl.to(pt, { opacity: 1, y: 0, duration: 0.18, ease: "power2.out" }, at);
          if (i < points.length - 1) tl.to(pt, { opacity: 0, y: -16, duration: 0.14, ease: "power2.in" }, at + 0.36);
        });
        tl.to({}, { duration: 0.35 });
      }
    });
  }

  // Bilder können die Höhe ändern: danach die Trigger neu vermessen
  window.addEventListener("load", () => { if (ScrollTrigger) ScrollTrigger.refresh(); });

  // Prints per Link öffnen, z. B. index.html#print-m42-orionnebel
  const deep = location.hash.match(/^#print-(.+)$/);
  if (deep && printById(deep[1])) openPrint(deep[1], { history: "replace" });
})();
