// Warenkorb: Zustand im localStorage, Anzeige im Drawer, Checkout optional über Stripe.
import { allProducts } from '../data/kits';
import { site, euro } from '../data/site';
import { stopScroll } from './smooth';

type Line = { id: string; qty: number };

const KEY = 'kleinteil-cart-v1';
const MAX_QTY = 9;
const products = new Map(allProducts.map((p) => [p.id, p]));

let lines: Line[] = load();

function load(): Line[] {
  try {
    const raw = JSON.parse(localStorage.getItem(KEY) || '[]');
    if (!Array.isArray(raw)) return [];
    return raw.filter((l) => products.get(l?.id)?.buyable && Number.isInteger(l.qty) && l.qty > 0);
  } catch {
    return [];
  }
}

function save() {
  try {
    localStorage.setItem(KEY, JSON.stringify(lines));
  } catch {
    /* Privater Modus o. Ä.: Korb lebt dann nur bis zum Neuladen */
  }
}

export function count() {
  return lines.reduce((n, l) => n + l.qty, 0);
}

function subtotal() {
  return lines.reduce((sum, l) => sum + (products.get(l.id)?.price ?? 0) * l.qty, 0);
}

export function add(id: string, qty = 1) {
  const product = products.get(id);
  if (!product?.buyable) return;
  const line = lines.find((l) => l.id === id);
  if (line) line.qty = Math.min(MAX_QTY, line.qty + qty);
  else lines.push({ id, qty });
  save();
  render();
  bumpCount();
  window.dispatchEvent(new CustomEvent('cart:add', { detail: { id } }));
}

function setQty(id: string, qty: number) {
  if (qty <= 0) lines = lines.filter((l) => l.id !== id);
  else {
    const line = lines.find((l) => l.id === id);
    if (line) line.qty = Math.min(MAX_QTY, qty);
  }
  save();
  render();
}

export function clear() {
  lines = [];
  save();
  render();
}

// -----------------------------------------------------------------------------
// Anzeige

const dialog = document.querySelector<HTMLDialogElement>('[data-cart]')!;
const list = dialog.querySelector<HTMLUListElement>('[data-cart-items]')!;
const countEls = document.querySelectorAll<HTMLElement>('[data-cart-count]');
let lastFocus: HTMLElement | null = null;

function render() {
  const n = count();
  countEls.forEach((el) => {
    el.textContent = String(n);
    el.classList.toggle('has-items', n > 0);
  });
  dialog.classList.toggle('is-empty', n === 0);
  dialog.querySelector<HTMLElement>('[data-cart-empty]')!.hidden = n > 0;

  list.replaceChildren(
    ...lines.map((l) => {
      const p = products.get(l.id)!;
      const li = document.createElement('li');
      li.className = 'cart-item';
      li.innerHTML = `
        <div>
          <div class="name"></div>
          <div class="unit">${euro(p.price)} pro Stück</div>
        </div>
        <div class="line">${euro(p.price * l.qty)}</div>
        <div class="controls">
          <div class="stepper" role="group">
            <button type="button" data-step="-1" aria-label="Eins weniger">−</button>
            <output aria-live="polite">${l.qty}</output>
            <button type="button" data-step="1" aria-label="Eins mehr">+</button>
          </div>
          <button type="button" class="remove" data-remove>Entfernen</button>
        </div>`;
      li.querySelector('.name')!.textContent = p.name;
      li.querySelector('.stepper')!.setAttribute('aria-label', `Menge ${p.name}`);
      li.querySelectorAll<HTMLButtonElement>('[data-step]').forEach((b) =>
        b.addEventListener('click', () => setQty(l.id, l.qty + Number(b.dataset.step))),
      );
      li.querySelector('[data-remove]')!.addEventListener('click', () => setQty(l.id, 0));
      return li;
    }),
  );

  const sub = subtotal();
  const free = sub >= site.shipping.freeFrom;
  const shipping = free || n === 0 ? 0 : site.shipping.flat;
  dialog.querySelector('[data-subtotal]')!.textContent = euro(sub);
  dialog.querySelector('[data-shipping]')!.textContent = free ? 'kostenlos' : euro(shipping);
  dialog.querySelector('[data-total]')!.textContent = euro(sub + shipping);

  const ship = dialog.querySelector<HTMLElement>('[data-ship]')!;
  ship.classList.toggle('is-free', free);
  dialog.querySelector('[data-ship-text]')!.textContent = free
    ? 'Versand geht auf uns.'
    : `Noch ${euro(site.shipping.freeFrom - sub)} bis zum kostenlosen Versand`;
  dialog.querySelector<HTMLElement>('[data-ship-bar]')!.style.width = `${Math.min(100, (sub / site.shipping.freeFrom) * 100)}%`;

  // Lötset anbieten, solange ein Bausatz mit Lötstellen drin ist und das Set fehlt
  const needsIron = lines.some((l) => l.id === 'kumpel' || l.id === 'wetterfrosch');
  dialog.querySelector<HTMLElement>('[data-upsell]')!.hidden = !needsIron || lines.some((l) => l.id === 'loetset');
  dialog.querySelector<HTMLElement>('[data-checkout-msg]')!.hidden = true;
}

function bumpCount() {
  countEls.forEach((el) => {
    el.classList.remove('bump');
    void el.offsetWidth;
    el.classList.add('bump');
  });
}

export function open() {
  if (dialog.open) {
    // Wird gerade geschlossen: einfach wieder aufziehen
    if (!dialog.classList.contains('is-open')) {
      dialog.classList.add('is-open');
      stopScroll(true);
    }
    return;
  }
  lastFocus = document.activeElement as HTMLElement | null;
  dialog.showModal();
  stopScroll(true);
  requestAnimationFrame(() => dialog.classList.add('is-open'));
}

export function close() {
  if (!dialog.open) return;
  dialog.classList.remove('is-open');
  stopScroll(false);
  const panel = dialog.querySelector<HTMLElement>('[data-cart-panel]')!;
  let finished = false;
  const done = () => {
    if (finished) return;
    finished = true;
    panel.removeEventListener('transitionend', onEnd);
    if (dialog.classList.contains('is-open')) return;
    dialog.close();
    lastFocus?.focus?.();
  };
  // Nur auf das Ende der Schiebe-Animation des Panels hören (nicht auf Kinder),
  // und zur Sicherheit nach kurzer Zeit trotzdem schließen.
  const onEnd = (e: TransitionEvent) => {
    if (e.target === panel && e.propertyName === 'transform') done();
  };
  if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) done();
  else {
    panel.addEventListener('transitionend', onEnd);
    window.setTimeout(done, 600);
  }
}

async function checkout() {
  const msg = dialog.querySelector<HTMLElement>('[data-checkout-msg]')!;
  const btn = dialog.querySelector<HTMLButtonElement>('[data-checkout]')!;
  if (site.checkout.mode !== 'stripe') {
    msg.textContent =
      'Die Kasse ist noch nicht angeschlossen. Das ist eine Vorschau: In site.ts den Checkout auf "stripe" stellen (siehe README).';
    msg.hidden = false;
    return;
  }
  btn.disabled = true;
  btn.textContent = 'Einen Moment …';
  try {
    const res = await fetch(site.checkout.endpoint, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ items: lines }),
    });
    const data = await res.json();
    if (!res.ok || !data.url) throw new Error(data.error || 'Checkout fehlgeschlagen');
    window.location.href = data.url;
  } catch (err) {
    msg.textContent = `Die Kasse hat nicht geantwortet. Versuch es gleich noch mal oder schreib uns an ${site.email}.`;
    msg.hidden = false;
    btn.disabled = false;
    btn.textContent = 'Zur Kasse';
    console.error(err);
  }
}

export function initCart() {
  render();
  document.addEventListener('click', (e) => {
    const target = e.target as HTMLElement;
    const addBtn = target.closest<HTMLElement>('[data-add]');
    if (addBtn) {
      e.preventDefault();
      add(addBtn.dataset.add!);
      if (!addBtn.hasAttribute('data-no-open')) open();
      return;
    }
    if (target.closest('[data-cart-open]')) {
      open();
      return;
    }
    if (target.closest('[data-cart-close]')) {
      close();
    }
  });
  // Klick auf den abgedunkelten Hintergrund schließt
  dialog.addEventListener('click', (e) => {
    if (e.target === dialog) close();
  });
  dialog.addEventListener('cancel', (e) => {
    e.preventDefault();
    close();
  });
  dialog.querySelector('[data-checkout]')!.addEventListener('click', checkout);
  // Korb in einem anderen Tab geändert
  window.addEventListener('storage', (e) => {
    if (e.key === KEY) {
      lines = load();
      render();
    }
  });
}
