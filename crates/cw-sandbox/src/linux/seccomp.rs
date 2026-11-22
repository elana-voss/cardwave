//! The command's seccomp filter, a classic BPF program over each system
//! call: it refuses the network (all of it for a plain command; for the
//! team's, all but TCP over IPv4 and IPv6, whose connects go to the server
//! to judge, `supervisor.rs`), reaching other processes (signals, tracing,
//! their memory and files, scheduling) and leaving the command's process
//! group, namespaces and kernel interfaces that bypass the filter
//! (`io_uring`), and changing a file's owner or extended attributes; a
//! file's mode, times and length go to the server (`metadata.rs`). Signals
//! to another process than the caller's group are
//! sent to the server too, which checks the target is the command's.
//! Trap: an argument is judged by its low 32 bits, as the kernel reads an
//! `int`; `clone3` gets `ENOSYS`, so libc falls back to `clone`, whose flags
//! the filter can read.

/// One BPF instruction (`struct sock_filter`).
#[repr(C)]
#[derive(Clone, Copy)]
pub(super) struct Instruction {
    code: u16,
    jt: u8,
    jf: u8,
    k: u32,
}

/// `struct sock_fprog`.
#[repr(C)]
pub(super) struct Program {
    pub(super) len: u16,
    pub(super) filter: *const Instruction,
}

const LOAD: u16 = 0x20; // BPF_LD | BPF_W | BPF_ABS
const JUMP_EQUAL: u16 = 0x15; // BPF_JMP | BPF_JEQ | BPF_K
const JUMP_ANY_BIT: u16 = 0x45; // BPF_JMP | BPF_JSET | BPF_K
const RETURN: u16 = 0x06; // BPF_RET | BPF_K
const AND: u16 = 0x54; // BPF_ALU | BPF_AND | BPF_K

const KILL: u32 = 0x8000_0000;
const NOTIFY: u32 = 0x7fc0_0000;
const ALLOW: u32 = 0x7fff_0000;
const fn error(code: i32) -> u32 {
    0x0005_0000 | code as u32
}

const NUMBER: u32 = 0;
const ARCH: u32 = 4;
const fn argument(index: u32) -> u32 {
    16 + 8 * index
}

#[cfg(target_arch = "x86_64")]
const AUDIT_ARCH: u32 = 0xC000_003E;
#[cfg(target_arch = "aarch64")]
const AUDIT_ARCH: u32 = 0xC000_00B7;
#[cfg(target_arch = "x86_64")]
const X32: u32 = 0x4000_0000;

const CLONE_REFUSED: u32 = 0x7E02_8000; // CLONE_NEW* and CLONE_PARENT
const MSG_FASTOPEN: u32 = 0x2000_0000;
const F_SETOWN: u32 = 8;
const F_SETSIG: u32 = 10;
const F_SETOWN_EX: u32 = 15;
const FIOSETOWN: u32 = 0x8901;
const SIOCSPGRP: u32 = 0x8902;
const IPPROTO_TCP: u32 = 6;
/// Numbers alike on every architecture, which the libc crate may not name.
const SETXATTRAT: libc::c_long = 463;
const REMOVEXATTRAT: libc::c_long = 466;

fn op(code: u16, k: u32, jt: u8, jf: u8) -> Instruction {
    Instruction { code, jt, jf, k }
}

/// A filter being written: each rule is a block that loads the call's
/// number, skips itself for another call, and ends in a return.
struct Filter(Vec<Instruction>);

impl Filter {
    fn rule(&mut self, call: libc::c_long, body: &[Instruction]) {
        self.0.push(op(LOAD, NUMBER, 0, 0));
        self.0
            .push(op(JUMP_EQUAL, call as u32, 0, body.len() as u8));
        self.0.extend_from_slice(body);
    }

    fn always(&mut self, call: libc::c_long, action: u32) {
        self.rule(call, &[op(RETURN, action, 0, 0)]);
    }

    /// `action` unless the low 32 bits of each of `zero` are 0, then allowed.
    fn unless_zero(&mut self, call: libc::c_long, zero: &[u32], action: u32) {
        let mut body = Vec::new();
        for (index, &which) in zero.iter().enumerate() {
            let left = (zero.len() - index - 1) as u8;
            body.push(op(LOAD, argument(which), 0, 0));
            // Not 0: on to the action, past the remaining checks and the allow.
            body.push(op(JUMP_EQUAL, 0, 0, 2 * left + 1));
        }
        body.push(op(RETURN, ALLOW, 0, 0));
        body.push(op(RETURN, action, 0, 0));
        self.rule(call, &body);
    }

    /// `action` where the low 32 bits of argument `which` equal one of `values`.
    fn when_equal(&mut self, call: libc::c_long, which: u32, values: &[u32], action: u32) {
        let mut body = vec![op(LOAD, argument(which), 0, 0)];
        for (index, &value) in values.iter().enumerate() {
            let left = (values.len() - index - 1) as u8;
            body.push(op(JUMP_EQUAL, value, left + 1, 0));
        }
        body.push(op(RETURN, ALLOW, 0, 0));
        body.push(op(RETURN, action, 0, 0));
        self.rule(call, &body);
    }

    /// `action` where argument `which` has any of `bits`.
    fn when_bits(&mut self, call: libc::c_long, which: u32, bits: u32, action: u32) {
        self.rule(
            call,
            &[
                op(LOAD, argument(which), 0, 0),
                op(JUMP_ANY_BIT, bits, 0, 1),
                op(RETURN, action, 0, 0),
                op(RETURN, ALLOW, 0, 0),
            ],
        );
    }
}

const REFUSED: u32 = error(libc::EPERM);
const NO_NETWORK: u32 = error(libc::EACCES);

/// The filter of a command; `internet` for a team's that may connect out.
pub(super) fn filter(internet: bool) -> Vec<Instruction> {
    let mut filter = Filter(vec![
        op(LOAD, ARCH, 0, 0),
        op(JUMP_EQUAL, AUDIT_ARCH, 1, 0),
        op(RETURN, KILL, 0, 0),
    ]);
    #[cfg(target_arch = "x86_64")]
    filter.0.extend([
        op(LOAD, NUMBER, 0, 0),
        op(JUMP_ANY_BIT, X32, 0, 1),
        op(RETURN, KILL, 0, 0),
    ]);
    processes(&mut filter);
    files(&mut filter);
    network(&mut filter, internet);
    filter.0.push(op(RETURN, ALLOW, 0, 0));
    filter.0
}

/// Other processes, the command's group, namespaces and the kernel
/// interfaces that bypass the filter.
fn processes(filter: &mut Filter) {
    for call in [
        libc::SYS_setsid,
        libc::SYS_setpgid,
        libc::SYS_ptrace,
        libc::SYS_process_vm_readv,
        libc::SYS_process_vm_writev,
        libc::SYS_pidfd_getfd,
        libc::SYS_unshare,
        libc::SYS_setns,
        libc::SYS_keyctl,
        libc::SYS_add_key,
        libc::SYS_request_key,
        libc::SYS_bpf,
        libc::SYS_perf_event_open,
        libc::SYS_userfaultfd,
        libc::SYS_io_uring_setup,
        libc::SYS_io_uring_enter,
        libc::SYS_io_uring_register,
        libc::SYS_ioprio_set,
        libc::SYS_bind,
        libc::SYS_listen,
    ] {
        let action = match call {
            libc::SYS_bind | libc::SYS_listen => NO_NETWORK,
            _ => REFUSED,
        };
        filter.always(call, action);
    }
    filter.always(libc::SYS_clone3, error(libc::ENOSYS));
    filter.always(libc::SYS_pidfd_open, error(libc::ENOSYS));
    filter.when_bits(libc::SYS_clone, 0, CLONE_REFUSED, REFUSED);
    // Signals to the caller's own group are its; others the server judges.
    for call in [
        libc::SYS_kill,
        libc::SYS_tkill,
        libc::SYS_tgkill,
        libc::SYS_rt_sigqueueinfo,
        libc::SYS_rt_tgsigqueueinfo,
    ] {
        filter.unless_zero(call, &[0], NOTIFY);
    }
    for call in [
        libc::SYS_sched_setaffinity,
        libc::SYS_sched_setscheduler,
        libc::SYS_sched_setparam,
        libc::SYS_sched_setattr,
        libc::SYS_prlimit64,
        libc::SYS_migrate_pages,
        libc::SYS_move_pages,
    ] {
        filter.unless_zero(call, &[0], REFUSED);
    }
    filter.unless_zero(libc::SYS_setpriority, &[0, 1], REFUSED);
}

/// A file's details, which Landlock does not hold: its mode, times and
/// length the server judges (`metadata.rs`); its owner and extended
/// attributes are refused.
fn files(filter: &mut Filter) {
    for call in super::metadata::handled() {
        filter.always(call, NOTIFY);
    }
    let mut owners = vec![libc::SYS_fchown, libc::SYS_fchownat];
    #[cfg(target_arch = "x86_64")]
    owners.extend([libc::SYS_chown, libc::SYS_lchown]);
    for call in owners {
        filter.always(call, REFUSED);
    }
    for call in [
        libc::SYS_setxattr,
        libc::SYS_lsetxattr,
        libc::SYS_fsetxattr,
        libc::SYS_removexattr,
        libc::SYS_lremovexattr,
        libc::SYS_fremovexattr,
        SETXATTRAT,
        REMOVEXATTRAT,
    ] {
        filter.always(call, error(libc::EOPNOTSUPP));
    }
}

/// Sockets: signals by I/O to a process of the command's choosing, and the
/// network, all of it refused unless `internet`.
fn network(filter: &mut Filter, internet: bool) {
    filter.when_equal(
        libc::SYS_fcntl,
        1,
        &[F_SETOWN, F_SETSIG, F_SETOWN_EX],
        REFUSED,
    );
    filter.when_equal(libc::SYS_ioctl, 1, &[FIOSETOWN, SIOCSPGRP], REFUSED);
    match internet {
        true => {
            // TCP over IPv4 or IPv6 alone: no UDP, no other family.
            filter.rule(
                libc::SYS_socket,
                &[
                    op(LOAD, argument(0), 0, 0),
                    op(JUMP_EQUAL, libc::AF_INET as u32, 1, 0),
                    op(JUMP_EQUAL, libc::AF_INET6 as u32, 0, 7),
                    op(LOAD, argument(1), 0, 0),
                    op(AND, 0xf, 0, 0),
                    op(JUMP_EQUAL, libc::SOCK_STREAM as u32, 0, 4),
                    op(LOAD, argument(2), 0, 0),
                    op(JUMP_EQUAL, 0, 1, 0),
                    op(JUMP_EQUAL, IPPROTO_TCP, 0, 1),
                    op(RETURN, ALLOW, 0, 0),
                    op(RETURN, NO_NETWORK, 0, 0),
                ],
            );
            filter.always(libc::SYS_connect, NOTIFY);
            filter.when_bits(libc::SYS_sendto, 3, MSG_FASTOPEN, NO_NETWORK);
            filter.when_bits(libc::SYS_sendmsg, 2, MSG_FASTOPEN, NO_NETWORK);
            filter.when_bits(libc::SYS_sendmmsg, 3, MSG_FASTOPEN, NO_NETWORK);
        }
        false => {
            filter.always(libc::SYS_socket, NO_NETWORK);
            filter.always(libc::SYS_connect, NO_NETWORK);
        }
    }
}

/// Lays `program` on this process, returning the descriptor its notices
/// come by. Only for the command's process between fork and exec: it
/// allocates nothing. `NO_NEW_PRIVS` must be set.
pub(super) fn install(program: &Program) -> std::io::Result<libc::c_int> {
    const SET_MODE_FILTER: u32 = 1;
    const NEW_LISTENER: u32 = 8;
    // SAFETY: the program and its instructions live through the call.
    let fd = unsafe {
        libc::syscall(
            libc::SYS_seccomp,
            SET_MODE_FILTER,
            NEW_LISTENER,
            program as *const Program,
        )
    };
    match fd < 0 {
        true => Err(std::io::Error::last_os_error()),
        false => Ok(fd as libc::c_int),
    }
}
