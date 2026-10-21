import 'input_entries.dart';
import 'profile_link.dart';

List<String> parseClipboardProfileLinks(String text) {
  if (text.length > 2 * 1024 * 1024) {
    throw const FormatException();
  }
  final parsed = parseUrlInput(
    text,
    isValid: (value) => normalizeProfileLink(value) != null,
  );
  if (parsed.entries.isEmpty ||
      parsed.entries.length > 10000 ||
      parsed.issues.isNotEmpty) {
    throw const FormatException();
  }
  return parsed.entries
      .map((value) => normalizeProfileLink(value)!)
      .toSet()
      .toList();
}
