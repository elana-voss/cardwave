//! Coding: the coding tasks (`coding`), the tools a model may call (`tools`)
//! and the MCP server and clients (`mcp`). What it needs of the app and of the
//! chats it declares in `ports` (`AppActions`, `ChatSide`, `ports::Storage`),
//! which the server and cw-chat implement and the server wires at start; it
//! names no crate above the library.

pub mod coding;
pub mod mcp;
pub mod ports;
pub mod tools;
