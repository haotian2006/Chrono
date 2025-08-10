# NpcRegistry

## Initialization

When required, NpcRegistry automatically:

- Creates a **`NPCCacheCamera`** under `workspace` to hold **client clones**.
- Creates or waits for a **`NPC_MODEL_CACHE`** folder in `ReplicatedStorage` for **replicated NPC models**.
- Connects to:

  - **Server:** `RunService.PostSimulation` for automatic NPC transform updates.
  - **Client:** `ChildAdded` on `NPC_MODEL_CACHE` for automatic client registration.

---

## Server API

### `Npc.Register(model: Model, npcType: string?, folderName: string?, automaticUpdate: boolean?) → ()`

Registers an NPC on the server.

| Parameter          | Type       | Description                                                  |
|--------------------|-----------|--------------------------------------------------------------|
| `model`            | `Model`   | The NPC model to register.     |
| `npcType`          | `string?` | Optional NPC type, defaults to `"DEFAULT"`.                  |
| `folderName`       | `string?` | Optional folder under `NPCCacheCamera` to store the model.    |
| `automaticUpdate`  | `boolean?`| If true, the server will automatically replicate cframe changes.|

---

### `Npc.UnRegister(idOrModel: number | Model) → Model`

Unregisters an NPC from the server and cleans up its cache.

| Parameter       | Type             | Description                             |
|-----------------|-----------------|-----------------------------------------|
| `idOrModel`     | `number | Model` | NPC ID or the registered model.          |

**Returns:**  
The original NPC `Model`.

---

### `Npc.GetModel(id: number) → Model?`

Returns the **original model** for a given NPC ID, if registered.

---

## Client Behavior

On the **client**, NpcRegistry:

1. Clones each NPC into `workspace.NPCCacheCamera` for rendering.
2. Registers the clone with `ClientReplicate` for **smooth interpolation**.
3. Destroys the clone and unregisters automatically when the NPC is removed.

---

:::danger
Animations are non replicated from server to client. If you want NPC animations to be visible, you must play them on the clients. This is also idiomatic as it optimizes roblox transforms. 
:::

## Usage Example

```lua
local NpcRegistry = require(ReplicatedStorage.Packages.chrono).NpcRegistry

--Register npc on server
local npcModel = workspace:WaitForChild("Goblin")
NpcCache.Register(npcModel, "DEFAULT", nil, true)

--Change cframe
npcModel:PivotTo(CFrame.new(Vector3.new(20, 5, -20)))

--Unregister for cleanup
NpcCache.UnRegister(npcModel)
```