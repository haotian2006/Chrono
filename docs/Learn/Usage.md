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
local ChronoClient = require(ReplicatedStorage.Chrono.client)
```
```lua
--Server
local ChronoServer = require(ReplicatedStorage.Chrono.server) 
```
Once required:

- **Player replication** will automatically start  
- **Snapshots** and **dynamic interpolation buffers** are handled internally  
- **CFrame updates** are batched and serialized 

---

### Registering NPCs

If you want to **replicate NPCs** with Chrono:
```lua
--Server-side
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ChronoServer = require(ReplicatedStorage.Chrono.server)

local npcId = ChronoServer.RegisterNPC(npcModel, "DEFAULT") --sets npcModel:SetAttribute("NPC_ID", npcId)

--when it moves
ChronoServer.PushNPCTransform(npcId, npcModel:GetPivot())
```

```lua
--Client-side
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ChronoClient = require(ReplicatedStorage.Chrono.client)

--after the NPC model exists locally
ChronoClient.RegisterClientNPC(npcId, npcModel, "DEFAULT")
```

#### Notes

- If **no model** is passed, Chrono will still create a server‑owned NPC entry for headless tracking  
- `PushNPCTransform` **updates the NPC’s snapshot**, which Chrono automatically interpolates on all clients  
- NPCs are treated the same as players except they will have a fixed interpolation buffer

---

### Getting the Latest CFrame

If you need the **latest replicated position** of a player or NPC for logic (hit detection, AI, etc.):
```lua
local cframe = ChronoServer.GetLatestCFrame(npcId or player)
if cframe then
    print(`Latest replicated position: {cframe.Position}`)
end
```
---
