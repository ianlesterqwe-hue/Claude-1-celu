/// Información técnica para la pantalla "Información del dispositivo".
///
/// Los adaptadores son responsables de censurar identificadores y de NO
/// incluir nunca secretos (local key, tokens, contraseñas).
class DiagnosticsEntry {
  const DiagnosticsEntry(this.label, this.value);
  final String label;
  final String value;
}

class DiagnosticsSection {
  const DiagnosticsSection(this.title, this.entries);
  final String title;
  final List<DiagnosticsEntry> entries;
}

/// Censura un identificador dejando visibles sólo los extremos:
/// `bf1234567890abcdef` → `bf12…cdef`.
String redactId(String? id, {int keep = 4}) {
  if (id == null || id.isEmpty) return '—';
  if (id.length <= keep * 2) return '${id[0]}…';
  return '${id.substring(0, keep)}…${id.substring(id.length - keep)}';
}
