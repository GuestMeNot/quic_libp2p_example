# {{crate}}

Current version: {{version}}

{{readme}}

## Goals

The main goal of this crate is to give examples of the QUIC protocol.
[QUIC](https://en.wikipedia.org/wiki/QUIC) forms the basis of [HTTP/3](https://en.wikipedia.org/wiki/HTTP/3)
and is based on [UDP](https://en.wikipedia.org/wiki/User_Datagram_Protocol)
rather than [TCP](https://en.wikipedia.org/wiki/Transmission_Control_Protocol).

[What is QUIC](https://www.auvik.com/franklyit/blog/what-is-quic-protocol/)

### Why UDP?

TCP has additional packet overhead [establish](https://en.wikipedia.org/wiki/Transmission_Control_Protocol#Connection_establishment)
and to handle [flow control, ACKs, error correction, etc.](https://en.wikipedia.org/wiki/Transmission_Control_Protocol#Data_transfer).

[Heartbeats](https://stackoverflow.com/questions/865987/do-i-need-to-heartbeat-to-keep-a-tcp-connection-open#866003)
are often added in application code to keep TCP connections alive and prevent reestablishing the connection.

UDP doesn't have this overhead, so it is faster. It can be tweaked to
[Receive a Million Packets](https://blog.cloudflare.com/how-to-receive-a-million-packets).
While it is not immediately intuitive how to integrate these results directly into the QUIC protocol,
it is thought-provoking.

We can [accelerate QUIC](https://blog.cloudflare.com/accelerating-udp-packet-transmission-for-quic)
directly.

UDP is generally considered unreliable but [QUIC retransmits packets](https://en.wikipedia.org/wiki/QUIC#Characteristics)
as needed. This retransmission and non-blocking is useful where multiple streams of data need to be sent from one source.
If there is packet loss in 1 request, QUIC does not block other requests.

## Our Example

Our goal is to transmit and receive as many bytes as possible to maximize TPS. A commonly referenced upper-bound
in TPS in a peer-to-peer network is Solana.

Unfortunately, Solana's engineers do not provide a lot of details on how to achieve their TPS performance:
[Solana TXNs per second](https://solana.blog/seriously-how-fast-can-solana-blockchain-get/)


### TXN size

For our example, a key choice is packet size. There needs to be a balance between
QUIC dividing packets, choosing efficient packet sizes for the OS kernel, packet loss and
retransmission rates. This naive example doesn't attempt to solve all these problems as this would require
the actual environment and a specific code implementation to properly run a performance test.

## Comparison with other packet sizes.

In this example the transaction size will be as large as possible to increase throughput.

Other choices of packet size have been added for reference 250b to mimic a
[Bitcoin TXN](https://bitcoinvisuals.com/chain-tx-size), ~3KB to mimic an average
[Ethereum TXN size](https://stackoverflow.com/questions/62577865/what-is-the-average-size-of-the-transaction-in-ethereum-and-hyperledger-fabric),
and 1232 to mimic a [Solana Transaction](https://github.com/solana-labs/solana/issues/16906).

## Example Code

[`./examples/quic_libp2p_example.rs`](./examples/quic_libp2p_example.rs)

This example tests the [libp2p-quic](https://docs.rs/libp2p-quic/latest/libp2p_quic/)
implementation listed above. It is based on: libp2p-quic/examples/smoke.rs

This naive implementation has a throughput of ~8000 TPS for 4Kb TXNs on commodity hardware.

There are several possibilities which may increase the TPS rate:

1. Layers above [libp2p Swarm](https://github.com/libp2p/go-libp2p-swarm) add some overhead.
2. The [QUINN Noise](https://github.com/ipfs-rust/quinn-noise) layer adds encryption cost.
3. Overhead of [lib2p2](https://libp2p.io/) itself.
4. Try using [tokio instead of async_std](https://news.ycombinator.com/item?id=24675155)
5. Try [tokio lightweight tasks](https://docs.rs/tokio/latest/tokio/#working-with-tasks)
   vs. [futures](https://docs.rs/futures/latest/futures/index.html)
6. Converting from a simple for loop to multi-threading.
7. Use [sendmmsg](https://www.man7.org/linux/man-pages/man2/sendmmsg.2.html)
   and [receivemmsg](https://www.man7.org/linux/man-pages/man2/recvmmsg.2.html).
8. Choose hardware which increases throughput.
