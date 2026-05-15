// Downloads the raw name corpora into memory-bank/name_datasets/ so the
// generation script can ground LLM output on real distributions.
// Idempotent — a `.fetched` marker file short-circuits subsequent runs.
// Delete the marker to force a refresh.
//
// Run from app/ via:
//   dart run tools/generate_names/dataset_fetch.dart

import 'dart:io';

const _corpora = [
  // Real-world human names.
  _Corpus(
    folder: 'philipperemy',
    repoUrl: 'https://github.com/philipperemy/name-dataset.git',
    description: 'philipperemy/name-dataset (per-country first + last)',
  ),
  _Corpus(
    folder: 'popular-names-by-country',
    repoUrl: 'https://github.com/sigpwned/popular-names-by-country-dataset.git',
    description: 'sigpwned/popular-names-by-country (top surnames)',
  ),

  // Era / decade-tagged human names (Victorian, 1920s, midcentury).
  _Corpus(
    folder: 'ssa-baby-names',
    repoUrl: 'https://github.com/hackerb9/ssa-baby-names.git',
    description: 'hackerb9/ssa-baby-names (US SSA 1880+, decade-tagged)',
  ),

  // Cyberpunk handles / aliases.
  _Corpus(
    folder: 'cyberpunk-names',
    repoUrl: 'https://github.com/mlane/cyberpunk-name-generator.git',
    description: 'mlane/cyberpunk-name-generator (cyberpunk handles)',
  ),

  // Fantasy races.
  _Corpus(
    folder: 'elf-name-generator',
    repoUrl: 'https://github.com/bradleynelson/elf-name-generator.git',
    description: 'bradleynelson/elf-name-generator (Elf/Dwarf/Orc/Halfling)',
  ),
  _Corpus(
    folder: 'fantasy-name-generator',
    repoUrl: 'https://github.com/FyefoxxM/fantasy-name-generator.git',
    description: 'FyefoxxM/fantasy-name-generator (race syllable pools)',
  ),
  _Corpus(
    folder: 'fantastical',
    repoUrl: 'https://github.com/seiyria/fantastical.git',
    description: 'seiyria/fantastical (Goblin/Demon/Angel/Fae/Dragon — JS embedded)',
  ),
  _Corpus(
    folder: 'dragon-names',
    repoUrl: 'https://github.com/kraihn/dragon-names.git',
    description: 'kraihn/dragon-names (dragons by source)',
  ),

  // Mythology (Greek / Norse / Egyptian / Hindu / Slavic / etc.).
  _Corpus(
    folder: 'mythology-names',
    repoUrl: 'https://github.com/repushko/mythology_names_dataset.git',
    description: 'repushko/mythology_names_dataset (4096 names by pantheon)',
  ),

  // Pre-materialised lists across 38 cultures + dwarf/elf/fantasy.
  _Corpus(
    folder: 'namegen',
    repoUrl: 'https://github.com/ironarachne/namegen.git',
    description: 'ironarachne/namegen (38 cultures + dwarf/elf/fantasy, Go arrays)',
  ),

  // Public-domain corpora (humans, mythology, lovecraft, Tolkien, etc.).
  _Corpus(
    folder: 'corpora',
    repoUrl: 'https://github.com/dariusk/corpora.git',
    description: 'dariusk/corpora (CC0 — humans / mythology / lovecraft / Tolkien chars)',
  ),
];

class _Corpus {
  const _Corpus({
    required this.folder,
    required this.repoUrl,
    required this.description,
  });
  final String folder;
  final String repoUrl;
  final String description;
}

Future<void> main() async {
  final root = Directory('../memory-bank/name_datasets');
  if (!root.existsSync()) {
    root.createSync(recursive: true);
  }

  final marker = File('${root.path}/.fetched');
  if (marker.existsSync()) {
    stdout.writeln('Datasets already fetched. Delete '
        '${marker.path} to refresh.');
    return;
  }

  for (final corpus in _corpora) {
    final target = Directory('${root.path}/${corpus.folder}');
    if (target.existsSync()) {
      stdout.writeln('[skip] ${corpus.folder} already present.');
      continue;
    }
    stdout.writeln('[clone] ${corpus.description}');
    final result = await Process.run(
      'git',
      ['clone', '--depth', '1', corpus.repoUrl, target.path],
    );
    if (result.exitCode != 0) {
      stderr.writeln('git clone failed for ${corpus.folder}:');
      stderr.writeln(result.stderr);
      exit(result.exitCode);
    }
  }

  marker.writeAsStringSync(DateTime.now().toIso8601String());
  stdout.writeln('Done. Marker written at ${marker.path}.');
}
