// SteamP2P - Steam P2P datagram transport over Kenshi's own steam_api64.dll.
//
// Kenshi ships the legacy ISteamNetworking P2P API (SendP2PPacket/ReadP2PPacket,
// confirmed in the DLL's flat exports; interface era SteamClient017/SteamUser019).
// Valve brokers connections BY STEAMID: UDP NAT hole-punch first, silent relay
// through Valve's network when punching fails. That removes IPs, port forwarding
// and router/CGNAT problems from the co-op session entirely.
//
// Design: this module does NOT replace the wire protocol - it is a datagram pipe.
// NetLink keeps running the stock ENet protocol (HELLO/WELCOME, channels,
// reliability, reconnect); the vendored ENet's socket layer is redirected here
// via enet_set_socket_hooks() (patch 0002), so every ENet datagram rides one
// unreliable Steam P2P packet on channel 0. UDP stays the default transport.
//
// Protocol 46 (trio): MULTI-PEER tunnel. Upstream carried a single tunnel peer,
// which capped Steam sessions at two players no matter what the sync layer could
// do. The tunnel now keeps a small peer table; each peer is assigned a distinct
// fake address (1.0.0.1, 1.0.0.2, ...) so ENet's ordinary address-based routing
// works unchanged over the tunnel. Sends route by destination address, receives
// stamp the sender's fake address.
//
// Peers are still configured UP FRONT by steamid64 (an N-way code exchange: the
// host lists every join, each join lists the host). Only known SteamIDs are
// accepted, so an unlisted stranger who sends to you is still dropped.
//
// Threading: init()/setPeer()/setPingPeer() are called on the main thread before
// the net thread launches; the ENet hooks and tick() run on the net thread. The
// flat ISteamNetworking calls are thread-safe (IPC into the Steam client).

#ifndef KENSHICOOP_STEAMP2P_H
#define KENSHICOOP_STEAMP2P_H

namespace coop {
namespace steamp2p {

typedef unsigned long long SteamId; // steamid64

// Resolve the flat API from the game's already-loaded steam_api64.dll and log
// "[steam] id=<steamid64> loggedOn=<0|1> iface=<version>". Idempotent; returns
// false (and logs why) when Steam isn't available.
bool init();
bool ready();
SteamId selfId();

// Configure the tunnel peer set, replacing anything already there. Proactively
// accepts the inbound session and allows Valve-relay fallback. Call before the
// net thread starts. A JOIN uses this with the host's id (one peer).
void setPeer(SteamId id);

// Protocol 46 (trio): add another tunnel peer, keeping existing ones. A HOST
// calls this once per join. Returns the assigned slot (0-based; slot n maps to
// fake address 1.0.0.<n+1>) or -1 if the table is full or the id is invalid.
// Re-adding an existing id returns its current slot instead of duplicating.
int addPeer(SteamId id);

// Number of configured tunnel peers.
unsigned int peerCount();

// Largest number of tunnel peers the fake-address scheme supports. The limit is
// the single octet the slot is encoded into, not anything about Kenshi.
const unsigned int MAX_TUNNEL_PEERS = 8;

// Accept an inbound P2P session from a specific SteamID. Used by the Steam
// invite layer's P2PSessionRequest_t callback so a session opens even if the
// request arrives before setPeer() pre-accepts it. No-op until init() succeeds.
void accept(SteamId id);

// Spike harness (KENSHICOOP_STEAM_PING=<steamid64>): ping/echo on P2P channel 1
// + periodic session-state logging, driven by tick() from the net thread. Works
// with either transport, so a UDP build can still prove Steam reachability.
void setPingPeer(SteamId id);

// Net-thread heartbeat: spike pings/echoes + session-state change logging.
// Cheap no-op when init() hasn't succeeded.
void tick();

// Install/remove the ENet socket hooks that tunnel channel 0 over Steam P2P.
// 'port' only fabricates the fake ENetAddress reported to ENet (the tunnel is
// addressless). Install BEFORE enet_host_create, remove after enet_host_destroy.
bool installEnetHooks(int port);
void removeEnetHooks();

// Close the P2P sessions (peer + ping peer).
void shutdown();

} // namespace steamp2p
} // namespace coop

#endif // KENSHICOOP_STEAMP2P_H
