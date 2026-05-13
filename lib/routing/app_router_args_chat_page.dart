import 'package:cardwave/character/character.dart';
import 'package:cardwave/workspace/workspace.dart';

class AppRouterArgsChatPage {
  const AppRouterArgsChatPage(
    this.characterFile, [
    this.base = WorkspaceBaseEnum.chat,
  ]);
  final CharacterFile characterFile;
  final WorkspaceBaseEnum base;
}
