const int kMinPassphraseLength = 4;

/// Returns an error message if [value] is shorter than [kMinPassphraseLength],
/// or null if it's long enough.
String? validatePassphraseLength(String value) {
  if (value.length < kMinPassphraseLength) {
    return 'Must be at least $kMinPassphraseLength characters';
  }
  return null;
}
