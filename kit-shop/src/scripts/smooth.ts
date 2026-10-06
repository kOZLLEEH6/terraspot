// Sanftes Scrollen (Lenis) und GSAP an einer Stelle, damit alle Module
// dieselbe Instanz benutzen.
import Lenis from 'lenis';
import { gsap } from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';

gsap.registerPlugin(ScrollTrigger);

export const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

let lenis: Lenis | null = null;

export function initSmooth() {
  if (lenis || reduceMotion) return lenis;
  lenis = new Lenis({ lerp: 0.11, smoothWheel: true });
  lenis.on('scroll', ScrollTrigger.update);
  gsap.ticker.add((time) => lenis?.raf(time * 1000));
  gsap.ticker.lagSmoothing(0);
  return lenis;
}

export function getLenis() {
  return lenis;
}

export function scrollToY(y: number, duration = 1.4) {
  if (lenis) {
    lenis.scrollTo(y, { duration, easing: (t: number) => 1 - Math.pow(1 - t, 4) });
  } else {
    window.scrollTo({ top: y, behavior: reduceMotion ? 'auto' : 'smooth' });
  }
}

export function stopScroll(stop: boolean) {
  if (!lenis) return;
  if (stop) lenis.stop();
  else lenis.start();
}

export { gsap, ScrollTrigger };
