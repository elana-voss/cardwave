//! The microphone in the app's window on Linux, the only module naming `webkit2gtk`.
//! WebKitGTK keeps `getUserMedia` off unless its setting `enable-media-stream`
//! is on (wry does not set it), and asks the app about each request, denying
//! what the app does not answer. Here a request for the microphone alone is
//! granted, and only while the window shows the app's own server (`origin`,
//! its address ending in "/") and loads nothing; every other request (the camera, the screen,
//! the location, another page) is denied. Windows' WebView2 asks nothing.

use tauri::WebviewWindow;
use webkit2gtk::glib::Cast;
use webkit2gtk::{
    PermissionRequestExt, SettingsExt, UserMediaPermissionRequest, UserMediaPermissionRequestExt,
    WebViewExt,
};

/// Switches the window's media stream on and answers its permission requests.
pub fn allow(window: &WebviewWindow, origin: &str) -> tauri::Result<()> {
    let origin = origin.to_owned();
    window.with_webview(move |webview| {
        let view = webview.inner();
        if let Some(settings) = WebViewExt::settings(&view) {
            settings.set_enable_media_stream(true);
        }
        view.connect_permission_request(move |view, request| {
            let ours = view
                .uri()
                .is_some_and(|uri| granted(&uri, view.is_loading(), &origin));
            let microphone = request
                .downcast_ref::<UserMediaPermissionRequest>()
                .is_some_and(|media| media.is_for_audio_device() && !media.is_for_video_device());
            if ours && microphone {
                request.allow();
            } else {
                request.deny();
            }
            true
        });
    })
}

/// Whether the page at `uri` is the app's own, served at `origin`. While a load
/// is under way WebKitGTK already names its address, though the page asking may
/// still be the one before (another site leaving for the app's address): none then.
fn granted(uri: &str, loading: bool, origin: &str) -> bool {
    !loading && uri.starts_with(origin)
}

#[cfg(test)]
mod tests {
    use super::granted;

    #[test]
    fn only_the_apps_own_address_is_granted() {
        let origin = "http://127.0.0.1:8477/";
        assert!(granted("http://127.0.0.1:8477/#/chat/1", false, origin));
        assert!(!granted("http://127.0.0.1:8477/#/chat/1", true, origin));
        assert!(!granted("http://127.0.0.1:84770/", false, origin));
        assert!(!granted(
            "https://example.com/http://127.0.0.1:8477/",
            false,
            origin
        ));
    }
}
