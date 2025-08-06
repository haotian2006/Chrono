# Overview

Here I am comparing multiple replication frameworks in Roblox, including:

- **Chrono**
- **BetterReplication** (another custom replication library)
- **Roblox Default Replication**

The benchmarks measure **both Send and Receive (Recv) bandwidth**:

- **Recv (Server → Client):**  
- **Send (Client → Server):**  
---

## Benchmarked Scenarios

The following scenarios were tested in this benchmark:

### 1. **Player Replication**
- Chrono **with Default Replication Disabled** (20 Hz, 10 players in proximity)  
- Chrono **with Default Replication** (20 Hz, 10 players in proximity)  
- BetterReplication (20 Hz, 10 players in proximity)  
:::info
BetterReplication does not support disabling default replication
:::

---
BetterReplication is for players only, so it will not be measured in the following benchmarks

### 2. **Moving Part Replication**
- Chrono (150 parts, random motion)  
- Roblox Default Replication (150 parts, random motion)  

---

### 3. **NPC Replication**
- Chrono (150 NPCs, following player)  
- Roblox Default Replication (150 NPCs, following player)  
---
