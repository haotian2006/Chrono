# ChronoServer 

## Public API

### `RegisterNPC(model: Model?, npcType: string?) → number`

Registers a new **NPC** on the server and returns its **network ID**.

- **`model`** *(optional)* – The NPC’s physical `Model`.  
  If omitted, Chrono still tracks the NPC **headlessly**.
- **`npcType`** *(optional)* – Type key in `Config.NPC_TYPES`.  
  Defaults to `"DEFAULT"`.

:::danger
Use NpcCache for physical npcs, or you will need to manually push transforms for movement to be replicated
:::
---

### `PushNPCTransform(id: number, cframe: CFrame)`

Pushes a new **CFrame snapshot** for a server-owned NPC.

---

### `GetLatestCFrame(target: Player | number) → CFrame?`

Returns the **latest replicated CFrame** for a:

- **Player** – Pass the `Player` instance  
- **NPC** – Pass the network ID (`number`)

---

### `TogglePlayerReplication(player: Player, on: boolean)`

Toggles whether Chrono should interpolate the player

- **player** – Pass the `Player` instance  
- **on** – Pass a boolean of whether chrono should interpolate

---

### `Replicators`

A table mapping **network IDs → dummy Models** used when  
`Config.DISABLE_DEFAULT_REPLICATION = true`.

- Replicators are **visual proxies** cloned from `StarterPlayer.Replicator`  
  and parented to `workspace.CurrentCamera`.  
- Chrono updates them each frame with `BulkMoveTo` based on snapshots.  
- They are useful for running queries on the player's characters on the server.
- You can also access a player's replicator via workspace.Camera[player.Name].

---

## Notes

- ChronoServer drives **all server-side replication**  
- **Players are registered automatically**  
- **NPCs require manual registration** with `RegisterNPC()`  
- `PushNPCTransform` **does not move the model on the server**, only updates snapshots for clients  
- **Disabling default replication** requires:
  - `Config.DISABLE_DEFAULT_REPLICATION = true`
  - Optional **dummy clones** for client visualization

---
