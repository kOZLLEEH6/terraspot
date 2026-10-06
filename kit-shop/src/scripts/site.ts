// Läuft auf jeder Seite: sanftes Scrollen, Header-Verhalten, Anker-Links, Warenkorb.
import { initSmooth, getLenis, scrollToY } from './smooth';
import { initCart } from './cart';

initSmooth();
initCart();

// Header: Hintergrund nach dem ersten Scrollen, beim Runterscrollen ausblenden
const header = document.querySelector<HTMLElement>('[data-header]');
if (header) {
  let lastY = window.scrollY;
  const onScroll = () => {
    const y = window.scrollY;
    header.classList.toggle('is-scrolled', y > 8);
    const down = y > lastY + 2;
    const up = y < lastY - 2;
    if (down && y > 420 && !document.querySelector('dialog[open]')) header.classList.add('is-hidden');
    if (up || y < 120) header.classList.remove('is-hidden');
    lastY = y;
  };
  const lenis = getLenis();
  if (lenis) lenis.on('scroll', onScroll);
  else window.addEventListener('scroll', onScroll, { passive: true });
  onScroll();
  header.addEventListener('focusin', () => header.classList.remove('is-hidden'));
}

// Anker-Links auf derselben Seite weich anfahren
document.addEventListener('click', (e) => {
  const link = (e.target as HTMLElement).closest<HTMLAnchorElement>('a[href*="#"]');
  if (!link || link.hasAttribute('data-scroll-to')) return;
  const url = new URL(link.href, location.href);
  if (url.pathname !== location.pathname || !url.hash) return;
  const target = document.getElementById(decodeURIComponent(url.hash.slice(1)));
  if (!target) return;
  e.preventDefault();
  const offset = (header?.offsetHeight ?? 0) + 12;
  scrollToY(target.getBoundingClientRect().top + window.scrollY - offset);
  history.replaceState(null, '', url.hash);
});
