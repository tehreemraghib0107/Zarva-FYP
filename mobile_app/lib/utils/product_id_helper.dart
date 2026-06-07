/// Normalizes MongoDB product ids from API maps / strings.
String? normalizeProductId(dynamic value) {
  if (value == null) return null;
  if (value is Map) {
    final id = value['_id'] ?? value['id'];
    if (id == null) return null;
    return id.toString();
  }
  final s = value.toString().trim();
  return s.isEmpty ? null : s;
}

Set<String> favoriteIdsFromApi(List<dynamic> favorites) {
  final ids = <String>{};
  for (final fav in favorites) {
    if (fav is! Map) continue;
    final id = normalizeProductId(fav['productId']);
    if (id != null) ids.add(id);
  }
  return ids;
}
