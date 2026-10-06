(function () {
  "use strict";

  const SHOP = window.SHOP;
  const $ = (sel, root = document) => root.querySelector(sel);
  const $$ = (sel, root = document) => Array.from(root.querySelectorAll(sel));

  const gsap = window.gsap;
  const ScrollTrigger = window.ScrollTrigger;
  const Flip = window.Flip;
  const CustomEase = window.CustomEase;
  const reduceQuery = window.matchMedia("(prefers-reduced-motion: reduce)");
  const motion = !!(gsap && ScrollTrigger) && !reduceQuery.matches;
  if (gsap) gsap.registerPlugin(...[ScrollTrigger, Flip, CustomEase].filter(Boolean));
  // dieselben Kurven wie im CSS (--ease-out, --ease-drawer)
  if (gsap && CustomEase) {
    CustomEase.create("out", "0.23,1,0.32,1");
    CustomEase.create("drawer", "0.32,0.72,0,1");
  }
  const EASE_OUT = gsap && CustomEase ? "out" : "expo.out";
  const EASE_DRAWER = gsap && CustomEase ? "drawer" : "expo.out";
  if (motion) document.documentElement.classList.add("has-motion");
  // Für Dialoge, Tabs und Warenkorb live prüfen: ein Umschalten im System wirkt sofort
  const liveMotion = () => !!gsap && !reduceQuery.matches;

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
    // über einem offenen Dialog sichtbar: als Popover neu in den Top Layer holen
    if (typeof toastEl.showPopover === "function") {
      try {
        toastEl.classList.remove("is-visible");
        if (toastEl.matches(":popover-open")) toastEl.hidePopover();
        toastEl.showPopover();
        void toastEl.offsetWidth;
      } catch (_) { /* ohne Popover-API bleibt es beim normalen Toast */ }
    }
    if (typeof announce === "function") announce(msg);
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

    const state = liveMotion() && Flip ? Flip.getState(tiles) : null;
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

  function openDialog(dlg, panel, from, opts = {}) {
    finishFlights();
    hideArrival(true);
    dlg.classList.remove("is-closing");
    if (!dlg.open) dlg.showModal();
    lock();
    if (liveMotion()) {
      gsap.fromTo(panel, from, {
        opacity: 1, x: 0, y: 0, scale: 1,
        duration: opts.duration || (from.x ? 0.5 : 0.42),
        ease: opts.ease || (from.x ? "expo.out" : "power3.out"),
        overwrite: true,
      });
    }
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
      if (!liveMotion()) return done();
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
        if (href && href.startsWith("#")) document.querySelector(href).scrollIntoView({ behavior: liveMotion() ? "smooth" : "auto" });
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
    sheetClosing = closeDialog(sheet, sheetPanel, Object.assign({ opacity: 0, y: 12, scale: 0.985 }, opts.to)).then(() => {
      sheetClosing = null;
      $("[data-sheet-status]").textContent = "";
      setZoom(false);
      focusTile(p, opts.scrollToTile !== false);
    });
    return sheetClosing;
  }
  wireDialog(sheet, () => closeSheet());

  // Nach dem Schließen landet der Fokus auf der Kachel des zuletzt angesehenen Prints
  // Nach dem Hinzufügen nicht scrollen: Ein Seitensprung unter dem fliegenden Stern
  // wirkt unruhig und würde die Ankunftskarte sofort wieder schließen.
  function focusTile(p, scroll = true) {
    const hit = p && grid.querySelector(`[data-open-print="${p.id}"]`);
    if (!hit || hit.closest(".tile").classList.contains("is-out")) return;
    hit.focus({ preventScroll: true });
    if (!scroll) return;
    const r = hit.getBoundingClientRect();
    if (r.bottom < 0 || r.top > window.innerHeight) hit.scrollIntoView({ block: "center" });
  }

  function setTab(name) {
    $$("[data-tab]", sheet).forEach((t) => t.setAttribute("aria-selected", String(t.dataset.tab === name)));
    $$("[data-pane]", sheet).forEach((p) => {
      const on = p.dataset.pane === name;
      p.hidden = !on;
      if (on && liveMotion()) gsap.fromTo(p, { opacity: 0 }, { opacity: 1, duration: 0.3, ease: "power1.out" });
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
    if (!liveMotion()) return;
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
  const itemKey = (i) => `${i.id}|${i.size}|${i.material}`;
  const FREE = SHOP.shipping.freeFrom;
  const freeF = (sub) => Math.min(1, sub / FREE);
  const MAX_QTY = 20;

  // Bewegung wird bei jedem Aufruf neu geprüft, ein Umschalten im System wirkt sofort
  const cartMotion = liveMotion;
  const canPop = typeof HTMLElement === "function" && typeof HTMLElement.prototype.showPopover === "function";

  const drawer = $("[data-cart]");
  const drawerPanel = $(".drawer__panel", drawer);
  const cartBtn = $("[data-open-cart]");
  const countEl = $("[data-cart-count]");
  const digitsEl = $("[data-cart-digits]");
  const arcEl = $("[data-cart-arc]");
  const echoEl = $("[data-cart-echo]");
  const glowEl = $("[data-cart-glow]");
  const listEl = $("[data-cart-list]");
  const footEl = $("[data-cart-foot]");
  const emptyEl = $("[data-cart-empty]");
  const titleEl = $("[data-cart-title]");
  const hintEl = $("[data-free-hint]");
  const shipWrap = $("[data-ship-wrap]");
  const shipText = $("[data-ship-text]");
  const subEl = $("[data-subtotal]");
  const totalEl = $("[data-total]");
  const drawerMeter = $("[data-cart-meter]");
  const cartStatus = $("[data-cart-status]");
  const drawerStatus = $("[data-drawer-status]");
  $("[data-meter-max]").textContent = money(FREE);

  let shownN = count();
  let celebrated = false; // Kreisschluss nur einmal pro Besuch feiern
  let lastSeenF = freeF(subtotal());
  let lastAdded = null;
  let undoState = null;

  // Statusmeldungen: Ein offener Dialog macht alles außerhalb inert, deshalb hat jeder
  // Dialog eine eigene Live-Region. Das Ziel wird erst im nächsten Frame bestimmt, und
  // Meldungen aus demselben Frame werden zu einem Satz zusammengefasst.
  const sheetStatus = $("[data-sheet-status]");
  let pendingMsgs = [];
  function announce(msg) {
    if (!msg) return;
    if (!pendingMsgs.length) requestAnimationFrame(flushAnnounce);
    pendingMsgs.push(msg);
  }
  function flushAnnounce() {
    const el = drawer.open ? drawerStatus : sheet.open ? sheetStatus : cartStatus;
    const text = pendingMsgs.join(" ");
    pendingMsgs = [];
    [drawerStatus, sheetStatus, cartStatus].forEach((r) => (r.textContent = ""));
    requestAnimationFrame(() => (el.textContent = text));
  }
  const freeText = (sub) => (sub >= FREE ? "Der Versand ist kostenlos." : `Noch ${money2(FREE - sub)} bis zum kostenlosen Versand.`);

  function setCartLabel() {
    const n = count();
    const sub = subtotal();
    cartBtn.setAttribute(
      "aria-label",
      n ? `Warenkorb öffnen, ${n} ${n === 1 ? "Print" : "Prints"}, ${sub >= FREE ? "Versand kostenlos" : `noch ${money2(FREE - sub)} bis zum kostenlosen Versand`}` : "Warenkorb öffnen, leer"
    );
  }

  // Zähler mit rollenden Ziffern und Ring
  const digitText = (n) => (n > 99 ? "99+" : String(n));
  function renderBadge({ animate = false, dir = 1, n = count(), sub = subtotal() } = {}) {
    const anim = animate && cartMotion();
    cartBtn.classList.toggle("has-items", n > 0);
    const offset = 100 - freeF(sub) * 100;
    if (anim) gsap.to(arcEl, { strokeDashoffset: offset, duration: 0.3, ease: "power3.out", overwrite: true });
    else if (gsap) gsap.set(arcEl, { strokeDashoffset: offset, overwrite: true });
    else arcEl.style.strokeDashoffset = offset;

    const bs = Array.from(digitsEl.children);
    if (gsap) gsap.killTweensOf(bs);
    bs.slice(0, -1).forEach((b) => b.remove());
    const old = digitsEl.lastElementChild;
    if (!anim || n === shownN) {
      if (gsap) gsap.set(old, { clearProps: "all" });
      old.textContent = digitText(n);
      shownN = n;
      return;
    }
    const neu = document.createElement("b");
    neu.textContent = digitText(n);
    digitsEl.appendChild(neu);
    gsap.fromTo(neu, { yPercent: 100 * dir, opacity: 0 }, { yPercent: 0, opacity: 1, duration: 0.26, ease: EASE_OUT });
    gsap.to(old, { yPercent: -100 * dir, opacity: 0, duration: 0.26, ease: EASE_OUT, onComplete: () => old.remove() });
    shownN = n;
  }

  // Belichtungsmesser: nur xPercent der Spur wird bewegt
  function setMeter(el, f, { instant = false, dur = 0.42, ease = EASE_OUT, delay = 0 } = {}) {
    const trail = el && $(".meter__trail", el);
    if (!trail) return;
    const x = (f - 1) * 100;
    if (!gsap) { trail.style.transform = `translateX(${x}%)`; return; }
    if (instant || !cartMotion()) gsap.set(trail, { xPercent: x, overwrite: true });
    else gsap.to(trail, { xPercent: x, duration: dur, ease, delay, overwrite: true });
  }

  // Name mit Format, damit mehrere Formate desselben Motivs unterscheidbar sind
  const itemName = (i) => `${printById(i.id).title}, ${sizeLabel(sizeById(i.size), printById(i.id).orientation)}, ${materialById(i.material).label}`;

  function itemHTML(i) {
    const p = printById(i.id);
    const t = esc(p.title);
    const name = esc(itemName(i));
    return `<li class="cart-item" data-key="${esc(itemKey(i))}">
      <div class="cart-item__thumb ${p.orientation === "landscape" ? "is-landscape" : ""}"><img src="${img(p.id, true)}" alt=""></div>
      <div>
        <div class="cart-item__title">${t}</div>
        <div class="cart-item__opts">${sizeLabel(sizeById(i.size), p.orientation)} · ${esc(materialById(i.material).label)}</div>
      </div>
      <div class="cart-item__price"><span data-line-price>${money2(lineTotal(i))}</span></div>
      <div class="cart-item__row">
        <div class="qty" role="group" aria-label="Anzahl ${name}">
          <button type="button" data-qty="-1" aria-label="${i.qty === 1 ? `${name} entfernen` : "Eins weniger"}">−</button>
          <output aria-live="polite"><span>${i.qty}</span></output>
          <button type="button" data-qty="1" aria-label="Eins mehr"${i.qty >= MAX_QTY ? ' aria-disabled="true"' : ""}>+</button>
        </div>
        <button class="remove" type="button" data-remove aria-label="${name} entfernen">Entfernen</button>
      </div>
    </li>`;
  }
  function liFor(i) {
    const tpl = document.createElement("template");
    tpl.innerHTML = itemHTML(i).trim();
    return tpl.content.firstElementChild;
  }

  let emptyShown = cart.length === 0;
  let emptyTween = null;
  function renderList() {
    listEl.innerHTML = cart.map(itemHTML).join("");
    undoState = null;
    if (emptyTween) { emptyTween.kill(); emptyTween = null; }
    if (gsap) gsap.set([footEl, emptyEl], { clearProps: "transform,opacity" });
    const empty = cart.length === 0;
    emptyShown = empty;
    emptyEl.hidden = !empty;
    footEl.hidden = empty;
  }

  // Wert setzen und kurz "einticken" lassen, dir +1 = kommt von unten
  function tick(el, text, dir, animate) {
    if (el.textContent === text) return;
    el.textContent = text;
    if (animate && cartMotion()) gsap.fromTo(el, { y: 4 * dir, opacity: 0.35 }, { y: 0, opacity: 1, duration: 0.2, ease: "power2.out", overwrite: true });
  }

  let hintTl = null;
  let shipTl = null;
  function setHint(sub, animate) {
    if (hintTl) {
      hintTl.kill();
      hintTl = null;
      gsap.set(hintEl, { clearProps: "transform,opacity" });
    }
    const text = freeText(sub);
    const isFree = sub >= FREE;
    if (hintEl.textContent === text) return;
    const flip = hintEl.classList.contains("is-free") !== isFree;
    if (animate && flip && cartMotion()) {
      hintTl = gsap.timeline({ onComplete: () => (hintTl = null) })
        .to(hintEl, { opacity: 0, y: -6, duration: 0.1, ease: "power2.in" })
        .add(() => { hintEl.textContent = text; hintEl.classList.toggle("is-free", isFree); })
        .fromTo(hintEl, { opacity: 0, y: 6 }, { opacity: 1, y: 0, duration: 0.18, ease: EASE_OUT });
    } else {
      hintEl.textContent = text;
      hintEl.classList.toggle("is-free", isFree);
    }
  }

  // Grenze 120 € überschritten: "6,90 €" wird durchgestrichen und weicht "kostenlos"
  function crossToFree() {
    const strike = $(".strike", shipWrap);
    shipTl = gsap.timeline({ onComplete: () => (shipTl = null) })
      .fromTo(strike, { scaleX: 0 }, { scaleX: 1, duration: 0.18, ease: "power2.out" })
      .to(shipText, { opacity: 0, duration: 0.08 })
      .add(() => {
        shipText.textContent = "kostenlos";
        shipWrap.classList.add("is-free");
        gsap.set(strike, { scaleX: 0 });
      })
      .fromTo(shipText, { opacity: 0, y: 6 }, { opacity: 1, y: 0, duration: 0.2, ease: EASE_OUT });
    if (!celebrated) {
      celebrated = true;
      const head = $(".meter__head", drawerMeter);
      gsap.timeline({ delay: 0.3 })
        .to(head, { scale: 1.8, duration: 0.1, ease: "power2.out" })
        .to(head, { scale: 1, duration: 0.2, ease: "power2.inOut" });
    }
  }

  function renderSums({ animate = false, dir = 1, prevSub = null } = {}) {
    if (shipTl) {
      shipTl.kill();
      shipTl = null;
      gsap.set($(".strike", shipWrap), { scaleX: 0 });
      gsap.set(shipText, { clearProps: "transform,opacity" });
    }
    const sub = subtotal();
    const ship = shipping();
    tick(subEl, money2(sub), dir, animate);
    tick(totalEl, money2(sub + ship), dir, animate);
    $("[data-total-2]").textContent = money2(sub + ship);

    const freeNow = sub >= FREE;
    const crossedUp = prevSub !== null && prevSub < FREE && freeNow;
    if (animate && crossedUp && cartMotion()) crossToFree();
    else {
      tick(shipText, freeNow ? "kostenlos" : money2(SHOP.shipping.flat), dir, animate);
      shipWrap.classList.toggle("is-free", freeNow);
    }
    setHint(sub, animate);
    // Meldung nur, wenn die Grenze überschritten wurde; der Aufrufer sagt sie zusammen mit seiner an
    return prevSub !== null && (prevSub >= FREE) !== freeNow ? (freeNow ? "Der Versand ist jetzt kostenlos." : freeText(sub)) : "";
  }

  function syncQtyButtons(li, i) {
    $('[data-qty="-1"]', li).setAttribute("aria-label", i.qty === 1 ? `${itemName(i)} entfernen` : "Eins weniger");
    const plus = $('[data-qty="1"]', li);
    if (i.qty >= MAX_QTY) plus.setAttribute("aria-disabled", "true");
    else plus.removeAttribute("aria-disabled");
  }

  function afterChange(dir, prevSub) {
    const shipMsg = renderSums({ animate: true, dir, prevSub });
    const f = freeF(subtotal());
    setMeter(drawerMeter, f);
    lastSeenF = f;
    renderBadge({ animate: true, dir });
    setCartLabel();
    return shipMsg;
  }

  function changeQty(li, d) {
    const i = cart.find((x) => itemKey(x) === li.dataset.key);
    if (!i) return;
    if (d > 0 && i.qty >= MAX_QTY) return;
    if (d < 0 && i.qty <= 1) return removeItem(li);
    const prevSub = subtotal();
    i.qty += d;
    save();
    const out = $("output span", li);
    out.textContent = i.qty;
    if (cartMotion()) gsap.fromTo(out, { y: 8 * d, opacity: 0 }, { y: 0, opacity: 1, duration: 0.22, ease: EASE_OUT, overwrite: true });
    tick($("[data-line-price]", li), money2(lineTotal(i)), d, true);
    syncQtyButtons(li, i);
    announce(afterChange(d, prevSub));
  }

  function updateEmpty(animate) {
    const empty = cart.length === 0;
    if (empty === emptyShown) return;
    emptyShown = empty;
    if (emptyTween) {
      emptyTween.kill();
      emptyTween = null;
      gsap.set(footEl, { clearProps: "transform,opacity" });
    }
    const anim = animate && cartMotion();
    if (empty) {
      const show = () => {
        emptyTween = null;
        if (cart.length) return;
        footEl.hidden = true;
        emptyEl.hidden = false;
        if (!anim) return;
        gsap.fromTo(emptyEl, { opacity: 0, y: 8 }, { opacity: 1, y: 0, duration: 0.32, ease: EASE_OUT, delay: 0.12, clearProps: "transform,opacity" });
        gsap.fromTo($(".cart-empty__mark", emptyEl), { rotation: -120 }, { rotation: -30, duration: 0.6, ease: EASE_OUT, delay: 0.12 });
      };
      if (anim) emptyTween = gsap.to(footEl, { opacity: 0, y: 8, duration: 0.16, ease: "power2.in", onComplete: () => { gsap.set(footEl, { clearProps: "transform,opacity" }); show(); } });
      else show();
    } else {
      emptyEl.hidden = true;
      footEl.hidden = false;
      if (anim) gsap.fromTo(footEl, { opacity: 0, y: 8 }, { opacity: 1, y: 0, duration: 0.3, ease: EASE_OUT, clearProps: "transform,opacity" });
    }
  }

  function flipFrom(state) {
    if (state) Flip.from(state, { duration: 0.32, ease: EASE_DRAWER, simple: true });
  }
  const flipState = () => (cartMotion() && Flip ? Flip.getState($$(".cart-item:not(.is-leaving), .cart-undo", listEl).concat(footEl)) : null);

  // Entfernen: Zeile gleitet raus, die anderen rücken per Flip nach, an ihre Stelle tritt "Rückgängig"
  function removeItem(li) {
    if (li.classList.contains("is-leaving")) return;
    const key = li.dataset.key;
    const index = cart.findIndex((x) => itemKey(x) === key);
    if (index < 0) return;
    const prevSub = subtotal();
    const [item] = cart.splice(index, 1);
    save();
    li.classList.add("is-leaving");
    const title = printById(item.id).title;
    const name = itemName(item);

    const swap = () => {
      $$(".cart-undo", listEl).forEach((r) => r.remove());
      const state = flipState();
      const row = document.createElement("li");
      row.className = "cart-undo";
      row.dataset.undo = key;
      row.innerHTML = `<span>${esc(title)} · ${esc(sizeLabel(sizeById(item.size), printById(item.id).orientation))} entfernt</span><button type="button" class="link-btn" data-undo-btn aria-label="${esc(name)} wieder hinzufügen">Rückgängig</button>`;
      li.replaceWith(row);
      undoState = { key, item, index };
      flipFrom(state);
      if (cartMotion()) gsap.fromTo(row.children, { opacity: 0 }, { opacity: 1, duration: 0.18 });
      const shipMsg = afterChange(-1, prevSub);
      updateEmpty(true);
      $("[data-undo-btn]", row).focus();
      announce(`${name} entfernt. Rückgängig möglich.`);
      announce(shipMsg);
    };
    if (cartMotion()) gsap.to(li.children, { opacity: 0, x: 20, duration: 0.16, ease: "power2.in", onComplete: swap });
    else swap();
  }

  function undo(row) {
    if (!undoState || row.dataset.undo !== undoState.key) return;
    const { item, index } = undoState;
    undoState = null;
    if (cart.some((x) => itemKey(x) === itemKey(item))) { renderList(); return; }
    const prevSub = subtotal();
    cart.splice(Math.min(index, cart.length), 0, item);
    save();
    const state = flipState();
    const li = liFor(item);
    row.replaceWith(li);
    flipFrom(state);
    if (cartMotion()) gsap.fromTo(li.children, { opacity: 0, x: 20 }, { opacity: 1, x: 0, duration: 0.26, ease: EASE_OUT, clearProps: "transform,opacity" });
    const shipMsg = afterChange(1, prevSub);
    updateEmpty(true);
    $("[data-remove]", li).focus();
    announce(`${itemName(item)} ist wieder im Warenkorb.`);
    announce(shipMsg);
  }

  listEl.addEventListener("click", (e) => {
    const undoBtn = e.target.closest("[data-undo-btn]");
    if (undoBtn) return undo(undoBtn.closest(".cart-undo"));
    const li = e.target.closest(".cart-item");
    if (!li || li.classList.contains("is-leaving")) return;
    const q = e.target.closest("[data-qty]");
    if (q) {
      if (q.getAttribute("aria-disabled") === "true") return;
      return changeQty(li, +q.dataset.qty);
    }
    if (e.target.closest("[data-remove]")) removeItem(li);
  });

  // Schritte wechseln in Leserichtung
  const ORDER = { cart: 0, checkout: 1, done: 2 };
  const TITLES = { cart: "Warenkorb", checkout: "Bestellung", done: "Danke" };
  let step = "cart";
  let stepTl = null;

  function focusStep(name) {
    const target =
      name === "checkout" ? $("[data-back]", drawer)
        : name === "done" ? $("[data-done-title]", drawer)
          : footEl.hidden ? $(".cart-empty .btn", drawer) : $("[data-to-checkout]", drawer);
    if (target) target.focus({ preventScroll: true });
  }

  function playDone(animate) {
    const ring = $(".done__ring", drawer);
    const dot = $(".done__dot", drawer);
    if (!animate || !cartMotion()) {
      if (gsap) gsap.set([ring, dot], { clearProps: "all" });
      return;
    }
    const texts = $$('[data-step="done"] > :not(.done__mark)', drawer);
    gsap.fromTo(ring, { strokeDashoffset: 25 }, { strokeDashoffset: 0, duration: 0.7, ease: "power2.inOut" });
    gsap.fromTo(dot, { scale: 0.6, opacity: 0, transformOrigin: "50% 50%" }, { scale: 1, opacity: 1, duration: 0.2, ease: EASE_OUT, delay: 0.5 });
    gsap.fromTo(texts, { y: 8, opacity: 0 }, { y: 0, opacity: 1, duration: 0.36, ease: EASE_OUT, stagger: 0.05, delay: 0.15, clearProps: "transform,opacity" });
  }

  function showStep(name, { animate = true, focus = true } = {}) {
    if (stepTl) stepTl.progress(1);
    const from = $(`[data-step="${step}"]`, drawer);
    const to = $(`[data-step="${name}"]`, drawer);
    const dir = ORDER[name] >= ORDER[step] ? 1 : -1;
    const swap = () => {
      $$("[data-step]", drawer).forEach((s) => (s.hidden = s.dataset.step !== name));
      titleEl.textContent = TITLES[name];
      drawerPanel.scrollTop = 0;
      step = name;
      if (focus) focusStep(name);
    };
    if (!animate || from === to || !cartMotion()) {
      swap();
      if (animate && from !== to && gsap) gsap.fromTo(to, { opacity: 0 }, { opacity: 1, duration: 0.12 });
      if (name === "done") playDone(false);
      return;
    }
    stepTl = gsap.timeline({ onComplete: () => { gsap.set(from, { clearProps: "transform,opacity" }); stepTl = null; } })
      .to(from, { opacity: 0, x: -12 * dir, duration: 0.12, ease: "power2.in" })
      .add(swap)
      .fromTo(to, { opacity: 0, x: 20 * dir }, { opacity: 1, x: 0, duration: 0.3, ease: EASE_OUT, clearProps: "transform,opacity" })
      .fromTo(titleEl, { opacity: 0, y: 8 }, { opacity: 1, y: 0, duration: 0.24, ease: EASE_OUT, clearProps: "transform,opacity" }, "<");
    if (name === "done") stepTl.add(() => playDone(true), "<");
  }

  const closeDrawer = () =>
    closeDialog(drawer, drawerPanel, { x: "100%", duration: 0.28 }).then(() => {
      $$(".cart-undo", listEl).forEach((r) => r.remove());
      undoState = null;
      drawerStatus.textContent = "";
    });
  wireDialog(drawer, closeDrawer);

  function openCart() {
    finishFlights();
    hideArrival(true);
    cartStatus.textContent = "";
    drawerStatus.textContent = "";
    renderList();
    renderSums();
    const f = freeF(subtotal());
    setMeter(drawerMeter, cartMotion() ? lastSeenF : f, { instant: true });
    showStep("cart", { animate: false, focus: false });
    openDialog(drawer, drawerPanel, { x: "100%", opacity: 1 }, { duration: 0.48, ease: EASE_DRAWER });
    if (cartMotion()) {
      const items = $$(".cart-item", listEl);
      gsap.fromTo(items.slice(0, 6), { opacity: 0, x: 20 }, { opacity: 1, x: 0, duration: 0.38, ease: EASE_OUT, delay: 0.09, stagger: 0.035, clearProps: "transform,opacity" });
      const block = footEl.hidden ? emptyEl : footEl;
      gsap.fromTo(block, { opacity: 0, y: 8 }, { opacity: 1, y: 0, duration: 0.36, ease: EASE_OUT, delay: 0.16, clearProps: "transform,opacity" });
      if (lastAdded && performance.now() - lastAdded.at < 8000) {
        const idx = items.findIndex((li) => li.dataset.key === lastAdded.key);
        if (idx >= 0) {
          items[idx].classList.add("is-new");
          gsap.fromTo($("img", items[idx]), { opacity: 0.15, scale: 1.04 }, { opacity: 1, scale: 1, duration: 0.6, ease: EASE_OUT, delay: 0.09 + 0.035 * Math.min(idx, 5), clearProps: "transform,opacity" });
        }
      }
      if (Math.abs(f - lastSeenF) > 0.001) setMeter(drawerMeter, f, { dur: 0.6, delay: 0.22 });
    }
    lastSeenF = f;
    lastAdded = null;
  }
  cartBtn.addEventListener("click", openCart);
  $("[data-to-checkout]").addEventListener("click", () => showStep("checkout"));
  $("[data-back]").addEventListener("click", () => showStep("cart"));

  // ---------- Sternspur: der Print fliegt als Stern in den Warenkorb ----------
  const fxLayer = $("[data-fx]");
  const flights = new Set();
  function finishFlights() { Array.from(flights).forEach((tl) => tl.progress(1)); }
  document.addEventListener("visibilitychange", () => { if (document.hidden) finishFlights(); });
  let lastVw = window.innerWidth;
  window.addEventListener("resize", () => {
    if (window.innerWidth !== lastVw) { lastVw = window.innerWidth; finishFlights(); }
  });

  // Kreisbogen von A nach B gegen den Uhrzeigersinn, wie die Sterne im Hero um den Pol
  function arcPath(A, B, deg) {
    const dx = B.x - A.x;
    const dy = B.y - A.y;
    if (!deg) {
      const t = (Math.atan2(dy, dx) * 180) / Math.PI;
      return (p) => ({ x: A.x + dx * p, y: A.y + dy * p, tan: t });
    }
    const th = (deg * Math.PI) / 180;
    const L = Math.hypot(dx, dy);
    const R = L / (2 * Math.sin(th / 2));
    const h = R * Math.cos(th / 2);
    const C = { x: (A.x + B.x) / 2 + (dy / L) * h, y: (A.y + B.y) / 2 - (dx / L) * h };
    const a0 = Math.atan2(A.y - C.y, A.x - C.x);
    return (p) => {
      const a = a0 - th * p;
      return { x: C.x + R * Math.cos(a), y: C.y + R * Math.sin(a), tan: (a * 180) / Math.PI - 90 };
    };
  }

  const SEGS = 12;
  const cl = (v) => (v < 0 ? 0 : v > 1 ? 1 : v);

  function launchStar(s) {
    const r = s.rect;
    const pad = s.edge ? 3 : 0;
    const w = r.width + pad * 2;
    const h = r.height + pad * 2;
    const A = { x: r.left + r.width / 2, y: r.top + r.height / 2 };
    const B = s.B;
    const L = Math.hypot(B.x - A.x, B.y - A.y);
    const inside = (pt) => pt.x >= 8 && pt.x <= s.W - 8 && pt.y >= 8 && pt.y <= s.H - 8;
    const fits = (fn) => { for (let k = 0; k <= 8; k++) if (!inside(fn(k / 8))) return false; return true; };
    let deg = L >= 400 ? 80 : L >= 140 ? 64 : 40;
    let path = arcPath(A, B, deg);
    if (!fits(path)) { deg /= 2; path = arcPath(A, B, deg); }
    if (!fits(path)) path = arcPath(A, B, 0);
    const sEnd = Math.min(0.5, 28 / Math.max(w, h));

    const paper = document.createElement("div");
    paper.className = `fx__paper${s.edge ? " has-edge" : ""}`;
    paper.style.width = `${w}px`;
    paper.style.height = `${h}px`;
    paper.innerHTML = `<img src="${img(s.item.id, true)}" alt="">`;
    const star = document.createElement("div");
    star.className = "fx__star";
    const segs = Array.from({ length: SEGS }, () => {
      const d = document.createElement("div");
      d.className = "fx__seg";
      return d;
    });
    fxLayer.replaceChildren(paper, star, ...segs);
    if (canPop) {
      try {
        if (fxLayer.matches(":popover-open")) fxLayer.hidePopover();
        fxLayer.showPopover();
      } catch (_) { fxLayer.classList.add("is-on"); }
    } else fxLayer.classList.add("is-on");

    const sineIn = gsap.parseEase("sine.in");
    const p2in = gsap.parseEase("power2.in");
    const p2out = gsap.parseEase("power2.out");
    const back2 = gsap.parseEase("back.out(2)");
    const expoOut = gsap.parseEase("expo.out");
    const P = new Array(SEGS + 1);

    function frame(m) {
      for (let j = 0; j <= SEGS; j++) P[j] = path(sineIn(cl((m - 120 - j * 14) / 680)));
      // Print: abheben, dann auf der Bahn schrumpfen
      const k = p2out(cl(m / 160));
      const q = p2in(cl((m - 120) / 420));
      const s0 = 1 + 0.035 * k;
      const sc = s0 + (sEnd - s0) * q;
      const tilt = Math.max(-14, Math.min(6, 0.25 * P[0].tan)) * cl((m - 120) / 200);
      const yOff = s.fromButton ? 12 * (1 - k) : -6 * k * (1 - cl((m - 120) / 420));
      paper.style.transform = `translate3d(${P[0].x - w / 2}px,${P[0].y - h / 2 + yOff}px,0) rotate(${tilt}deg) scale(${sc})`;
      paper.style.opacity = (s.fromButton ? k : 1) * (m < 400 ? 1 : 1 - cl((m - 400) / 140));
      paper.style.setProperty("--lift", k);
      // Stern: entsteht aus dem Print, verglüht im Zähler
      const a = cl((m - 390) / 140);
      const b = expoOut(cl((m - 800) / 160));
      star.style.transform = `translate3d(${P[0].x - 12}px,${P[0].y - 12}px,0) scale(${(0.4 + 0.6 * back2(a)) * (1 + 0.8 * b)})`;
      star.style.opacity = a * (1 - b);
      // Sternspur aus kurzen Strichen mit kleinen Lücken, wie eine gestapelte Belichtung
      for (let i = 0; i < SEGS; i++) {
        const p0 = P[i + 1];
        const p1 = P[i];
        const len = Math.hypot(p1.x - p0.x, p1.y - p0.y);
        const ang = (Math.atan2(p1.y - p0.y, p1.x - p0.x) * 180) / Math.PI;
        const vis = cl((m - (i + 1) * 14 - 390) / 140) * (m - 120 - (i + 1) * 14 >= 680 ? 0 : 1);
        segs[i].style.transform = `translate3d(${p0.x}px,${p0.y - 0.75}px,0) rotate(${ang}deg) scaleX(${(len * 0.9) / 10})`;
        segs[i].style.opacity = 0.8 * Math.pow(1 - i / SEGS, 1.5) * vis;
      }
    }

    const clock = { m: 0 };
    const tl = gsap.timeline({
      onComplete: () => {
        flights.delete(tl);
        fxLayer.replaceChildren();
        if (!flights.size) {
          fxLayer.classList.remove("is-on");
          if (canPop) try { fxLayer.hidePopover(); } catch (_) { /* schon zu */ }
        }
      },
    });
    tl.to(clock, { m: 968, duration: 0.968, ease: "none", onUpdate: () => frame(clock.m) }, 0).call(arrive, [s], 0.8);
    frame(0);
    flights.add(tl);
    return tl;
  }

  // Ankunft: Licht im Zähler, Ziffer rollt, Ring wächst, Karte erscheint
  function arrive(s) {
    renderBadge({ animate: true, dir: 1, n: s.nAfter, sub: s.subAfter });
    setCartLabel();
    announce(`${s.title}, ${s.optsText} liegt im Warenkorb. ${freeText(s.subAfter)}`);
    if (cartMotion()) {
      gsap.timeline()
        .fromTo(glowEl, { opacity: 0, scale: 0.5 }, { opacity: 0.6, duration: 0.06, ease: "power2.out" }, 0)
        .to(glowEl, { opacity: 0, duration: 0.3, ease: "power2.out" }, 0.06)
        .to(glowEl, { scale: 1.2, duration: 0.36, ease: "expo.out" }, 0)
        .to(countEl, { scaleX: 1.1, scaleY: 0.88, y: -1, duration: 0.07, ease: "power2.out" }, 0)
        .to(countEl, { scaleX: 1, scaleY: 1, y: 0, duration: 0.28, ease: "back.out(2)" }, 0.07);
    } else if (gsap) {
      gsap.timeline().set(glowEl, { scale: 1 }).to(glowEl, { opacity: 0.5, duration: 0.2, ease: "none" }).to(glowEl, { opacity: 0, duration: 0.2, ease: "none" });
    }
    const party = s.crossed && !celebrated;
    showArrival(s, party);
    if (party) {
      celebrated = true;
      if (cartMotion()) gsap.fromTo(echoEl, { scale: 1, opacity: 0.7, transformOrigin: "50% 50%" }, { scale: 1.5, opacity: 0, duration: 0.22, ease: "expo.out", delay: 0.16 });
    }
    lastAdded = { key: s.key, at: performance.now() };
    lastSeenF = cartMotion() ? lastSeenF : s.fAfter;
  }

  // ---------- Ankunftskarte ----------
  const arrivalEl = $("[data-arrival]");
  const arrivalBody = $("[data-arrival-body]");
  const arrivalMeter = $("[data-arrival-meter]");
  const arrivalShip = $("[data-arrival-ship]");
  let arrivalTimer = 0;
  let arrivalY = 0;
  const shipLabel = (sub) => (sub >= FREE ? "Versand kostenlos" : `Noch ${money2(FREE - sub)} bis Gratisversand`);

  function setShipLabel(sub) {
    arrivalShip.textContent = shipLabel(sub);
    arrivalShip.classList.toggle("is-free", sub >= FREE);
  }
  function onArrivalScroll() { if (Math.abs(window.scrollY - arrivalY) > 48) hideArrival(); }

  function showArrival(s, party) {
    const p = printById(s.item.id);
    const anim = cartMotion();
    $("[data-arrival-img]").src = img(p.id, true);
    $("[data-arrival-thumb]").classList.toggle("is-landscape", p.orientation === "landscape");
    $("[data-arrival-title]").textContent = p.title;
    $("[data-arrival-opts]").textContent = `${s.optsText} · ${money2(s.price)}`;
    setShipLabel(party && anim ? s.subBefore : s.subAfter);

    const r = s.btnRect;
    arrivalEl.style.top = `${Math.round(r.bottom + 8)}px`;
    clearTimeout(arrivalTimer);
    const wasVisible = !arrivalEl.hidden;
    arrivalEl.hidden = false;
    if (gsap) {
      if (wasVisible) {
        gsap.fromTo(arrivalBody, { opacity: 0 }, { opacity: 1, duration: 0.16, overwrite: true });
        gsap.set(arrivalEl, { opacity: 1, y: 0, scale: 1, overwrite: true });
      } else if (anim) {
        const box = arrivalEl.getBoundingClientRect();
        gsap.fromTo(arrivalEl, { opacity: 0, y: -8, scale: 0.98, transformOrigin: `${s.B.x - box.left}px 0px` }, { opacity: 1, y: 0, scale: 1, duration: 0.28, ease: EASE_OUT, overwrite: true });
      } else {
        gsap.fromTo(arrivalEl, { opacity: 0 }, { opacity: 1, duration: 0.15, overwrite: true });
      }
    }
    setMeter(arrivalMeter, anim ? s.fBefore : s.fAfter, { instant: true });
    if (anim) setMeter(arrivalMeter, s.fAfter, { dur: 0.3, ease: "power3.out", delay: 0.06 });
    if (party && anim) {
      gsap.timeline({ delay: 0.16 })
        .to(arrivalShip, { opacity: 0, y: -6, duration: 0.1, ease: "power2.in" })
        .add(() => setShipLabel(s.subAfter))
        .fromTo(arrivalShip, { opacity: 0, y: 6 }, { opacity: 1, y: 0, duration: 0.18, ease: EASE_OUT });
    }
    arrivalTimer = setTimeout(hideArrival, anim ? 3280 : 4150);
    arrivalY = window.scrollY;
    window.addEventListener("scroll", onArrivalScroll, { passive: true });
  }

  function hideArrival(fast) {
    clearTimeout(arrivalTimer);
    window.removeEventListener("scroll", onArrivalScroll);
    if (arrivalEl.hidden) return;
    const done = () => { arrivalEl.hidden = true; };
    if (!gsap || fast === true) {
      if (gsap) gsap.set(arrivalEl, { opacity: 0, overwrite: true });
      return done();
    }
    gsap.to(arrivalEl, cartMotion()
      ? { opacity: 0, y: -4, duration: 0.2, ease: "power2.in", overwrite: true, onComplete: done }
      : { opacity: 0, duration: 0.15, overwrite: true, onComplete: done });
  }

  // Sichtbarer Anteil des Motivs im Dialog (auf dem Handy oft weggescrollt)
  function visibleShare(rect, panel, W, H) {
    if (!rect.width || !rect.height) return 0;
    const x0 = Math.max(rect.left, panel.left, 0);
    const y0 = Math.max(rect.top, panel.top, 0);
    const x1 = Math.min(rect.left + rect.width, panel.right, W);
    const y1 = Math.min(rect.top + rect.height, panel.bottom, H);
    return Math.max(0, x1 - x0) * Math.max(0, y1 - y0) / (rect.width * rect.height);
  }

  function visibleImageRect() {
    const wall = !$('[data-pane="wand"]', sheet).hidden;
    if (wall) return roomPoster.getBoundingClientRect();
    const r = productImg.getBoundingClientRect();
    const cs = getComputedStyle(productImg);
    const left = r.left + parseFloat(cs.paddingLeft);
    const top = r.top + parseFloat(cs.paddingTop);
    const bw = r.width - parseFloat(cs.paddingLeft) - parseFloat(cs.paddingRight);
    const bh = r.height - parseFloat(cs.paddingTop) - parseFloat(cs.paddingBottom);
    const ratio = sel.print.orientation === "landscape" ? 1.5 : 2 / 3;
    let w = bw;
    let h = bh;
    if (w / h > ratio) w = h * ratio; else h = w / ratio;
    return { left: left + (bw - w) / 2, top: top + (bh - h) / 2, width: w, height: h };
  }

  form.addEventListener("submit", (e) => {
    e.preventDefault();
    if (sheetClosing) return;
    const p = sel.print;
    const nBefore = count();
    const subBefore = subtotal();
    const it = { id: p.id, size: sel.size, material: sel.material };
    const existing = cart.find((i) => itemKey(i) === itemKey(it));
    if (existing) existing.qty = Math.min(MAX_QTY, existing.qty + 1);
    else cart.push(Object.assign({ qty: 1 }, it));
    save();
    setCartLabel();

    // Ein Lese-Block vor allen Schreibzugriffen
    const W = window.innerWidth;
    const H = window.innerHeight;
    const wall = !$('[data-pane="wand"]', sheet).hidden;
    let rect = visibleImageRect();
    const panelRect = sheetPanel.getBoundingClientRect();
    const countRect = countEl.getBoundingClientRect();
    const btnRect = cartBtn.getBoundingClientRect();
    const addRect = $("[data-add]", form).getBoundingClientRect();
    const subAfter = subtotal();
    const s = {
      item: it,
      key: itemKey(it),
      title: p.title,
      optsText: `${sizeLabel(sizeById(sel.size), p.orientation)} · ${materialById(sel.material).label}`,
      price: priceOf(sel.size, sel.material),
      nBefore,
      nAfter: count(),
      subBefore,
      subAfter,
      fBefore: freeF(subBefore),
      fAfter: freeF(subAfter),
      B: { x: countRect.left + countRect.width / 2, y: countRect.top + countRect.height / 2 },
      btnRect,
      W,
      H,
      edge: sel.material === "papier" && !wall,
      fromButton: false,
    };
    s.crossed = s.fBefore < 1 && s.fAfter >= 1;

    // Motiv weggescrollt? Dann startet ein kleiner Print direkt über dem Button
    if (visibleShare(rect, panelRect, W, H) < 0.5) {
      const land = p.orientation === "landscape";
      const rw = land ? 72 : 48;
      const rh = land ? 48 : 72;
      rect = { left: addRect.left + addRect.width / 2 - rw / 2, top: addRect.top - 8 - rh, width: rw, height: rh };
      s.fromButton = true;
    }
    s.rect = rect;

    finishFlights();
    if (!cartMotion()) {
      closeSheet({ scrollToTile: false }).then(() => arrive(s));
      return;
    }
    if (canPop) {
      launchStar(s);
      closeSheet({ to: { duration: 0.2, ease: "power2.out" }, scrollToTile: false });
    } else {
      closeSheet({ scrollToTile: false }).then(() => launchStar(s).seek(0.12));
    }
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
    renderList();
    renderSums();
    renderBadge();
    setCartLabel();
    setMeter(drawerMeter, 0, { instant: true });
    lastSeenF = 0;
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

  renderList();
  renderSums();
  renderBadge();
  setCartLabel();
  setMeter(drawerMeter, lastSeenF, { instant: true });
  if (typeof toastEl.showPopover === "function") {
    try { toastEl.showPopover(); } catch (_) { /* egal */ }
  }

  // ---------- Navigation ----------
  const nav = $("[data-nav]");
  let navTick = false;
  const updateNav = () => { nav.classList.toggle("is-solid", window.scrollY > 60); navTick = false; };
  window.addEventListener("scroll", () => { if (!navTick) { navTick = true; requestAnimationFrame(updateNav); } }, { passive: true });
  updateNav();

  // ---------- Hero: Scrollen = Parallax-Tiefe ----------
  const Sky = window.Sky;
  const depthEl = $("[data-exposure]");  /* zeigt Tiefe als % */
  const heroHint = $("[data-hero-hint]");
  const heroState = { intro: 0, scroll: 0 };

  function setDepth(d) {
    if (!Sky) return;
    Sky.state.depth = Math.max(0, Math.min(1, d));
    depthEl.textContent = Math.round(d * 100) + '%';
    if (!motion) Sky.draw();
  }

  function heroUpdate() {
    const start = 0 + 0.15 * heroState.intro;  /* intro: 0 bis 0.15 */
    const t = heroState.scroll;
    /* smooth easing */
    const eased = t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2;
    setDepth(start + (1 - start) * eased);  /* 0 bis 1 */
  }

  if (!motion) {
    setDepth(0.7);
  } else {
    /* Auftakt: Sterne rücken näher, Text steigt ein */
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
      onEnter: () => gsap.to(heroHint, { opacity: 0, duration: 0.3 }),
      onLeaveBack: () => gsap.to(heroHint, { opacity: 1, duration: 0.3 }),
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
