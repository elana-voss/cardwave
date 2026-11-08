//! How the app serves the other crates: the search's host, which failures are
//! the app's own, and what coding's tools and tasks ask of it.

use std::sync::{Arc, MutexGuard};

use crate::AppState;

impl cw_find::Host for AppState {
    fn search(&self) -> &cw_find::reader::Search {
        &self.search
    }

    fn storage(&self) -> &dyn cw_find::Storage {
        &self.db
    }

    fn held(&self) -> Arc<dyn cw_find::Host> {
        Arc::new(self.clone())
    }
}

impl cw_library::failures::Failures for AppState {
    fn failed_in(&self, error: &anyhow::Error) -> bool {
        crate::api::failed_here(error)
    }
}

impl cw_coding::ports::AppActions for AppState {
    fn store(&self) -> &dyn cw_coding::ports::Storage {
        &self.db
    }

    fn chat(&self) -> Box<dyn cw_coding::ports::ChatSide + '_> {
        Box::new(cw_chat::chats::Side(&self.db))
    }

    fn http(&self) -> &cw_provider::Http {
        &self.http
    }

    fn web(&self) -> &cw_coding::tools::web::Web {
        &self.web
    }

    fn data_dir(&self) -> &std::path::Path {
        &self.data_dir
    }

    fn tasks(&self) -> MutexGuard<'_, cw_coding::coding::run::Tasks> {
        self.coding()
    }
}

impl AppState {
    /// The app as coding's tools and tasks ask it.
    pub(crate) fn actions(&self) -> Arc<dyn cw_coding::ports::AppActions> {
        Arc::new(self.clone())
    }
}
