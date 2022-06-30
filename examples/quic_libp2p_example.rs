/// NOTE: this code is a lightly reworked version of [`smoke.rs`](crate:libp2p-quic/examples/smoke.rs).
///
/// The changes from the original smoke.rs code include:
///
///     1. altering the packet length,
///     2. guaranteed exits,
///     3. comparison with other coin packet sizes,
///     5. increasing the number of packets.
///
/// **NOTE**: for suggested improvements see the README file.
///
/// To run the code try (*second and subsequence runs show significant improvement*):
///
///    cargo run --release --example quic_libp2p_example
///
/// To use various packet sizes try:
///
///    cargo run --release --example quic_libp2p_example --features "solana"
///    cargo run --release --example quic_libp2p_example --features "ethereum"
///    cargo run --release --example quic_libp2p_example --features "bitcoin"
///
use anyhow::Result;
use futures::future::FutureExt;
use futures::stream::StreamExt;
use libp2p::request_response::{RequestResponseEvent, RequestResponseMessage};
use libp2p::swarm::{Swarm, SwarmEvent};
use quic_libp2p_example::{
    create_swarm, Ping, Pong, BITCOIN_PACKET_LEN, ETHEREUM_AVG_PACKET_LEN, PACKET_LEN,
    SOLANA_MAX_PACKET_LEN,
};
use rand::RngCore;
use std::time::Instant;

const PACKET_COUNT: usize = 4096 * 32;

#[async_std::main]
async fn main() -> Result<()> {
    let mut a = create_swarm().await?;
    let mut b = create_swarm().await?;

    Swarm::listen_on(&mut a, "/ip4/127.0.0.1/udp/0/quic".parse()?)?;

    let addr = match a.next().await {
        Some(SwarmEvent::NewListenAddr { address, .. }) => address,
        e => panic!("{:?}", e),
    };

    let mut data = vec![0; PACKET_LEN];

    let mut rng = rand::thread_rng();
    rng.fill_bytes(&mut data);

    b.behaviour_mut()
        .add_address(&Swarm::local_peer_id(&a), addr);

    let now = Instant::now();

    for _ in 0..PACKET_COUNT {
        b.behaviour_mut()
            .send_request(&Swarm::local_peer_id(&a), Ping(data.clone()));
    }

    let exit_count = PACKET_COUNT / 2;
    let mut count = 0;
    let mut res = 0;
    while res < PACKET_COUNT {
        futures::select! {
            event = a.next().fuse() => {
                if let Some(SwarmEvent::Behaviour(RequestResponseEvent::Message {
                    message: RequestResponseMessage::Request {
                        request: Ping(ping),
                        channel,
                        ..
                    },
                    ..
                })) = event {
                    a.behaviour_mut().send_response(channel, Pong(ping)).unwrap();
                }
            },
            event = b.next().fuse() => {
                if let Some(SwarmEvent::Behaviour(RequestResponseEvent::Message {
                    message: RequestResponseMessage::Response {
                        response: Pong(pong),
                        ..
                    },
                    ..
                })) = event  {
                    assert_eq!(data, pong);
                    res += 1;
                }
            }
        }

        count += 1;
        if count >= exit_count {
            break;
        }
    }

    let time = now.elapsed();
    let millis = time.as_millis();
    let seconds_ratio = millis as f32 / 1000_f32;
    let packets = exit_count as f32;
    let pps = packets / seconds_ratio;
    let solana_ratio = PACKET_LEN as f32 / SOLANA_MAX_PACKET_LEN as f32;
    let ethereum_ratio = PACKET_LEN as f32 / ETHEREUM_AVG_PACKET_LEN as f32;
    let bitcoin_ratio = PACKET_LEN as f32 / BITCOIN_PACKET_LEN as f32;

    println!();
    println!("{}ms to receive {} packets", millis, count);
    println!("{} packets/sec", pps);
    println!();
    println!(
        "{} Packet len vs. Solana packet len: {}",
        PACKET_LEN, SOLANA_MAX_PACKET_LEN
    );
    println!("~{} Solana equivalent packets/sec.", pps * solana_ratio);
    println!();
    println!(
        "{} Packet len vs. Ethereum avg. packet len: {}",
        PACKET_LEN, ETHEREUM_AVG_PACKET_LEN
    );
    println!("~{} Ethereum equivalent packets/sec.", pps * ethereum_ratio);
    println!();
    println!(
        "{} Packet len vs. Bitcoin packet len: {}",
        PACKET_LEN, BITCOIN_PACKET_LEN
    );
    println!("~{} Bitcoin equivalent packets/sec.", pps * bitcoin_ratio);
    println!();

    Ok(())
}
