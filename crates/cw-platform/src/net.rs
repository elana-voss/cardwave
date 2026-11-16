//! This computer's addresses in the networks it reaches: the home network's
//! ([`this_computer`]) and Tailscale's ([`in_tailscale`]). Both are learned by
//! the way a UDP socket would leave by; no packet is sent.

use std::net::{IpAddr, Ipv4Addr};

/// This computer's address in the home network: the one the way out to the
/// internet leaves by.
pub fn this_computer() -> Option<IpAddr> {
    way_to(Ipv4Addr::new(192, 0, 2, 1))
}

/// This computer's Tailscale address: the one it reaches Tailscale's own
/// service address (100.100.100.100) from, where that is Tailscale's.
pub fn in_tailscale() -> Option<IpAddr> {
    tailscale_of(way_to(Ipv4Addr::new(100, 100, 100, 100)), this_computer())
}

/// The address the way to Tailscale's service leaves by, where it is
/// Tailscale's: in its range and not the way out to the internet. Without
/// Tailscale both are one way, the home network's, whose address may be in
/// the same range (a provider's shared one, as a phone's hotspot gives). With
/// Tailscale's exit node both are Tailscale's, and it is not told apart.
fn tailscale_of(to_service: Option<IpAddr>, way_out: Option<IpAddr>) -> Option<IpAddr> {
    to_service.filter(|ip| in_tailnet(*ip) && Some(*ip) != way_out)
}

/// The address this computer reaches `far` from. No packet is sent: a UDP
/// socket only picks its way when it is connected.
fn way_to(far: Ipv4Addr) -> Option<IpAddr> {
    let probe = std::net::UdpSocket::bind((Ipv4Addr::UNSPECIFIED, 0)).ok()?;
    probe.connect((far, 9)).ok()?;
    Some(probe.local_addr().ok()?.ip()).filter(|ip| !ip.is_unspecified())
}

/// Whether `ip` is in 100.64.0.0/10, the range Tailscale gives its devices.
fn in_tailnet(ip: IpAddr) -> bool {
    matches!(ip, IpAddr::V4(v4) if v4.octets()[0] == 100 && v4.octets()[1] & 0xC0 == 64)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn only_an_address_of_tailscale_is_one_from_anywhere() {
        let at = |a, b, c, d| IpAddr::V4(Ipv4Addr::new(a, b, c, d));
        assert!(in_tailnet(at(100, 64, 0, 1)));
        assert!(in_tailnet(at(100, 127, 255, 254)));
        assert!(!in_tailnet(at(100, 63, 255, 255)));
        assert!(!in_tailnet(at(100, 128, 0, 0)));
        assert!(!in_tailnet(at(192, 168, 1, 20)));
        assert!(!in_tailnet(IpAddr::V6(std::net::Ipv6Addr::LOCALHOST)));
    }

    #[test]
    fn a_shared_range_address_of_the_home_network_is_not_tailscales() {
        let at = |a, b, c, d| Some(IpAddr::V4(Ipv4Addr::new(a, b, c, d)));
        let hotspot = at(100, 72, 9, 4);
        assert_eq!(tailscale_of(hotspot, hotspot), None);
        assert_eq!(
            tailscale_of(at(100, 101, 2, 3), at(192, 168, 1, 20)),
            at(100, 101, 2, 3)
        );
        assert_eq!(tailscale_of(at(100, 101, 2, 3), None), at(100, 101, 2, 3));
        assert_eq!(tailscale_of(at(192, 168, 1, 20), at(192, 168, 1, 20)), None);
    }
}
