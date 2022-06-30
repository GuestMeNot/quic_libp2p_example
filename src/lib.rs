/// NOTE: This code is a lightly reworked version of [`smoke.rs`](crate:libp2p-quic/examples/smoke.rs).
use anyhow::Result;
use async_trait::async_trait;
use futures::future::FutureExt;
use futures::io::{AsyncRead, AsyncWrite, AsyncWriteExt};
use libp2p::core::upgrade;
use libp2p::request_response::{
    ProtocolName, ProtocolSupport, RequestResponse, RequestResponseCodec, RequestResponseConfig,
};
use libp2p::swarm::{Swarm, SwarmBuilder};
use libp2p_quic::{Keypair, QuicConfig, ToLibp2p};
use std::{io, iter};

#[cfg(all(
    not(feature = "solana"),
    not(feature = "ethereum"),
    not(feature = "bitcoin")
))]
pub const PACKET_LEN: usize = 4096;

#[cfg(feature = "solana")]
pub const PACKET_LEN: usize = SOLANA_MAX_PACKET_LEN;

/// Average size of a Ethereum encoded TXN.
#[cfg(feature = "ethereum")]
pub const PACKET_LEN: usize = ETHEREUM_AVG_PACKET_LEN;

/// Average size of a Bitcoin encoded TXN.
#[cfg(feature = "bitcoin")]
pub const PACKET_LEN: usize = BITCOIN_PACKET_LEN;

/// Maximum size of a Solana encoded TXN: https://github.com/solana-labs/solana/issues/16906
pub const SOLANA_MAX_PACKET_LEN: usize = 1232;

/// <https://stackoverflow.com/questions/62577865/what-is-the-average-size-of-the-transaction-in-ethereum-and-hyperledger-fabric>
pub const ETHEREUM_AVG_PACKET_LEN: usize = 1024 * 3;

/// <https://bitcoinvisuals.com/chain-tx-size>
pub const BITCOIN_PACKET_LEN: usize = 226;

/// Noise uses well-known symmetric key encryption.
type Crypto = libp2p_quic::NoiseCrypto;

pub async fn create_swarm() -> Result<Swarm<RequestResponse<PingCodec>>> {
    let keypair = Keypair::generate(&mut rand_core::OsRng {});
    let peer_id = keypair.to_peer_id();
    let transport = QuicConfig::<Crypto>::new(keypair)
        .listen_on("/ip4/127.0.0.1/udp/0/quic".parse()?)
        .await?
        .boxed();

    let protocols = iter::once((PingProtocol(), ProtocolSupport::Full));
    let cfg = RequestResponseConfig::default();
    let behaviour = RequestResponse::new(PingCodec(), protocols, cfg);
    tracing::info!("{}", peer_id);
    let swarm = SwarmBuilder::new(transport, behaviour, peer_id)
        .executor(Box::new(|fut| {
            async_global_executor::spawn(fut).detach();
        }))
        .build();
    Ok(swarm)
}

#[derive(Debug, Clone)]
pub struct PingProtocol();

#[derive(Clone)]
pub struct PingCodec();

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Ping(pub Vec<u8>);

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Pong(pub Vec<u8>);

impl ProtocolName for PingProtocol {
    fn protocol_name(&self) -> &[u8] {
        "/ping/1".as_bytes()
    }
}

#[async_trait]
impl RequestResponseCodec for PingCodec {
    type Protocol = PingProtocol;
    type Request = Ping;
    type Response = Pong;

    async fn read_request<T>(&mut self, _: &PingProtocol, io: &mut T) -> io::Result<Self::Request>
    where
        T: AsyncRead + Unpin + Send,
    {
        let req = upgrade::read_length_prefixed(io, PACKET_LEN)
            .map(|res| match res {
                Err(e) => Err(io::Error::new(io::ErrorKind::InvalidData, e)),
                Ok(vec) if vec.is_empty() => Err(io::ErrorKind::UnexpectedEof.into()),
                Ok(vec) => Ok(Ping(vec)),
            })
            .await?;
        Ok(req)
    }

    async fn read_response<T>(&mut self, _: &PingProtocol, io: &mut T) -> io::Result<Self::Response>
    where
        T: AsyncRead + Unpin + Send,
    {
        let res = upgrade::read_length_prefixed(io, PACKET_LEN)
            .map(|res| match res {
                Err(e) => Err(io::Error::new(io::ErrorKind::InvalidData, e)),
                Ok(vec) if vec.is_empty() => Err(io::ErrorKind::UnexpectedEof.into()),
                Ok(vec) => Ok(Pong(vec)),
            })
            .await?;
        Ok(res)
    }

    async fn write_request<T>(
        &mut self,
        _: &PingProtocol,
        io: &mut T,
        Ping(data): Ping,
    ) -> io::Result<()>
    where
        T: AsyncWrite + Unpin + Send,
    {
        upgrade::write_length_prefixed(io, data).await?;
        io.close().await?;
        Ok(())
    }

    async fn write_response<T>(
        &mut self,
        _: &PingProtocol,
        io: &mut T,
        Pong(data): Pong,
    ) -> io::Result<()>
    where
        T: AsyncWrite + Unpin + Send,
    {
        upgrade::write_length_prefixed(io, data).await?;
        io.close().await?;
        Ok(())
    }
}
