; The installer's hooks file (tauri.conf.json, bundle.windows.nsis.installerHooks), included by Tauri's NSIS
; template before its pages, so the defines below reach Modern UI 2. The board "Installer and desktop icon" puts
; the header picture at the header's right, and has both pictures also at 2x for high-DPI screens.
;
; Trap: Modern UI unpacks the 1x pictures into $PLUGINSDIR and shows the header in its .onGUIInit; the
; function below runs after that (MUI_CUSTOMFUNCTION_GUIINIT), so on a screen at 150 % or more it overwrites
; both files with the 2x ones and loads the header again; the welcome and finish pages read theirs later.
; ${__FILEDIR__} is this file's folder, as File's paths are otherwise the generated script's.

!define MUI_HEADERIMAGE_RIGHT

!macro CARDWAVE_PICTURES_2X
  System::Call "user32::GetDpiForWindow(p $HWNDPARENT) i .r0"
  ${If} $0 >= 144
    File "/oname=$PLUGINSDIR\modern-wizard.bmp" "${__FILEDIR__}\icons\sidebar@2x.bmp"
    File "/oname=$PLUGINSDIR\modern-header.bmp" "${__FILEDIR__}\icons\header@2x.bmp"
    SetBrandingImage /IMGID=1046 /RESIZETOFIT "$PLUGINSDIR\modern-header.bmp"
  ${EndIf}
!macroend

!define MUI_CUSTOMFUNCTION_GUIINIT CardwavePictures2x
Function CardwavePictures2x
  !insertmacro CARDWAVE_PICTURES_2X
FunctionEnd

!define MUI_CUSTOMFUNCTION_UNGUIINIT un.CardwavePictures2x
Function un.CardwavePictures2x
  !insertmacro CARDWAVE_PICTURES_2X
FunctionEnd
