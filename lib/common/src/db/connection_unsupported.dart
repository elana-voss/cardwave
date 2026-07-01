import 'package:drift/drift.dart';

/// Placeholder for platforms with neither `dart:io` nor web support. The
/// conditional export in `drift_connection.dart` only resolves to this when
/// the app is built for an unsupported target.
Future<QueryExecutor> openDriftConnection({
  required String nativePath,
  required String webName,
}) =>
    throw UnsupportedError('No drift database backend on this platform.');
