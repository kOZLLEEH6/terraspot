// Erstellt eine Stripe-Checkout-Session aus dem Warenkorb und gibt die URL zurück.
// Preise kommen aus src/data/kits.ts (Server-Seite), nie aus dem Browser.
//
// Benötigt die Umgebungsvariable STRIPE_SECRET_KEY (in Netlify unter
// Site configuration > Environment variables). Kein npm-Paket nötig.
import { allProducts } from '../../src/data/kits';
import { site } from '../../src/data/site';

const products = new Map(allProducts.map((p) => [p.id, p]));

export default async (req: Request): Promise<Response> => {
  if (req.method !== 'POST') return json({ error: 'Nur POST erlaubt' }, 405);

  const key = process.env.STRIPE_SECRET_KEY;
  if (!key) return json({ error: 'STRIPE_SECRET_KEY ist nicht gesetzt' }, 500);

  let body: { items?: { id?: string; qty?: number }[] };
  try {
    body = await req.json();
  } catch {
    return json({ error: 'Ungültige Anfrage' }, 400);
  }

  const lines = (Array.isArray(body.items) ? body.items : [])
    .map((i) => ({ product: products.get(String(i?.id)), qty: Math.floor(Number(i?.qty)) }))
    .filter((l) => l.product?.buyable && l.qty >= 1 && l.qty <= 9);
  if (!lines.length) return json({ error: 'Der Warenkorb ist leer' }, 400);

  const subtotal = lines.reduce((sum, l) => sum + l.product!.price * l.qty, 0);
  const freeShipping = subtotal >= site.shipping.freeFrom;
  const origin = process.env.URL || new URL(req.url).origin;

  const p = new URLSearchParams();
  p.set('mode', 'payment');
  p.set('locale', 'de');
  p.set('success_url', `${origin}/danke/?session_id={CHECKOUT_SESSION_ID}`);
  p.set('cancel_url', `${origin}/#bausaetze`);
  p.set('billing_address_collection', 'required');
  site.shipping.countries.forEach((c, i) => p.set(`shipping_address_collection[allowed_countries][${i}]`, c));

  const rate = 'shipping_options[0][shipping_rate_data]';
  p.set(`${rate}[type]`, 'fixed_amount');
  p.set(`${rate}[display_name]`, freeShipping ? 'Kostenloser Versand mit DHL' : 'DHL Paket');
  p.set(`${rate}[fixed_amount][amount]`, String(freeShipping ? 0 : site.shipping.flat));
  p.set(`${rate}[fixed_amount][currency]`, 'eur');
  p.set(`${rate}[delivery_estimate][minimum][unit]`, 'business_day');
  p.set(`${rate}[delivery_estimate][minimum][value]`, '2');
  p.set(`${rate}[delivery_estimate][maximum][unit]`, 'business_day');
  p.set(`${rate}[delivery_estimate][maximum][value]`, '4');

  // Rechnung als PDF an die Kundschaft (Stripe berechnet dafür eine kleine Gebühr).
  p.set('invoice_creation[enabled]', 'true');

  lines.forEach((l, i) => {
    const item = `line_items[${i}]`;
    p.set(`${item}[quantity]`, String(l.qty));
    p.set(`${item}[price_data][currency]`, 'eur');
    p.set(`${item}[price_data][unit_amount]`, String(l.product!.price));
    p.set(`${item}[price_data][tax_behavior]`, 'inclusive');
    p.set(`${item}[price_data][product_data][name]`, l.product!.name);
  });

  const res = await fetch('https://api.stripe.com/v1/checkout/sessions', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${key}`,
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: p,
  });
  const data = await res.json();
  if (!res.ok) {
    console.error('Stripe-Fehler', data?.error?.message);
    return json({ error: 'Stripe hat die Anfrage abgelehnt' }, 502);
  }
  return json({ url: data.url });
};

export const config = { path: '/api/checkout' };

function json(obj: unknown, status = 200) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' },
  });
}
