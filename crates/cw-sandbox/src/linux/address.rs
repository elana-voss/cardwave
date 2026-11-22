//! Which addresses a team's command may connect to: what the shared check
//! `cw_platform::http::public` calls the open internet, not this computer's
//! own addresses, except the system's name servers at port 53 (DNS over TCP,
//! as the command's `RES_OPTIONS=use-vc` asks). An IPv6 address that carries
//! an IPv4 one (`::ffff:a.b.c.d`, `64:ff9b::a.b.c.d`) is matched with the own
//! addresses and name servers by it. Pure: the caller reads the computer's own
//! addresses and name servers (`own`, `nameservers`).

use std::net::{IpAddr, Ipv4Addr};

use cw_platform::http::public;

/// Whether a command may connect to `ip` at `port`.
pub(super) fn reachable(ip: IpAddr, port: u16, own: &[IpAddr], nameservers: &[IpAddr]) -> bool {
    if port == 53 && nameservers.iter().any(|server| same(*server, ip)) {
        return true;
    }
    !own.iter().any(|mine| same(*mine, ip)) && public(ip)
}

/// Whether two addresses are the same, an IPv4 one and its IPv6 forms alike.
fn same(a: IpAddr, b: IpAddr) -> bool {
    plain(a) == plain(b)
}

/// `ip` as the IPv4 address it carries, where it carries one: `::ffff:0:0/96`
/// (mapped) and `64:ff9b::/96` (NAT64).
fn plain(ip: IpAddr) -> IpAddr {
    let IpAddr::V6(v6) = ip else { return ip };
    let s = v6.segments();
    match s[..6] {
        [0, 0, 0, 0, 0, 0xffff] | [0x64, 0xff9b, 0, 0, 0, 0] => IpAddr::V4(Ipv4Addr::new(
            (s[6] >> 8) as u8,
            s[6] as u8,
            (s[7] >> 8) as u8,
            s[7] as u8,
        )),
        _ => ip,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn ip(text: &str) -> IpAddr {
        text.parse().unwrap()
    }

    #[test]
    fn the_internet_is_reached_and_this_computers_networks_are_not() {
        // Public addresses, so only the own-address check refuses them.
        let own = [ip("93.184.216.7"), ip("2606:2800:220:1::7")];
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
            "2002:c0a8:0101::1",
            "2001:0:c0a8:101::1",
            "::10.0.0.1",
            "93.184.216.7",
            "::ffff:93.184.216.7",
            "64:ff9b::93.184.216.7",
            "2606:2800:220:1::7",
        ] {
            assert!(!reachable(ip(local), 443, &own, &servers), "{local}");
        }
        assert!(reachable(ip("10.255.255.254"), 53, &own, &servers));
        assert!(!reachable(ip("10.255.255.254"), 80, &own, &servers));
        assert!(reachable(ip("::ffff:10.255.255.254"), 53, &own, &servers));
    }
}
