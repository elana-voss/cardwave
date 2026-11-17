//! The graph made into steps for `kernels.wgsl`: each value's size, the weights to load, and per node the kernel,
//! the values it reads and writes and its numbers, in the order the kernel's comment gives them. Only the nodes
//! the wanted outputs need are kept (YuNet's `kps_*` are not). Shapes are worked out here from the input's, one
//! picture of 3 by SQUARE by SQUARE. A Reshape writes nothing: its output is its input's value, read anew.
//! Anything YuNet does not hold (another op, dilation, uneven padding, a scale that is not whole) is refused.

use std::collections::{HashMap, HashSet};

use anyhow::{Context, Result, bail, ensure};

use super::onnx::{Constant, Graph, Node};

/// The kernels of `kernels.wgsl`, by their entry point.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub(crate) enum Kernel {
    Conv,
    Relu,
    Sigmoid,
    Add,
    MaxPool,
    Resize,
    Transpose,
}

impl Kernel {
    pub(crate) const ALL: [Kernel; 7] = [
        Kernel::Conv,
        Kernel::Relu,
        Kernel::Sigmoid,
        Kernel::Add,
        Kernel::MaxPool,
        Kernel::Resize,
        Kernel::Transpose,
    ];

    pub(crate) fn entry(self) -> &'static str {
        match self {
            Kernel::Conv => "conv",
            Kernel::Relu => "relu",
            Kernel::Sigmoid => "sigmoid",
            Kernel::Add => "add",
            Kernel::MaxPool => "max_pool",
            Kernel::Resize => "resize",
            Kernel::Transpose => "transpose",
        }
    }
}

/// One dispatch: what it reads (the kernel's `a`, `b`, `c` in order), what it writes, and its numbers.
pub(crate) struct Step {
    pub kernel: Kernel,
    pub reads: Vec<usize>,
    pub writes: usize,
    /// The kernel's `p`; the first is how many values it writes.
    pub numbers: [u32; 16],
}

pub(crate) struct Plan {
    /// Each value's length in floats, by its number.
    pub sizes: Vec<usize>,
    /// The values loaded once, the weights and biases.
    pub weights: Vec<(usize, Vec<f32>)>,
    pub input: usize,
    pub steps: Vec<Step>,
    /// The wanted outputs, by name, in the order asked.
    pub outputs: Vec<(String, usize)>,
}

/// A value while planning: its number and shape.
type Shaped = (usize, Vec<usize>);
/// A step before it is placed: its kernel, the values it reads, its output's shape and its numbers.
type Built = (Kernel, Vec<usize>, Vec<usize>, Vec<u32>);

fn count(shape: &[usize]) -> u32 {
    shape.iter().product::<usize>() as u32
}

impl Plan {
    /// The steps from `input` (named so in the graph) to the outputs `wanted`.
    pub(crate) fn new(graph: &Graph, input: (&str, Vec<usize>), wanted: &[String]) -> Result<Self> {
        let needed = needed(graph, wanted)?;
        let mut plan = Plan {
            sizes: vec![],
            weights: vec![],
            input: 0,
            steps: vec![],
            outputs: vec![],
        };
        let mut known: HashMap<&str, Shaped> = HashMap::new();
        plan.input = plan.value(&input.1);
        known.insert(input.0, (plan.input, input.1));
        for node in graph
            .nodes
            .iter()
            .filter(|node| needed.contains(&node.key()))
        {
            let shaped = plan.step(graph, node, &mut known)?;
            let name = node
                .outputs
                .first()
                .context("a node of the face model has no output")?;
            known.insert(name, shaped);
        }
        for name in wanted {
            let (value, _) = known
                .get(name.as_str())
                .with_context(|| format!("the face model has no {name}"))?;
            plan.outputs.push((name.clone(), *value));
        }
        Ok(plan)
    }

    /// A new value of `shape`.
    fn value(&mut self, shape: &[usize]) -> usize {
        self.sizes.push(shape.iter().product::<usize>().max(1));
        self.sizes.len() - 1
    }

    /// A node's input: a value worked out before, or a weight, loaded once.
    fn read<'g>(
        &mut self,
        graph: &'g Graph,
        known: &mut HashMap<&'g str, Shaped>,
        name: &'g str,
    ) -> Result<Shaped> {
        if let Some(shaped) = known.get(name) {
            return Ok(shaped.clone());
        }
        let constant = graph
            .constants
            .get(name)
            .with_context(|| format!("the face model reads {name} before it is made"))?;
        ensure!(
            !constant.floats.is_empty(),
            "the face model's weight {name} holds no floats"
        );
        let value = self.value(&constant.shape);
        self.weights.push((value, constant.floats.clone()));
        known.insert(name, (value, constant.shape.clone()));
        Ok((value, constant.shape.clone()))
    }

    fn step<'g>(
        &mut self,
        graph: &'g Graph,
        node: &'g Node,
        known: &mut HashMap<&'g str, Shaped>,
    ) -> Result<Shaped> {
        let first = node
            .inputs
            .first()
            .context("a node of the face model has no input")?;
        let (from, shape) = self.read(graph, known, first)?;
        let (kernel, reads, out, numbers) = match node.op.as_str() {
            "Conv" => self.conv(graph, known, node, from, &shape)?,
            "Relu" | "Sigmoid" => {
                let kernel = if node.op == "Relu" {
                    Kernel::Relu
                } else {
                    Kernel::Sigmoid
                };
                (kernel, vec![from], shape.clone(), vec![count(&shape)])
            }
            "Add" => self.add(graph, known, node, from, &shape)?,
            "MaxPool" => Self::pool(node, from, &shape)?,
            "Resize" => Self::resize(graph, node, from, &shape)?,
            "Transpose" => Self::transpose(node, from, &shape)?,
            "Reshape" => {
                let target = node
                    .inputs
                    .get(1)
                    .and_then(|name| graph.constants.get(name));
                let out = reshaped(&shape, target)?;
                return Ok((from, out));
            }
            other => bail!("the face model holds the step {other}, which is not run here"),
        };
        let writes = self.value(&out);
        let mut padded = [0u32; 16];
        ensure!(
            numbers.len() <= padded.len(),
            "a step of the face model has too many numbers"
        );
        padded[..numbers.len()].copy_from_slice(&numbers);
        self.steps.push(Step {
            kernel,
            reads,
            writes,
            numbers: padded,
        });
        Ok((writes, out))
    }

    /// A convolution.
    fn conv<'g>(
        &mut self,
        graph: &'g Graph,
        known: &mut HashMap<&'g str, Shaped>,
        node: &'g Node,
        from: usize,
        shape: &[usize],
    ) -> Result<Built> {
        let [_, channels, h, w] = four(shape)?;
        ensure!(
            node.inputs.len() == 3,
            "a convolution of the face model has no bias"
        );
        let (weight, kernel_shape) = self.read(graph, known, &node.inputs[1])?;
        let (bias, _) = self.read(graph, known, &node.inputs[2])?;
        let [out_channels, _, k, k_across] = four(&kernel_shape)?;
        ensure!(
            k == k_across,
            "a convolution of the face model is not square"
        );
        ensure!(
            all(node, "dilations", 1),
            "a convolution of the face model is dilated"
        );
        let pad = padding(node)?;
        ensure!(
            h.min(w) + 2 * pad >= k,
            "a convolution of the face model is larger than its input"
        );
        let stride = one(node, "strides")?;
        let groups = ints(node, "group")
            .and_then(|group| group.first())
            .copied()
            .unwrap_or(1) as usize;
        ensure!(
            channels % groups == 0 && out_channels % groups == 0,
            "a convolution's groups do not fit"
        );
        let side = |length: usize| (length + 2 * pad - k) / stride + 1;
        let out = vec![1, out_channels, side(h), side(w)];
        let numbers = [
            count(&out),
            channels as u32,
            h as u32,
            w as u32,
            out_channels as u32,
        ];
        let rest = [side(h), side(w), k, stride, pad, groups].map(|one| one as u32);
        Ok((
            Kernel::Conv,
            vec![from, weight, bias],
            out,
            [&numbers[..], &rest].concat(),
        ))
    }

    /// A max pooling.
    fn pool(node: &Node, from: usize, shape: &[usize]) -> Result<Built> {
        let [_, channels, h, w] = four(shape)?;
        ensure!(
            padding(node)? == 0 && all(node, "ceil_mode", 0) && all(node, "dilations", 1),
            "a pooling of the face model pads or is dilated"
        );
        let k = one(node, "kernel_shape")?;
        let stride = one(node, "strides")?;
        ensure!(
            h.min(w) >= k,
            "a pooling of the face model is larger than its input"
        );
        let out = vec![1, channels, (h - k) / stride + 1, (w - k) / stride + 1];
        let numbers = [
            count(&out),
            h as u32,
            w as u32,
            out[2] as u32,
            out[3] as u32,
            k as u32,
            stride as u32,
        ];
        Ok((Kernel::MaxPool, vec![from], out, numbers.to_vec()))
    }

    /// A nearest resizing.
    fn resize(graph: &Graph, node: &Node, from: usize, shape: &[usize]) -> Result<Built> {
        let [_, channels, h, w] = four(shape)?;
        let text = |name: &str| node.texts.get(name).map(String::as_str);
        ensure!(
            text("mode") == Some("nearest")
                && text("coordinate_transformation_mode") == Some("asymmetric")
                && text("nearest_mode") == Some("floor"),
            "a resizing of the face model is not nearest, asymmetric and rounded down"
        );
        let scales = node
            .inputs
            .get(2)
            .and_then(|name| graph.constants.get(name));
        let [_, _, down, across] = whole_scales(scales)?;
        let out = vec![1, channels, h * down, w * across];
        let numbers = [
            count(&out),
            h as u32,
            w as u32,
            out[2] as u32,
            out[3] as u32,
            down as u32,
            across as u32,
        ];
        Ok((Kernel::Resize, vec![from], out, numbers.to_vec()))
    }

    /// A transposition of four axes.
    fn transpose(node: &Node, from: usize, shape: &[usize]) -> Result<Built> {
        let perm = ints(node, "perm").context("a transposition of the face model has no order")?;
        ensure!(
            perm.len() == 4 && shape.len() == 4,
            "a transposition of the face model is not of four axes"
        );
        let steps = [
            shape[1] * shape[2] * shape[3],
            shape[2] * shape[3],
            shape[3],
            1,
        ];
        let axis = |i: usize| usize::try_from(perm[i]).ok().filter(|&axis| axis < 4);
        let order = [0, 1, 2, 3].map(axis);
        let order: Vec<usize> = order
            .into_iter()
            .collect::<Option<_>>()
            .context("a transposition's order is out of range")?;
        let out: Vec<usize> = order.iter().map(|&axis| shape[axis]).collect();
        let numbers = [count(&out), out[1] as u32, out[2] as u32, out[3] as u32];
        let steps = order.iter().map(|&axis| steps[axis] as u32);
        Ok((
            Kernel::Transpose,
            vec![from],
            out.clone(),
            numbers.into_iter().chain(steps).collect(),
        ))
    }

    /// An addition of two values of one shape.
    fn add<'g>(
        &mut self,
        graph: &'g Graph,
        known: &mut HashMap<&'g str, Shaped>,
        node: &'g Node,
        from: usize,
        shape: &[usize],
    ) -> Result<Built> {
        let other = node
            .inputs
            .get(1)
            .context("an addition of the face model has one input")?;
        let (other, other_shape) = self.read(graph, known, other)?;
        ensure!(
            other_shape == shape,
            "an addition of the face model adds unlike shapes"
        );
        Ok((
            Kernel::Add,
            vec![from, other],
            shape.to_vec(),
            vec![count(shape)],
        ))
    }
}

impl Node {
    /// A node is known by its first output.
    fn key(&self) -> &str {
        self.outputs.first().map(String::as_str).unwrap_or_default()
    }
}

/// The first outputs of the nodes the outputs `wanted` are made by, walked back from them.
fn needed<'g>(graph: &'g Graph, wanted: &[String]) -> Result<HashSet<&'g str>> {
    let maker: HashMap<&str, &Node> = graph
        .nodes
        .iter()
        .flat_map(|node| {
            node.outputs
                .iter()
                .map(move |output| (output.as_str(), node))
        })
        .collect();
    let mut needed = HashSet::new();
    let mut open: Vec<&str> = wanted.iter().map(String::as_str).collect();
    while let Some(name) = open.pop() {
        let Some(node) = maker.get(name) else {
            continue;
        };
        if needed.insert(node.key()) {
            open.extend(node.inputs.iter().map(String::as_str));
        }
    }
    for name in wanted {
        ensure!(
            maker.contains_key(name.as_str()),
            "the face model makes no {name}"
        );
    }
    Ok(needed)
}

fn ints<'n>(node: &'n Node, name: &str) -> Option<&'n [i64]> {
    node.ints.get(name).map(Vec::as_slice)
}

/// Whether every number of the attribute is `value`, an attribute left out counting as so.
fn all(node: &Node, name: &str, value: i64) -> bool {
    ints(node, name).is_none_or(|numbers| numbers.iter().all(|&one| one == value))
}

/// The one number an attribute holds for both sides, as its sides must match.
fn one(node: &Node, name: &str) -> Result<usize> {
    let numbers = ints(node, name)
        .with_context(|| format!("a {} of the face model has no {name}", node.op))?;
    let first = *numbers
        .first()
        .with_context(|| format!("a {} of the face model has an empty {name}", node.op))?;
    ensure!(
        numbers.iter().all(|&one| one == first),
        "a {} of the face model is not square",
        node.op
    );
    usize::try_from(first)
        .with_context(|| format!("a {} of the face model has a negative {name}", node.op))
}

/// The padding a node gives every side alike, set by `pads` alone (0 where left out); refused where `auto_pad`
/// sets it, or `pads` is empty, uneven or negative.
fn padding(node: &Node) -> Result<usize> {
    ensure!(
        node.texts
            .get("auto_pad")
            .is_none_or(|text| text == "NOTSET"),
        "a {} of the face model pads by auto_pad",
        node.op
    );
    match ints(node, "pads") {
        None => Ok(0),
        Some(_) => one(node, "pads"),
    }
}

fn four(shape: &[usize]) -> Result<[usize; 4]> {
    shape
        .try_into()
        .ok()
        .with_context(|| format!("the face model holds a value of shape {shape:?}, not four axes"))
}

/// A Resize's scales, each a whole number.
fn whole_scales(scales: Option<&Constant>) -> Result<[usize; 4]> {
    let scales = scales.context("a resizing of the face model has no constant scales")?;
    let whole: Vec<usize> = scales
        .floats
        .iter()
        .filter(|&&scale| scale >= 1. && scale.fract() == 0.)
        .map(|&scale| scale as usize)
        .collect();
    ensure!(
        whole.len() == scales.floats.len(),
        "a resizing of the face model scales by a part"
    );
    let whole: [usize; 4] = whole
        .try_into()
        .ok()
        .context("a resizing of the face model is not of four axes")?;
    ensure!(
        whole[0] == 1 && whole[1] == 1,
        "a resizing of the face model scales pictures or channels"
    );
    Ok(whole)
}

/// A Reshape's new shape: 0 keeps the axis, -1 takes what is left.
fn reshaped(shape: &[usize], target: Option<&Constant>) -> Result<Vec<usize>> {
    let target = target.context("a reshaping of the face model has no constant shape")?;
    let total: usize = shape.iter().product();
    let mut out = vec![];
    let mut open = None;
    for (axis, &length) in target.ints.iter().enumerate() {
        match length {
            0 => out.push(
                *shape
                    .get(axis)
                    .context("a reshaping keeps an axis that is not there")?,
            ),
            -1 if open.is_none() => {
                open = Some(axis);
                out.push(1);
            }
            length if length > 0 => out.push(length as usize),
            _ => bail!("a reshaping of the face model has the length {length}"),
        }
    }
    let known: usize = out.iter().product();
    ensure!(
        known > 0 && total.is_multiple_of(known),
        "a reshaping of the face model changes the count"
    );
    if let Some(axis) = open {
        out[axis] = total / known;
    }
    ensure!(
        out.iter().product::<usize>() == total,
        "a reshaping of the face model changes the count"
    );
    Ok(out)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{SQUARE, STRIDES};

    fn plan() -> Plan {
        let graph = Graph::read(include_bytes!("../yunet.onnx")).unwrap();
        let wanted = super::super::wanted();
        Plan::new(
            &graph,
            ("input", vec![1, 3, SQUARE as usize, SQUARE as usize]),
            &wanted,
        )
        .unwrap()
    }

    #[test]
    fn yunet_is_planned_without_its_landmarks() {
        let plan = plan();
        // 106 nodes, of which the landmarks' 12 go (their Reshapes among them) and the other 9 Reshapes write nothing.
        assert_eq!(plan.steps.len(), 106 - 12 - 9);
        assert_eq!(plan.outputs.len(), 9);
        let size = |name: &str| plan.sizes[plan.outputs.iter().find(|(n, _)| n == name).unwrap().1];
        for stride in STRIDES {
            let cells = ((SQUARE / stride) * (SQUARE / stride)) as usize;
            assert_eq!(size(&format!("cls_{stride}")), cells);
            assert_eq!(size(&format!("obj_{stride}")), cells);
            assert_eq!(size(&format!("bbox_{stride}")), cells * 4);
        }
        // Every step writes what its first number says and reads what was written or loaded before it.
        let mut ready: HashSet<usize> = plan.weights.iter().map(|(value, _)| *value).collect();
        ready.insert(plan.input);
        for step in &plan.steps {
            assert!(
                step.reads.iter().all(|value| ready.contains(value)),
                "{:?}",
                step.kernel
            );
            assert_eq!(
                plan.sizes[step.writes], step.numbers[0] as usize,
                "{:?}",
                step.kernel
            );
            ready.insert(step.writes);
        }
    }

    #[test]
    fn padding_yunet_does_not_hold_is_refused() {
        let node = |ints: &[(&str, Vec<i64>)], texts: &[(&str, &str)]| Node {
            op: "Conv".into(),
            inputs: vec![],
            outputs: vec![],
            ints: ints
                .iter()
                .map(|(name, value)| (name.to_string(), value.clone()))
                .collect(),
            texts: texts
                .iter()
                .map(|(name, value)| (name.to_string(), value.to_string()))
                .collect(),
        };
        assert_eq!(padding(&node(&[], &[])).unwrap(), 0);
        assert_eq!(padding(&node(&[("pads", vec![1; 4])], &[])).unwrap(), 1);
        assert!(padding(&node(&[], &[("auto_pad", "SAME_UPPER")])).is_err());
        assert!(padding(&node(&[("pads", vec![])], &[])).is_err());
        assert!(padding(&node(&[("pads", vec![-1; 4])], &[])).is_err());
        assert!(padding(&node(&[("pads", vec![1, 0, 1, 0])], &[])).is_err());
    }

    #[test]
    fn a_reshape_takes_what_is_left_for_its_open_axis() {
        let target = Constant {
            shape: vec![3],
            floats: vec![],
            ints: vec![1, -1, 4],
        };
        assert_eq!(
            reshaped(&[1, 20, 20, 4], Some(&target)).unwrap(),
            vec![1, 400, 4]
        );
        let wrong = Constant {
            ints: vec![3, -1, 7],
            ..target
        };
        assert!(reshaped(&[1, 20, 20, 4], Some(&wrong)).is_err());
    }
}
