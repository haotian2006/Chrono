---
title: Client Tick
outline: deep
---

# Client Tick

A common thing people do when implementing **custom replication** is to:

- Send **CFrames to the server**  
- Have the **server generate a timestamp** to be forwarded to the client  

::: warning
This is **bad practice** because it only accounts for **the latency of the receiver**, **not the sender**.  
This might seem like a minor issue, but it will cause **visible desync in faster-paced movement**.
:::

---

## Why Server-Generated Timestamps Cause Problems

Picture this scenario:

- **Client A** sends a CFrame at local time **t = 100ms**  
- **Client B** sends theirs at **t = 90ms**  
- Due to network latency, **both packets arrive at the server around t = 120ms**

If the **server assigns the same timestamp** to both packets and forwards them to other clients:

1. The **actual send times are ignored**  
2. The **interpolation on receiving clients becomes inaccurate**  
3. **Fast movements** will appear **desynced or jittery**

---

## The Correct Approach

Simply **forwarding timestamps from the client to the server** solves this issue.  

- The client **attaches its local timestamp** to the remote event  
- The server **uses that timestamp** instead of generating a new one  
- Receiving clients can then **calculate latency correctly** for both **sender and receiver**

---

### Example

| ❌ Bad  | ✅ Good  |
|-----------------|-----------------|
| Client fires remote            | Client fires remote with timestamp attached |
| Server generates new timestamp |  Server uses that timestamp                 |
| Client uses that timestamp and calculates latency from there | Server forwards to clients; receiving client calculates latency including both sender & receiver |