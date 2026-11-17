//! The model's graph read from its ONNX file, a protocol buffer, by hand: the nodes in order with their inputs,
//! outputs and whole-number attributes, the weights from their raw bytes, and the graph's outputs. Only what YuNet
//! uses is read; the rest of the file is skipped. Trap: a repeated whole number comes packed or one by one.

use std::collections::HashMap;

use anyhow::{Context, Result, bail, ensure};

/// One step of the graph.
pub(crate) struct Node {
    pub op: String,
    pub inputs: Vec<String>,
    pub outputs: Vec<String>,
    /// The whole-number attributes, a single number as a list of one.
    pub ints: HashMap<String, Vec<i64>>,
    /// The text attributes.
    pub texts: HashMap<String, String>,
}

/// A weight or constant: its shape and its values as floats, or as whole numbers where it holds those.
pub(crate) struct Constant {
    pub shape: Vec<usize>,
    pub floats: Vec<f32>,
    pub ints: Vec<i64>,
}

pub(crate) struct Graph {
    pub nodes: Vec<Node>,
    pub constants: HashMap<String, Constant>,
    pub outputs: Vec<String>,
}

/// ONNX's numbers for a tensor's element type.
const FLOAT: i64 = 1;
const INT64: i64 = 7;

impl Graph {
    pub(crate) fn read(model: &[u8]) -> Result<Self> {
        let graph = fields(model)?
            .into_iter()
            .find_map(|(number, value)| (number == 7).then_some(value))
            .and_then(Value::bytes)
            .context("the model has no graph")?;
        let mut read = Graph {
            nodes: vec![],
            constants: HashMap::new(),
            outputs: vec![],
        };
        for (number, value) in fields(graph)? {
            let Some(bytes) = value.bytes() else { continue };
            match number {
                1 => read.nodes.push(node(bytes)?),
                5 => {
                    let (name, constant) = constant(bytes)?;
                    read.constants.insert(name, constant);
                }
                12 => read.outputs.push(name_of(bytes)?),
                _ => {}
            }
        }
        Ok(read)
    }
}

fn node(bytes: &[u8]) -> Result<Node> {
    let mut node = Node {
        op: String::new(),
        inputs: vec![],
        outputs: vec![],
        ints: HashMap::new(),
        texts: HashMap::new(),
    };
    for (number, value) in fields(bytes)? {
        match (number, value) {
            (1, Value::Bytes(text)) => node.inputs.push(text_of(text)?),
            (2, Value::Bytes(text)) => node.outputs.push(text_of(text)?),
            (4, Value::Bytes(text)) => node.op = text_of(text)?,
            (5, Value::Bytes(attribute)) => {
                let mut name = String::new();
                let mut ints = vec![];
                let mut text = None;
                for (number, value) in fields(attribute)? {
                    match (number, value) {
                        (1, Value::Bytes(bytes)) => name = text_of(bytes)?,
                        (3 | 8, Value::Number(one)) => ints.push(one as i64),
                        (8, Value::Bytes(packed)) => ints.extend(numbers(packed)?),
                        (4, Value::Bytes(bytes)) => text = Some(text_of(bytes)?),
                        _ => {}
                    }
                }
                match text {
                    Some(text) => {
                        node.texts.insert(name, text);
                    }
                    None => {
                        node.ints.insert(name, ints);
                    }
                }
            }
            _ => {}
        }
    }
    Ok(node)
}

fn constant(bytes: &[u8]) -> Result<(String, Constant)> {
    let (mut name, mut kind, mut raw) = (String::new(), 0, None);
    let mut shape = vec![];
    for (number, value) in fields(bytes)? {
        match (number, value) {
            (1, Value::Number(one)) => shape.push(one as usize),
            (1, Value::Bytes(packed)) => {
                shape.extend(numbers(packed)?.into_iter().map(|one| one as usize))
            }
            (2, Value::Number(one)) => kind = one as i64,
            (8, Value::Bytes(text)) => name = text_of(text)?,
            (9, Value::Bytes(data)) => raw = Some(data),
            _ => {}
        }
    }
    let raw = raw.with_context(|| format!("the model's constant {name} has no raw data"))?;
    let mut constant = Constant {
        shape,
        floats: vec![],
        ints: vec![],
    };
    match kind {
        FLOAT => {
            constant.floats = raw
                .as_chunks::<4>()
                .0
                .iter()
                .map(|four| f32::from_le_bytes(*four))
                .collect()
        }
        INT64 => {
            constant.ints = raw
                .as_chunks::<8>()
                .0
                .iter()
                .map(|eight| i64::from_le_bytes(*eight))
                .collect()
        }
        other => bail!("the model's constant {name} is of the element type {other}, not read here"),
    }
    Ok((name, constant))
}

/// A value's name, field 1 of ONNX's ValueInfoProto.
fn name_of(bytes: &[u8]) -> Result<String> {
    for (number, value) in fields(bytes)? {
        if let (1, Value::Bytes(text)) = (number, value) {
            return text_of(text);
        }
    }
    bail!("the model names an output without a name")
}

fn text_of(bytes: &[u8]) -> Result<String> {
    Ok(std::str::from_utf8(bytes)
        .context("the model holds a name that is not UTF-8")?
        .to_owned())
}

/// A field's value: a whole number (varint or fixed width) or bytes.
enum Value<'a> {
    Number(u64),
    Bytes(&'a [u8]),
}

impl<'a> Value<'a> {
    fn bytes(self) -> Option<&'a [u8]> {
        match self {
            Value::Bytes(bytes) => Some(bytes),
            Value::Number(_) => None,
        }
    }
}

/// A message's fields in order, each with its number.
fn fields(mut bytes: &[u8]) -> Result<Vec<(u64, Value<'_>)>> {
    let mut found = vec![];
    while !bytes.is_empty() {
        let key = varint(&mut bytes)?;
        let value = match key & 7 {
            0 => Value::Number(varint(&mut bytes)?),
            1 => Value::Number(u64::from_le_bytes(take(&mut bytes, 8)?.try_into()?)),
            2 => {
                let length = usize::try_from(varint(&mut bytes)?)?;
                Value::Bytes(take(&mut bytes, length)?)
            }
            5 => Value::Number(u32::from_le_bytes(take(&mut bytes, 4)?.try_into()?).into()),
            other => bail!("the model's file holds a field of wire type {other}, not read here"),
        };
        found.push((key >> 3, value));
    }
    Ok(found)
}

/// Packed whole numbers.
fn numbers(mut bytes: &[u8]) -> Result<Vec<i64>> {
    let mut found = vec![];
    while !bytes.is_empty() {
        found.push(varint(&mut bytes)? as i64);
    }
    Ok(found)
}

fn varint(bytes: &mut &[u8]) -> Result<u64> {
    let mut value = 0u64;
    for shift in (0..64).step_by(7) {
        let (&byte, rest) = bytes
            .split_first()
            .context("the model's file ends inside a number")?;
        *bytes = rest;
        value |= u64::from(byte & 0x7f) << shift;
        if byte < 0x80 {
            return Ok(value);
        }
    }
    bail!("the model's file holds a number longer than 64 bits")
}

fn take<'a>(bytes: &mut &'a [u8], length: usize) -> Result<&'a [u8]> {
    ensure!(
        length <= bytes.len(),
        "the model's file ends inside a field"
    );
    let (taken, rest) = bytes.split_at(length);
    *bytes = rest;
    Ok(taken)
}
