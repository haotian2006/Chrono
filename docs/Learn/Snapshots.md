---
title: Snapshots
outline: deep
---

# Snapshots

Snapshots sound simple to implement, because one may think it is just **keeping up a table and indexing the time**.  

::: info
In reality, it is a bit more complicated - but still **very straightforward once you understand it**.  
You want to get an **"interpolated snapshot"** at the current `renderTime` rather than just the raw snapshot for that time.
:::

---

## Why Interpolation Matters

Imagine this scenario:

- You are sending **CFrames at 30Hz**, which is roughly **33.3ms per position update**.  
- A player is at **17ms** between updates.  

You now have:

- Snapshot at **0ms**  
- Snapshot at **33ms**  

If you simply snap to either snapshot, **motion will look jittery or disconnected**.

::: tip Key Concept
Interpolating between the two snapshots allows you to **estimate the player’s state at 17ms** smoothly.
:::

---

## Snapshot Interpolation Methods

There are **two common methods** for snapshot interpolation:

1. **Linear Interpolation**  
2. **Hermite Interpolation**

---

### 1. Linear Interpolation

Linear interpolation is the **simplest and most common** method.

- You **linearly interpolate** between snapshots as you move forward through the array.  
- This is the **recommended** approach for most snapshot systems.

---

### 2. Hermite Interpolation

Hermite interpolation is the **method Roblox uses**.

- It is **calculus-based** and **approximates functions**  
- Hermite interpolation **constructs a polynomial** that matches both **values and derivatives** at specific points  
- It produces **smoother curves**, especially for **easing in and out of motion**  

::: warning Complexity
Hermite interpolation adds **unnecessary complexity** for most use cases.  
It is **not required** for basic snapshot smoothing.
:::

---

## Additional Resources

> **Further Reading:** [Snapshot Interpolation – Gaffer on Games](https://gafferongames.com/post/snapshot_interpolation/)
