// Zentrale Einstellungen für den Shop. Alles, was du vor dem Livegang
// anpassen musst, steht hier oder in kits.ts.

export const site = {
  // Arbeitstitel. Name ändern = hier ändern (plus Logo in components/Logo.astro).
  name: 'kleinteil',
  claim: 'Elektronik-Bausätze mit ESP32',
  description:
    'Bausätze mit ESP32 zum Selberbauen: Teile, Anleitung und Code. Löte dir einen Schreibtisch-Kumpel mit OLED-Gesicht und lern dabei echte Elektronik.',

  // TODO: echte Adresse eintragen. .example ist absichtlich ein Platzhalter.
  email: 'hallo@kleinteil.example',

  shipping: {
    flat: 490, // Cent, Versandkosten unter der Schwelle
    freeFrom: 6000, // Cent, ab hier versandkostenfrei
    countries: ['DE', 'AT'],
    dispatch: '1 bis 2 Werktage',
  },

  checkout: {
    // 'demo':   Warenkorb funktioniert, "Zur Kasse" zeigt nur einen Hinweis.
    // 'stripe': schickt den Warenkorb an `endpoint` und leitet zu Stripe weiter.
    //           Siehe README, Abschnitt "Bezahlen mit Stripe".
    mode: 'demo' as 'demo' | 'stripe',
    endpoint: '/api/checkout',
  },
};

// 4900 -> "49 €", 490 -> "4,90 €"
export const euro = (cents: number) => {
  const digits = cents % 100 === 0 ? 0 : 2;
  return new Intl.NumberFormat('de-DE', {
    style: 'currency',
    currency: 'EUR',
    minimumFractionDigits: digits,
    maximumFractionDigits: digits,
  }).format(cents / 100);
};
