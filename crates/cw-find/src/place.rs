//! A task's place where one works at a time, which the reader and the API's background tasks hold.

/// A task's place where one works at a time (a user's cards described, a
/// chat's memory pass, the cards read by the search model): given up when the
/// task ends, by a panic too, unless the task gave it up itself (`release`) in
/// the hold that found nothing more to do, after which another may hold it.
pub struct Place(Option<Box<dyn FnOnce() + Send>>);

impl Place {
    pub fn new(give_up: impl FnOnce() + Send + 'static) -> Self {
        Self(Some(Box::new(give_up)))
    }

    /// The task gave its place up itself.
    pub fn release(mut self) {
        self.0 = None;
    }
}

impl Drop for Place {
    fn drop(&mut self) {
        if let Some(give_up) = self.0.take() {
            give_up();
        }
    }
}
