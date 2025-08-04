# ChronoServer 

## Public API

### `RegisterNPC(model: Model?, npcType: string?) → number`

Registers a new **NPC** on the server and returns its **network ID**.

- **`model`** *(optional)* – The NPC’s physical `Model`.  
  If omitted, Chrono still tracks the NPC **headlessly**.
- **`npcType`** *(optional)* – Type key in `Config.NPC_TYPES`.  
  Defaults to `"DEFAULT"`.

---

### `PushNPCTransform(id: number, cframe: CFrame)`

Pushes a new **CFrame snapshot** for a server-owned NPC.

---

### `GetLatestCFrame(target: Player | number) → CFrame?`

Returns the **latest replicated CFrame** for a:

- **Player** – Pass the `Player` instance  
- **NPC** – Pass the network ID (`number`)

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
