//! The model through Vulkan, by wgpu, off Windows (and on Windows in tests alone, to compare with Windows ML).
//! The ONNX file is read in place (`onnx.rs`), made into steps (`plan.rs`) and run by own kernels
//! (`kernels.wgsl`): each value is a buffer on the graphics card, made once at `open`, a pass writes the input,
//! runs every step in one compute pass and reads the outputs back. The adapter is a graphics card, the separate
//! one first; a Vulkan device that is the processor (lavapipe) is refused, so where there is no card `open` fails.
//! Traps: wgpu's futures are ready at once on Vulkan, so each is polled once; its errors would panic unless caught,
//! so all its work is inside error scopes, which belong to the thread that pushed them.

mod onnx;
mod plan;

use std::collections::HashMap;
use std::future::Future;
use std::pin::pin;
use std::sync::mpsc;
use std::task::{Context as TaskContext, Poll, Waker};

use anyhow::{Context, Result, bail, ensure};
use wgpu::{
    Adapter, Backends, BindGroup, BindGroupDescriptor, BindGroupEntry, Buffer, BufferDescriptor,
    BufferUsages, CommandEncoderDescriptor, ComputePassDescriptor, ComputePipeline,
    ComputePipelineDescriptor, Device, DeviceDescriptor, DeviceType, ErrorFilter, Instance,
    InstanceDescriptor, Limits, MapMode, PollType, Queue, ShaderModuleDescriptor, ShaderSource,
};

use crate::{SQUARE, STRIDES, Stride};
use onnx::Graph;
use plan::{Kernel, Plan};

const MODEL: &[u8] = include_bytes!("../yunet.onnx");
const KERNELS: &str = include_str!("kernels.wgsl");
/// Values a kernel's batch writes, its `@workgroup_size`.
const BATCH: u32 = 64;
/// Batches a dispatch has at most on a side.
const SIDE: u32 = 65_535;

/// The outputs read, per stride its class, object and box values.
pub(crate) fn wanted() -> Vec<String> {
    STRIDES
        .iter()
        .flat_map(|stride| ["cls", "obj", "bbox"].map(|name| format!("{name}_{stride}")))
        .collect()
}

pub(crate) struct Session {
    device: Device,
    queue: Queue,
    input: Buffer,
    /// Per step its pipeline, bindings and batches.
    steps: Vec<(ComputePipeline, BindGroup, (u32, u32))>,
    /// Per wanted output its value's buffer and length.
    outputs: Vec<(Buffer, usize)>,
    /// Where the outputs are copied to be read, one after another.
    staging: Buffer,
}

impl Session {
    pub(crate) fn open() -> Result<Self> {
        let adapter = card()?.context("no graphics card with Vulkan to find faces on")?;
        let (device, queue) = now(adapter.request_device(&DeviceDescriptor {
            label: Some("faces"),
            required_limits: Limits::downlevel_defaults(),
            ..Default::default()
        }))?
        .context("opening the graphics card")?;
        let plan = Plan::new(
            &Graph::read(MODEL)?,
            ("input", vec![1, 3, SQUARE as usize, SQUARE as usize]),
            &wanted(),
        )?;
        caught(&device, || Self::build(device.clone(), queue, &plan))
            .context("opening the face model on the graphics card")
    }

    /// The buffers, pipelines and bindings of a plan.
    fn build(device: Device, queue: Queue, plan: &Plan) -> Result<Self> {
        let usage = BufferUsages::STORAGE | BufferUsages::COPY_DST | BufferUsages::COPY_SRC;
        let values: Vec<Buffer> = plan
            .sizes
            .iter()
            .map(|&size| buffer(&device, size * 4, usage))
            .collect();
        for (value, floats) in &plan.weights {
            queue.write_buffer(&values[*value], 0, &bytes(floats));
        }
        let module = device.create_shader_module(ShaderModuleDescriptor {
            label: Some("faces"),
            source: ShaderSource::Wgsl(KERNELS.into()),
        });
        let pipelines: HashMap<Kernel, ComputePipeline> = Kernel::ALL
            .into_iter()
            .map(|kernel| {
                let pipeline = device.create_compute_pipeline(&ComputePipelineDescriptor {
                    label: Some(kernel.entry()),
                    layout: None,
                    module: &module,
                    entry_point: Some(kernel.entry()),
                    compilation_options: Default::default(),
                    cache: None,
                });
                (kernel, pipeline)
            })
            .collect();
        let mut steps = vec![];
        for step in &plan.steps {
            let pipeline = pipelines[&step.kernel].clone();
            let numbers = buffer(&device, 64, BufferUsages::UNIFORM | BufferUsages::COPY_DST);
            queue.write_buffer(
                &numbers,
                0,
                &step
                    .numbers
                    .iter()
                    .flat_map(|one| one.to_le_bytes())
                    .collect::<Vec<_>>(),
            );
            // The kernel's `a`, `b`, `c` are bindings 1 to 3, `out` 4; it binds only those it reads.
            let mut entries = vec![BindGroupEntry {
                binding: 0,
                resource: numbers.as_entire_binding(),
            }];
            for (at, value) in step.reads.iter().enumerate() {
                entries.push(BindGroupEntry {
                    binding: at as u32 + 1,
                    resource: values[*value].as_entire_binding(),
                });
            }
            entries.push(BindGroupEntry {
                binding: 4,
                resource: values[step.writes].as_entire_binding(),
            });
            let bindings = device.create_bind_group(&BindGroupDescriptor {
                label: None,
                layout: &pipeline.get_bind_group_layout(0),
                entries: &entries,
            });
            steps.push((pipeline, bindings, batches(step.numbers[0])?));
        }
        let outputs: Vec<(Buffer, usize)> = plan
            .outputs
            .iter()
            .map(|(_, value)| (values[*value].clone(), plan.sizes[*value]))
            .collect();
        let total: usize = outputs.iter().map(|(_, size)| size).sum();
        let staging = buffer(
            &device,
            total * 4,
            BufferUsages::MAP_READ | BufferUsages::COPY_DST,
        );
        Ok(Self {
            input: values[plan.input].clone(),
            device,
            queue,
            steps,
            outputs,
            staging,
        })
    }

    pub(crate) fn pass(&self, tensor: &[f32]) -> Result<Vec<Stride>> {
        ensure!(
            tensor.len() * 4 == self.input.size() as usize,
            "the face model reads a square of 3 by {SQUARE}"
        );
        let read = caught(&self.device, || self.run(tensor))?;
        let mut read = read.into_iter();
        let mut next = || {
            read.next()
                .context("the face model answered too few outputs")
        };
        STRIDES
            .iter()
            .map(|&stride| {
                Ok(Stride {
                    stride,
                    cls: next()?,
                    obj: next()?,
                    bbox: next()?,
                })
            })
            .collect()
    }

    /// The outputs of one pass, in the order of [`wanted`].
    fn run(&self, tensor: &[f32]) -> Result<Vec<Vec<f32>>> {
        self.queue.write_buffer(&self.input, 0, &bytes(tensor));
        let mut encoder = self
            .device
            .create_command_encoder(&CommandEncoderDescriptor { label: None });
        {
            let mut pass = encoder.begin_compute_pass(&ComputePassDescriptor {
                label: None,
                timestamp_writes: None,
            });
            for (pipeline, bindings, (across, down)) in &self.steps {
                pass.set_pipeline(pipeline);
                pass.set_bind_group(0, bindings, &[]);
                pass.dispatch_workgroups(*across, *down, 1);
            }
        }
        let mut offset = 0;
        for (buffer, size) in &self.outputs {
            let length = (*size * 4) as u64;
            encoder.copy_buffer_to_buffer(buffer, 0, &self.staging, offset, length);
            offset += length;
        }
        self.queue.submit([encoder.finish()]);
        let slice = self.staging.slice(..);
        let (sender, mapped) = mpsc::channel();
        slice.map_async(MapMode::Read, move |result| {
            // The receiver waits below; were it gone, there would be no one to tell.
            let _ = sender.send(result);
        });
        self.device
            .poll(PollType::Wait {
                submission_index: None,
                timeout: None,
            })
            .context("waiting for the graphics card")?;
        mapped.recv()?.context("reading the face model's answer")?;
        let floats: Vec<f32> = {
            let view = slice
                .get_mapped_range()
                .map_err(|failure| anyhow::anyhow!("{failure:?}"))?;
            view.as_chunks::<4>()
                .0
                .iter()
                .map(|four| f32::from_le_bytes(*four))
                .collect()
        };
        self.staging.unmap();
        let mut at = 0;
        Ok(self
            .outputs
            .iter()
            .map(|(_, size)| {
                at += size;
                floats[at - size..at].to_vec()
            })
            .collect())
    }
}

/// The graphics card the model runs on, the best by `rank`; None where Vulkan has none.
pub(crate) fn card() -> Result<Option<Adapter>> {
    let instance = Instance::new(InstanceDescriptor {
        backends: Backends::VULKAN,
        ..InstanceDescriptor::new_without_display_handle()
    });
    let adapters = now(instance.enumerate_adapters(Backends::VULKAN))?;
    Ok(adapters
        .into_iter()
        .filter_map(|adapter| rank(adapter.get_info().device_type).map(|rank| (rank, adapter)))
        .min_by_key(|(rank, _)| *rank)
        .map(|(_, adapter)| adapter))
}

/// How an adapter is preferred, the lowest first: a separate graphics card, the built-in one, a virtual one, any
/// other. None for the processor, which is never used.
fn rank(kind: DeviceType) -> Option<u8> {
    match kind {
        DeviceType::DiscreteGpu => Some(0),
        DeviceType::IntegratedGpu => Some(1),
        DeviceType::VirtualGpu => Some(2),
        DeviceType::Other => Some(3),
        DeviceType::Cpu => None,
    }
}

/// The batches a step's `n` values take, across and down, as `kernels.wgsl`'s `index` lays them out.
fn batches(n: u32) -> Result<(u32, u32)> {
    let total = n.div_ceil(BATCH).max(1);
    let across = total.min(SIDE);
    let down = total.div_ceil(across);
    ensure!(
        down <= SIDE,
        "a step of the face model writes too many values"
    );
    Ok((across, down))
}

fn buffer(device: &Device, size: usize, usage: BufferUsages) -> Buffer {
    device.create_buffer(&BufferDescriptor {
        label: None,
        size: size.max(4) as u64,
        usage,
        mapped_at_creation: false,
    })
}

fn bytes(floats: &[f32]) -> Vec<u8> {
    floats.iter().flat_map(|one| one.to_le_bytes()).collect()
}

/// `work`, with what wgpu finds wrong in it (an invalid step, too little memory) as its error, not a panic.
fn caught<T>(device: &Device, work: impl FnOnce() -> Result<T>) -> Result<T> {
    // Internal is what a driver's refusal (of a pipeline, say) comes as; uncaught, it would panic.
    let internal = device.push_error_scope(ErrorFilter::Internal);
    let memory = device.push_error_scope(ErrorFilter::OutOfMemory);
    let validation = device.push_error_scope(ErrorFilter::Validation);
    let done = work();
    let invalid = now(validation.pop())?;
    let short = now(memory.pop())?;
    let refused = now(internal.pop())?;
    if let Some(failure) = invalid.or(short).or(refused) {
        bail!("the graphics card refused the face model: {failure}");
    }
    done
}

/// A future of wgpu's, which on Vulkan is ready when made.
fn now<F: Future>(future: F) -> Result<F::Output> {
    match pin!(future).poll(&mut TaskContext::from_waker(Waker::noop())) {
        Poll::Ready(output) => Ok(output),
        Poll::Pending => bail!("the graphics card did not answer at once"),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_processor_is_never_chosen_and_a_separate_card_first() {
        assert_eq!(rank(DeviceType::Cpu), None);
        assert!(rank(DeviceType::DiscreteGpu) < rank(DeviceType::IntegratedGpu));
    }

    #[test]
    fn a_large_step_takes_batches_down_as_well() {
        assert_eq!(batches(64).unwrap(), (1, 1));
        assert_eq!(batches(65).unwrap(), (2, 1));
        assert_eq!(batches(SIDE * BATCH + 1).unwrap(), (SIDE, 2));
    }
}
