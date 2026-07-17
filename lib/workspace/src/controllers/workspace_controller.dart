import 'package:cardwave/workspace/src/models/chat_page_mode_enum.dart';
import 'package:cardwave/workspace/src/models/workspace_base_enum.dart';
import 'package:flutter/foundation.dart';

class WorkspaceController extends ChangeNotifier {
  WorkspaceController({required WorkspaceBaseEnum initialBase})
    : _base = initialBase;
  WorkspaceBaseEnum _base;
  bool _chatSidePanel = false;
  bool _isDisposed = false;

  WorkspaceBaseEnum get base => _base;
  bool get chatSidePanel => _chatSidePanel;

  ChatPageModeEnum effectiveMode(bool isWideScreen) {
    switch (_base) {
      case WorkspaceBaseEnum.chat:
        return (_chatSidePanel && isWideScreen)
            ? ChatPageModeEnum.splitChatEditor
            : ChatPageModeEnum.chat;
      case WorkspaceBaseEnum.editor:
        return ChatPageModeEnum.editor;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void setBase(WorkspaceBaseEnum newBase) {
    if (_isDisposed || _base == newBase) return;
    _base = newBase;
    notifyListeners();
  }

  void toggleChatSidePanel() {
    if (_isDisposed) return;
    _chatSidePanel = !_chatSidePanel;
    notifyListeners();
  }
}
