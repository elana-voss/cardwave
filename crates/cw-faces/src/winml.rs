//! The model through Windows ML, on the graphics card Windows calls the high-performance one. Windows ML would run
//! on Microsoft's software adapter where a computer has no graphics card, which is the processor: `open` refuses
//! that. WinRT is begun in the multithreaded apartment on the thread that opens; a Session is used from there.

use anyhow::{Context, Result, bail, ensure};
use windows::AI::MachineLearning::{
    LearningModel, LearningModelBinding, LearningModelDevice, LearningModelDeviceKind,
    LearningModelEvaluationResult, LearningModelSession, TensorFloat,
};
use windows::Graphics::DisplayAdapterId;
use windows::Storage::Streams::{
    DataWriter, InMemoryRandomAccessStream, RandomAccessStreamReference,
};
use windows::Win32::Foundation::RPC_E_CHANGED_MODE;
use windows::Win32::Graphics::Dxgi::{
    CreateDXGIFactory1, DXGI_ADAPTER_FLAG_SOFTWARE, IDXGIFactory1,
};
use windows::Win32::System::WinRT::{RO_INIT_MULTITHREADED, RoInitialize};
use windows::core::{HSTRING, Interface};

use crate::{SQUARE, STRIDES, Stride};

const MODEL: &[u8] = include_bytes!("yunet.onnx");

pub(crate) struct Session(LearningModelSession);

impl Session {
    pub(crate) fn open() -> Result<Self> {
        // SAFETY: takes a value alone; the thread stays in the apartment, as a pool's thread may be asked again.
        match unsafe { RoInitialize(RO_INIT_MULTITHREADED) } {
            Ok(()) => {}
            // Another's single-threaded apartment on this thread: WinRT is begun all the same.
            Err(failure) if failure.code() == RPC_E_CHANGED_MODE => {}
            Err(failure) => return Err(failure).context("beginning WinRT"),
        }
        let device = LearningModelDevice::Create(LearningModelDeviceKind::DirectXHighPerformance)
            .context("opening the graphics card")?;
        on_hardware(device.AdapterId()?)?;
        let session = LearningModelSession::CreateFromModelOnDevice(&model()?, &device)
            .context("opening the face model on the graphics card")?;
        Ok(Self(session))
    }

    pub(crate) fn pass(&self, tensor: &[f32]) -> Result<Vec<Stride>> {
        let side = SQUARE as i64;
        let input = TensorFloat::CreateFromShapeArrayAndDataArray(&[1, 3, side, side], tensor)?;
        let binding = LearningModelBinding::CreateFromSession(&self.0)?;
        binding.Bind(&HSTRING::from("input"), &input)?;
        let result = self.0.Evaluate(&binding, &HSTRING::new())?;
        ensure!(
            result.Succeeded()?,
            "the face model failed: {:?}",
            result.ErrorStatus()
        );
        STRIDES
            .iter()
            .map(|&stride| {
                Ok(Stride {
                    stride,
                    cls: output(&result, &format!("cls_{stride}"))?,
                    obj: output(&result, &format!("obj_{stride}"))?,
                    bbox: output(&result, &format!("bbox_{stride}"))?,
                })
            })
            .collect()
    }
}

/// The model inside the app, as Windows ML reads one from memory.
fn model() -> Result<LearningModel> {
    let stream = InMemoryRandomAccessStream::new()?;
    let writer = DataWriter::CreateDataWriter(&stream)?;
    writer.WriteBytes(MODEL)?;
    writer.StoreAsync()?.join()?;
    writer.FlushAsync()?.join()?;
    writer.DetachStream()?;
    stream.Seek(0)?;
    let reference = RandomAccessStreamReference::CreateFromStream(&stream)?;
    Ok(LearningModel::LoadFromStream(&reference)?)
}

/// Refuses the adapter unless DXGI knows it as hardware.
fn on_hardware(adapter: DisplayAdapterId) -> Result<()> {
    // SAFETY: the calls take and answer values alone.
    let factory: IDXGIFactory1 = unsafe { CreateDXGIFactory1() }?;
    let mut index = 0;
    // SAFETY: as above; an index past the last ends the loop by its error.
    while let Ok(one) = unsafe { factory.EnumAdapters1(index) } {
        // SAFETY: as above.
        let description = unsafe { one.GetDesc1() }?;
        let luid = description.AdapterLuid;
        if luid.LowPart == adapter.LowPart && luid.HighPart == adapter.HighPart {
            ensure!(
                description.Flags & DXGI_ADAPTER_FLAG_SOFTWARE.0 as u32 == 0,
                "the only adapter is the software one: no graphics card to find faces on"
            );
            return Ok(());
        }
        index += 1;
    }
    bail!("the adapter Windows ML chose is not one DXGI knows")
}

fn output(result: &LearningModelEvaluationResult, name: &str) -> Result<Vec<f32>> {
    let tensor: TensorFloat = result.Outputs()?.Lookup(&HSTRING::from(name))?.cast()?;
    let view = tensor.GetAsVectorView()?;
    let mut values = vec![0f32; view.Size()? as usize];
    view.GetMany(0, &mut values)?;
    Ok(values)
}
