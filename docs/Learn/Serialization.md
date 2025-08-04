---
title: Serialization
outline: deep
---

# Serialization

To **optimize for bandwidth**, it is highly recommended to **use buffers to serialize packets**.  

Thankfully, there are networking libraries such as **Bytenet** and **Blink** to handle **SerDes (Serialization/Deserialization)** easily. In **Chrono**, we are using our own SerDes to squeeze out even more performance.

---

## CFrame Serialization

CFrames consist of **both positional and rotational components**.  

### Position

- Use ``f32`` for position  
- While `f16` is smaller, it suffers from **precision limits**  
- Many **open-source replication systems** uses float16 for position, but those are typically just for **showcase purposes**

::: tip
Stick with **float32** for positions if you care about accuracy in a production environment.
:::

---

### Rotation

- Best approach: **convert rotations to quaternions** and **serialize as ``f16``**  
- Converting between **CFrame → Quaternion (AxisAngles)** and **Quaternion → CFrame** is straightforward  
- Alternatively, you can **just send Y-axis rotation** for many **battleground games**, as it is **precise enough**

---

## Timestamp Handling

```lua
GetServerTimeNow()
```

- Provides a **synchronized clock between client and server**  
- **Avoids the need** to manually compensate for **clock drift** due to latency variations

::: danger RenderCache
From my tests, GetServerTimeNow has issues making interpolation jittery. Chrono uses os.clock and predicting the estimated server time and renderTimeError; this system also provides much smoother control over visuals.
:::
---

## Rendering Timestamps

When rendering timestamps:

1. Compute **remote latency** easily by comparing a synced clock time on the server and client  
2. Subtract your **interpolation buffer** to compute the **correct render time**

---

## Performance & Bandwidth Tips

::: warning Float Cost
`GetServerTimeNow()` returns a **`f64`**, which is **more costly** than `os.clock()` (**`f32`**)
:::

### Bandwidth Optimization

- **Encode timestamps** to reduce bandwidth  

```lua
-- Example: compress to f16 range
timestamp = GetServerTimeNow() % 255
```

::: danger Time Wrapping
If you implement time wrapping like this:
Always account for circularity when comparing timestamps. Failing to do so will result in incorrect snapshot ordering
:::
