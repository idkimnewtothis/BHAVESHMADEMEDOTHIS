/// URL rules shared by pasted URLs, deep links, persisted repos and redirects.
abstract final class RepositoryUrl {
  static Uri normalize(String input) {
    var value = input.trim();
    if (!value.contains('://')) value = 'https://$value';
    var uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const FormatException(
          'Enter an HTTPS repository URL without credentials');
    }
    if (uri.host.toLowerCase() == 'github.com') {
      final parts = uri.pathSegments.toList();
      if (parts.length >= 4 && {'raw', 'blob', 'tree'}.contains(parts[2])) {
        parts.removeAt(2);
        uri =
            uri.replace(host: 'raw.githubusercontent.com', pathSegments: parts);
      } else if (parts.length == 2 ||
          (parts.length == 3 && parts.last.isEmpty)) {
        // Extension repositories conventionally publish to the repo branch.
        uri = uri.replace(
            host: 'raw.githubusercontent.com',
            pathSegments: [parts[0], parts[1], 'repo', 'repo.json']);
      }
    }
    final path = uri.path.toLowerCase();
    if (!path.endsWith('.json') &&
        !path.endsWith('.pb') &&
        !path.endsWith('.pb.gz') &&
        !path.endsWith('.json.gz')) {
      uri = uri.replace(
          path: '${uri.path.replaceFirst(RegExp(r'/+$'), '')}/repo.json');
    }
    return uri.removeFragment();
  }
}
