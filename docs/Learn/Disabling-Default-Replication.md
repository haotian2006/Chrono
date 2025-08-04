---
title: Disabling Default Replication
outline: deep
---

# Disabling Default Replication

There are **two common methods** for **disabling default Roblox character replication**,  
each with their **own complexities**:

1. **Anchoring on server and unanchoring on client**  
2. **Parenting instances to the camera**

---

## 1. Anchoring on Server & Unanchoring on Client

This is the **most straightforward** and **simplest** way to disable character replication.

- Anchor the character **on the server**  
- Unanchor the character **on the client**

::: tip
Animations **replicate fine** using this method, and **character appearances already replicate** by default.
:::

### Collision Handling

- Each player should be **represented as a dummy**  
- **Parent the dummy to the camera** (it will **not replicate**)  
- Use **`BulkMoveTo`** to move the dummy to the **latest character `CFrame`** for local collision detection

---

## 2. Parenting to Camera

Instances **parented to the camera do not replicate**.  

- You will need to **recreate character appearances for all players** on the client  
- Best used when you are implementing:  
  1. A **custom animation system**  
  2. A **custom character controller with collisions**

::: info Best Use Case
This method is typically the **go-to** when creating **fully custom characters** with complete **client-side control**.
:::
