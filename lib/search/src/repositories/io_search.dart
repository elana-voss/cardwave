import 'dart:typed_data';

import 'package:cardwave/common/common.dart';

/// Raw bytes IO for the per-card sidecar file. No domain types; the
/// repository layer above wraps these in `CardSearchData` decode/encode.
class IoSearch {
  const IoSearch({required this.appStorage});

  final AppStorage appStorage;

  Future<bool> exists(String relativePath) =>
      appStorage.fileExists(StorageDomainEnum.cards, relativePath);

  Future<Uint8List> read(String relativePath) async {
    final bytes = await appStorage.readBytes(
      StorageDomainEnum.cards,
      relativePath,
    );
    return Uint8List.fromList(bytes);
  }

  Future<void> write(String relativePath, Uint8List bytes) =>
      appStorage.writeBytes(StorageDomainEnum.cards, relativePath, bytes);
}
