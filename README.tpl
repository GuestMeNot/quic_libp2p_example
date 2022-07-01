# {{crate}}

Current version: {{version}}

{{readme}}

## Goals

The main goal of this crate is to give an example of the QUIC protocol and highlight performance improvements.
[QUIC](https://en.wikipedia.org/wiki/QUIC) forms the basis of [HTTP/3](https://en.wikipedia.org/wiki/HTTP/3)
and is based on [UDP](https://en.wikipedia.org/wiki/User_Datagram_Protocol)
rather than [TCP](https://en.wikipedia.org/wiki/Transmission_Control_Protocol).

[What is QUIC](https://www.auvik.com/franklyit/blog/what-is-quic-protocol/)

### Why UDP?

TCP has additional packet overhead to [establish connections](https://en.wikipedia.org/wiki/Transmission_Control_Protocol#Connection_establishment)
to handle [flow control, ACKs, error correction, etc.](https://en.wikipedia.org/wiki/Transmission_Control_Protocol#Data_transfer).

[Heartbeats](https://stackoverflow.com/questions/865987/do-i-need-to-heartbeat-to-keep-a-tcp-connection-open#866003)
are often added in application code to keep TCP connections alive and prevent applications from noticing the cost of
reestablishing connections. This is done to improve application responsiveness. This is becoming more important
as mobile devices encounter a network switch.

UDP doesn't have this overhead. UDP has been tweaked in the lab to
[Receive a Million Packets](https://blog.cloudflare.com/how-to-receive-a-million-packets).
While it is not immediately intuitive how to integrate these results directly into the QUIC protocol,
it is thought-provoking.

We can [accelerate QUIC](https://blog.cloudflare.com/accelerating-udp-packet-transmission-for-quic)
directly.

UDP has historically been considered unreliable and considered only where packet loss was acceptable.
To overcome this [QUIC retransmits packets](https://en.wikipedia.org/wiki/QUIC#Characteristics)
as needed inside application code not in the kernel. Since this retransmission occurs in application layer,
QUIC is also non-blocking so one stream of data will not impact another stream of data.
This is useful when multiple streams of data need to be sent from one source.
If there is packet loss in 1 request, QUIC does not block other requests.

## This Example

The performance goal of this example is to transmit and receive as many bytes as possible.

## Comparisons

A commonly referenced upper-bound in TPS in peer-to-peer networking is Solana.
An often quoted TPS of Solana is 50,000 TXN/sec. Much is the delay in achieving this is in packet transmission.
This example shows that QUIC can achieve a high packet/sec rate on the network without any significant
modifications. The results show the same [Order of Magnitude](https://en.wikipedia.org/wiki/Order_of_magnitude)
as Solana''s commonly quoted 50,000 TXN.sec.


Unfortunately, Solana''s engineers do not provide details on how they achieved their
[TPS performance](https://solana.blog/seriously-how-fast-can-solana-blockchain-get/) in the lab.
Real world Solana TPS appears to hover around [1,500-3,000 TXN/sec](https://explorer.solana.com/).


Another often sited TXN/sec. goal is Visa at [24,000 TXN/sec](https://howmuch.net/articles/crypto-transaction-speeds-compared).
These results are also from the lab. In the real world Visa achieves
[1,700 TXN/sec](https://news.bitcoin.com/no-visa-doesnt-handle-24000-tps-and-neither-does-your-pet-blockchain/).


### TXN size

For our example, a key choice is packet size. There needs to be a balance between
the QUIC protocol dividing requests into packets, choosing efficient packet sizes for the OS kernel, packet loss and
retransmission rates. This naive example doesn't attempt to solve all these problems as this would require
a test lab environment and a specific code implementation to properly run performance tests.

## Comparison with other packet sizes.

In this example the packet size will be as large as possible to increase throughput.

Other choices of packet size have been added for reference

- 250b to mimic [Bitcoin TXN](https://bitcoinvisuals.com/chain-tx-size),
- ~3KB to mimic an average [Ethereum TXN size](https://stackoverflow.com/questions/62577865/what-is-the-average-size-of-the-transaction-in-ethereum-and-hyperledger-fabric) and,
- 1232 to mimic a [Solana Transaction/Packet](https://github.com/solana-labs/solana/issues/16906).

## Example Code

[`./examples/quic_libp2p_example.rs`](./examples/quic_libp2p_example.rs)

This example tests the [libp2p-quic](https://docs.rs/libp2p-quic/latest/libp2p_quic/)
implementation listed above. It is based on: libp2p-quic/examples/smoke.rs

This naive implementation has a throughput of ~8000 packets/sec. using 4Kb application layer data packets
on commodity hardware. This compares favorably with Visa. Also, without specialized hardware it compares to
favorably to Solana when you consider the packet size is about 4 times larger.

There are several possibilities which may increase this transmission rate:

1. Layers above [libp2p Swarm](https://github.com/libp2p/go-libp2p-swarm) add some overhead.
2. The [QUINN Noise](https://github.com/ipfs-rust/quinn-noise) layer adds encryption cost.
3. The overhead of [lib2p2](https://libp2p.io/) itself vs. QUINN directly.
4. Using [tokio instead of async_std](https://news.ycombinator.com/item?id=24675155).
5. Using [tokio lightweight tasks](https://docs.rs/tokio/latest/tokio/#working-with-tasks)
   instead of [futures](https://docs.rs/futures/latest/futures/index.html)
6. Converting from a simple `for` loop to multi-threading.
7. Using [sendmmsg](https://www.man7.org/linux/man-pages/man2/sendmmsg.2.html)
   and [receivemmsg](https://www.man7.org/linux/man-pages/man2/recvmmsg.2.html)
   to minimize context switching from application code to kernel code.
8. Choosing hardware which increases throughput.
