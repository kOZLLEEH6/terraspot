// @ts-check
import { defineConfig } from 'astro/config';

export default defineConfig({
  // TODO: echte Domain eintragen (wird für Canonical-URLs und Social-Previews gebraucht)
  site: 'https://kleinteil.example',
  devToolbar: { enabled: false },
  build: { inlineStylesheets: 'auto' },
});
