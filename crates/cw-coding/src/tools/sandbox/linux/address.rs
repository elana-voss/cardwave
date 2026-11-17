//! Which addresses a team's command may connect to: the internet, not this
//! computer's own addresses nor its networks' (loopback, private, link-local,
//! shared, multicast, reserved), except the system's name servers at port 53
//! (DNS over TCP, as the command's `RES_OPTIONS=use-vc` asks). An IPv6
//! address that carries an IPv4 one (`::ffff:a.b.c.d`, `64:ff9b::a.b.c.d`)
//! is judged by it. Pure: the caller reads the computer's own addresses and
//! name servers (`own`, `nameservers`).

use std::net::{IpAddr, Ipv4Addr, Ipv6Addr};

/// Whether a command may connect to `ip` at `port`.
pub(super) fn reachable(ip: IpAddr, port: u16, own: &[IpAddr], nameservers: &[IpAddr]) -> bool {
    if port == 53 && nameservers.iter().any(|server| same(*server, ip)) {
        return true;
    }
    if own.iter().any(|mine| same(*mine, ip)) {
        return false;
    }
    match ip {
        IpAddr::V4(v4) => public_v4(v4),
        IpAddr::V6(v6) => match embedded_v4(v6) {
            Some(v4) => !own.contains(&IpAddr::V4(v4)) && public_v4(v4),
            None => public_v6(v6),
        },
    }
}

/// Whether two addresses are the same, an IPv4 one and its IPv6 form alike.
fn same(a: IpAddr, b: IpAddr) -> bool {
    let plain = |ip: IpAddr| match ip {
        IpAddr::V6(v6) => v6
            .to_ipv4_mapped()
            .map(IpAddr::V4)
            .unwrap_or(IpAddr::V6(v6)),
        v4 => v4,
    };
    plain(a) == plain(b)
}

/// The IPv4 address an IPv6 one carries: `::ffff:0:0/96` (mapped) and
/// `64:ff9b::/96` (NAT64).
fn embedded_v4(v6: Ipv6Addr) -> Option<Ipv4Addr> {
    let s = v6.segments();
    let tail = Ipv4Addr::new((s[6] >> 8) as u8, s[6] as u8, (s[7] >> 8) as u8, s[7] as u8);
    match s[..6] {
        [0, 0, 0, 0, 0, 0xffff] | [0x64, 0xff9b, 0, 0, 0, 0] => Some(tail),
        _ => None,
    }
}

fn public_v4(ip: Ipv4Addr) -> bool {
    let [a, b, c, _] = ip.octets();
    !(a == 0
        || a == 127
        || a == 10
        || (a == 172 && (16..32).contains(&b))
        || (a == 192 && b == 168)
        || (a == 169 && b == 254)
        || (a == 100 && (64..128).contains(&b))
        // Benchmarking networks and the protocols' own block.
        || (a == 198 && b & 0xfe == 18)
        || (a == 192 && b == 0 && c == 0)
        || a >= 224)
}

fn public_v6(ip: Ipv6Addr) -> bool {
    let first = ip.segments()[0];
    // `::/96` holds the unspecified and loopback addresses and the old
    // IPv4-compatible ones.
    let compatible = ip.segments()[..6] == [0; 6];
    !(compatible
        || first & 0xffc0 == 0xfe80
        // The old site-local block, still routed inside some networks.
        || first & 0xffc0 == 0xfec0
        || first & 0xfe00 == 0xfc00
        || first & 0xff00 == 0xff00)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn ip(text: &str) -> IpAddr {
        text.parse().unwrap()
    }

    #[test]
    fn the_internet_is_reached_and_this_computers_networks_are_not() {
        let own = [ip("203.0.113.7"), ip("2001:db8::7")];
        let servers = [ip("10.255.255.254")];
        for public in [
            "93.184.216.34",
            "2606:2800:220:1::1",
            "::ffff:93.184.216.34",
        ] {
            assert!(reachable(ip(public), 443, &own, &servers), "{public}");
        }
        for local in [
            "127.0.0.1",
            "0.0.0.0",
            "10.1.2.3",
            "172.16.0.1",
            "172.31.255.255",
            "192.168.1.1",
            "169.254.169.254",
            "100.64.0.1",
            "198.18.0.1",
            "198.19.255.255",
            "192.0.0.8",
            "fec0::1",
            "224.0.0.1",
            "255.255.255.255",
            "::",
            "::1",
            "fe80::1",
            "fd00::1",
            "ff02::1",
            "::ffff:127.0.0.1",
            "::ffff:192.168.0.1",
            "64:ff9b::10.0.0.1",
            "::10.0.0.1",
            "203.0.113.7",
            "::ffff:203.0.113.7",
            "2001:db8::7",
        ] {
            assert!(!reachable(ip(local), 443, &own, &servers), "{local}");
        }
        assert!(reachable(ip("10.255.255.254"), 53, &own, &servers));
        assert!(!reachable(ip("10.255.255.254"), 80, &own, &servers));
        assert!(reachable(ip("::ffff:10.255.255.254"), 53, &own, &servers));
    }
}
