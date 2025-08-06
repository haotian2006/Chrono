# Basic Usage

Chrono runs **on top of Roblox’s default replication by default** and can optionally take full control if you disable replication. This makes it **easy to drop in** without breaking your existing character setup.


To implement:

- Drop the client and server modules into **ReplicatedStorage** (with the suggested structure)  
- Require them in your **server and client scripts**  
- Most replication (snapshots, interpolation buffers, networkables) works **automatically**

---

### Initial Setup

```lua
--Client
local ReplicatedStorage = game:GetService("ReplicatedStorage")
require(ReplicatedStorage.Packages.chrono).Start()
```
```lua
--Server
local ReplicatedStorage = game:GetService("ReplicatedStorage")
require(ReplicatedStorage.Packages.chrono).Start()
```
Once required and started:

- **Player replication** will begin
- **Snapshots** and **dynamic interpolation buffers** are handled internally  
- **CFrame updates** are batched and serialized 

---

### Registering NPCs

If you want to **replicate NPCs** with Chrono:
```lua
--Server-side
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NpcRegistry = require(ReplicatedStorage.Packages.chrono).NpcRegistry

NpcRegistry.Register(npcModel, "DEFAULT", "TestNPCs", true)

--you will simply need to update the npc's cframe and it would automatically be replicated.
--default replication is fully disabled in this case.
--animations will not replicate from server. please play them from the client.
```

#### Notes

- If **no model** is passed, Chrono will still create a server‑owned NPC entry for headless tracking
- `PushNPCTransform` **updates the NPC’s snapshot**, which Chrono automatically interpolates on all clients. Use this for headless tracking without a physical model
- NPCs are treated the same as players except they will have a fixed interpolation buffer

---

### Getting the Latest CFrame

If you need the **latest replicated position** of a player or NPC for logic (hit detection, AI, etc.):
```lua
local ChronoServer = require(ReplicatedStorage.Packages.chrono).ChronoServer
local npcId = npcModel:GetAttribute("NPC_ID") -- this is how you get the id from an npc model
local cframe = ChronoServer.GetLatestCFrame(npcId or player)
if cframe then
    print(`Latest replicated position: {cframe.Position}`)
end
```
---
