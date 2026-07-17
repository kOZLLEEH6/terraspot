/// Rechtstexte für TerraSpot.
///
/// ⚠️ WICHTIG: Dies sind VORLAGEN, kein anwaltlich geprüfter Text. Vor einer
/// Veröffentlichung (App Store / Play Store, kostenpflichtiges Abo, Verarbeitung
/// von Standort- und Fotodaten in der EU) müssen AGB, Datenschutzerklärung,
/// Impressum und Widerrufsbelehrung von einer Anwältin/einem Anwalt geprüft und
/// die Platzhalter (Anbieter, Adresse, Kontakt) ausgefüllt werden.
class Legal {
  static const version = 1;

  /// Kurzfassung, die im Zustimmungs-Dialog oben steht.
  static const summary =
      'Bevor du loslegst: TerraSpot zeigt von Nutzern erstellte Outdoor-Orte. '
      'Das Aufsuchen dieser Orte geschieht auf eigene Gefahr. Bitte lies und '
      'akzeptiere die folgenden Bedingungen.';

  static const List<LegalSection> sections = [
    LegalSection(
      icon: '⚠️',
      title: '1. Haftungsausschluss — Nutzung auf eigene Gefahr',
      body:
          'TerraSpot ist eine reine Informations- und Community-Plattform. Die '
          'angezeigten Orte, Wege, Zeiten, Schwierigkeitsgrade, Wetter- und '
          'Astronomiedaten stammen teils von anderen Nutzern und aus externen '
          'Quellen und können ungenau, veraltet oder falsch sein.\n\n'
          'Das Aufsuchen, Betreten und Fotografieren der gezeigten Orte sowie '
          'jede Wanderung, Klettertour, Camping- oder Outdoor-Aktivität erfolgt '
          'ausschließlich auf eigene Gefahr und Verantwortung. Natur ist '
          'gefährlich: Absturzgefahr, Wetterumschwünge, Lawinen, Gezeiten, '
          'Steinschlag, Wildtiere und weitere Risiken können zu schweren oder '
          'tödlichen Verletzungen führen.\n\n'
          'Der Anbieter übernimmt keine Haftung für Personen-, Sach- oder '
          'Vermögensschäden, die aus der Nutzung der App oder dem Aufsuchen von '
          'Orten entstehen, soweit gesetzlich zulässig. Prüfe eigene Ausrüstung, '
          'Kondition, Wetter, örtliche Regeln, Betretungsrechte und '
          'Naturschutzauflagen stets selbst und eigenverantwortlich. Beachte '
          'Sperrungen und respektiere Privatgrund.',
    ),
    LegalSection(
      icon: '📸',
      title: '2. Deine Inhalte & Community-Regeln',
      body:
          'Wenn du einen Spot mit Foto und Beschreibung erstellst, versicherst du, '
          'dass du die nötigen Rechte an den Inhalten hast und keine Rechte '
          'Dritter (Urheber-, Persönlichkeits-, Marken- oder Eigentumsrechte) '
          'verletzt. Du räumst dem Anbieter das einfache Recht ein, deine '
          'Inhalte innerhalb der App darzustellen.\n\n'
          'Verboten sind u. a.: rechtswidrige, beleidigende, jugendgefährdende '
          'oder irreführende Inhalte, das Preisgeben sensibler oder geschützter '
          'Orte sowie Spam. Gemeldete Inhalte können gesperrt und Nutzerkonten '
          'bei Verstößen eingeschränkt werden. Du bleibst für deine Inhalte '
          'selbst verantwortlich.',
    ),
    LegalSection(
      icon: '🔒',
      title: '3. Datenschutz',
      body:
          'TerraSpot verarbeitet Daten, um zu funktionieren:\n'
          '• Standort — nur mit deiner Erlaubnis, um Spots in deiner Nähe zu '
          'finden und beim Erstellen den Ort zu setzen. Er wird nicht dauerhaft '
          'im Hintergrund verfolgt.\n'
          '• Fotos & Spot-Angaben, die du selbst hochlädst.\n'
          '• Wetterdaten werden anonym anhand von Koordinaten abgefragt.\n'
          '• Konto- und Nutzungsdaten, soweit für den Betrieb nötig.\n\n'
          'Du hast das Recht auf Auskunft, Berichtigung, Löschung und '
          'Widerspruch (DSGVO). Details und Kontakt stehen in der '
          'Datenschutzerklärung. [Platzhalter: vollständige DSGVO-konforme '
          'Datenschutzerklärung ist vor Veröffentlichung zu ergänzen.]',
    ),
    LegalSection(
      icon: '⭐',
      title: '4. TerraSpot PRO — Abo, Verlängerung & Kündigung',
      body:
          'TerraSpot PRO ist ein kostenpflichtiges Abo (9,99 €/Monat). Es '
          'verlängert sich automatisch um jeweils einen Monat, bis du es '
          'kündigst.\n\n'
          'Du kannst jederzeit kündigen. Nach der Kündigung bleibt PRO bis zum '
          'Ende des bereits bezahlten Zeitraums aktiv und verlängert sich danach '
          'nicht mehr. Bereits gezahlte Beträge für den laufenden Zeitraum '
          'werden nicht anteilig erstattet, soweit gesetzlich zulässig.\n\n'
          'Widerrufsrecht: Bei digitalen Abos kann ein 14-tägiges Widerrufsrecht '
          'bestehen. [Platzhalter: Widerrufsbelehrung vor Veröffentlichung '
          'ergänzen.] Bei Kauf über App Store oder Google Play gelten zusätzlich '
          'deren Abrechnungs- und Kündigungsbedingungen.',
    ),
    LegalSection(
      icon: '📄',
      title: '5. Verfügbarkeit & Änderungen',
      body:
          'Ein unterbrechungsfreier Betrieb wird nicht garantiert. Der Anbieter '
          'darf die App weiterentwickeln, Funktionen ändern oder einstellen. '
          'Ändern sich diese Bedingungen wesentlich, wirst du erneut um '
          'Zustimmung gebeten.\n\n'
          'Mit deiner Zustimmung bestätigst du, dass du diese Bedingungen '
          'gelesen hast und ihnen zustimmst — insbesondere dem '
          'Haftungsausschluss unter Punkt 1.',
    ),
    LegalSection(
      icon: '🏢',
      title: '6. Impressum & Kontakt',
      body:
          'Angaben gemäß § 5 DDG (ehem. TMG):\n\n'
          '[Platzhalter — vor Veröffentlichung ausfüllen:]\n'
          'Anbieter: [Name / Firma, z. B. TerraSpot UG (haftungsbeschränkt)]\n'
          'Anschrift: [Straße, PLZ, Ort]\n'
          'Vertreten durch: [Geschäftsführer/in]\n'
          'E-Mail: [kontakt@…]\n'
          'Registergericht/-nummer: [falls vorhanden]\n'
          'USt-IdNr.: [falls vorhanden]\n\n'
          'Verantwortlich für den Inhalt. Diese Angaben sind derzeit '
          'Platzhalter und müssen vor einer Veröffentlichung durch die echten '
          'Daten des Anbieters ersetzt werden.',
    ),
  ];
}

class LegalSection {
  const LegalSection({
    required this.icon,
    required this.title,
    required this.body,
  });

  final String icon;
  final String title;
  final String body;
}
