extends Node

## ENet connection lifecycle service.
## This is the networking foundation; gameplay-state authority and remote player
## replication are not considered complete until wired to the mission controller.

signal status_changed(message: String)
signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)
signal session_started(mode: String)
signal session_ended

const DEFAULT_PORT: int = 24567
const DEFAULT_MAX_PLAYERS: int = 5
const MIN_PLAYERS: int = 2
const MAX_PLAYERS: int = 8

var session_mode: String = "solo"
var server_address: String = "127.0.0.1"
var server_port: int = DEFAULT_PORT
var max_players: int = DEFAULT_MAX_PLAYERS
var last_error: int = OK
var _peer: MultiplayerPeer
var _signals_connected: bool = false

func is_online_session() -> bool:
    return session_mode in ["host", "client"] and multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer)

func is_host() -> bool:
    return session_mode == "host" and multiplayer.is_server()

func player_count() -> int:
    if not is_online_session():
        return 1
    return multiplayer.get_peers().size() + (1 if multiplayer.is_server() else 1)

func host_session(port: int = DEFAULT_PORT, requested_max_players: int = DEFAULT_MAX_PLAYERS) -> int:
    leave_session(false)
    server_port = clampi(port, 1024, 65535)
    max_players = clampi(requested_max_players, MIN_PLAYERS, MAX_PLAYERS)
    var new_peer := ENetMultiplayerPeer.new()
    var error_code := new_peer.create_server(server_port, max_players - 1)
    last_error = error_code
    if error_code != OK:
        status_changed.emit("Gagal membuat host. Kode error: %d" % error_code)
        return error_code
    _peer = new_peer
    multiplayer.multiplayer_peer = new_peer
    session_mode = "host"
    _connect_peer_signals()
    status_changed.emit("Host aktif di port %d. Batas pemain: %d." % [server_port, max_players])
    session_started.emit(session_mode)
    return OK

func join_session(address: String, port: int = DEFAULT_PORT) -> int:
    leave_session(false)
    server_address = address.strip_edges()
    server_port = clampi(port, 1024, 65535)
    if server_address.is_empty():
        last_error = ERR_INVALID_PARAMETER
        status_changed.emit("Alamat server tidak boleh kosong.")
        return last_error
    var new_peer := ENetMultiplayerPeer.new()
    var error_code := new_peer.create_client(server_address, server_port)
    last_error = error_code
    if error_code != OK:
        status_changed.emit("Gagal memulai koneksi. Kode error: %d" % error_code)
        return error_code
    _peer = new_peer
    multiplayer.multiplayer_peer = new_peer
    session_mode = "client"
    _connect_peer_signals()
    status_changed.emit("Mencoba terhubung ke %s:%d..." % [server_address, server_port])
    session_started.emit(session_mode)
    return OK

func leave_session(notify: bool = true) -> void:
    # Replacing the peer with OfflineMultiplayerPeer is the documented Godot lifecycle
    # operation and safely returns the SceneTree multiplayer API to offline mode.
    multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
    _peer = null
    session_mode = "solo"
    if notify:
        status_changed.emit("Sesi jaringan ditutup. Mode solo aktif.")
        session_ended.emit()

func _connect_peer_signals() -> void:
    if _signals_connected:
        return
    multiplayer.peer_connected.connect(_on_peer_connected)
    multiplayer.peer_disconnected.connect(_on_peer_disconnected)
    multiplayer.connected_to_server.connect(_on_connected_to_server)
    multiplayer.connection_failed.connect(_on_connection_failed)
    multiplayer.server_disconnected.connect(_on_server_disconnected)
    _signals_connected = true

func _on_peer_connected(peer_id: int) -> void:
    status_changed.emit("Pemain %d terhubung. Jangan mulai sesi produksi sebelum sinkronisasi gameplay dipasang." % peer_id)
    peer_joined.emit(peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
    status_changed.emit("Pemain %d terputus." % peer_id)
    peer_left.emit(peer_id)

func _on_connected_to_server() -> void:
    status_changed.emit("Terhubung ke host sebagai peer %d." % multiplayer.get_unique_id())

func _on_connection_failed() -> void:
    status_changed.emit("Koneksi gagal. Periksa IP, port, firewall, dan apakah host aktif.")
    leave_session(false)

func _on_server_disconnected() -> void:
    status_changed.emit("Koneksi ke host terputus.")
    leave_session(false)
