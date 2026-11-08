//! Off Windows: no way to the graphics card here, so no faces.

use anyhow::{Result, bail};

use crate::Stride;

pub(crate) struct Session;

impl Session {
    pub(crate) fn open() -> Result<Self> {
        bail!("finding faces needs Windows ML")
    }

    pub(crate) fn pass(&self, _tensor: &[f32]) -> Result<Vec<Stride>> {
        bail!("finding faces needs Windows ML")
    }
}
