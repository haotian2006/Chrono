# Custom replication v.0.0.0

###
Current initial release, expect bugs, glitches etc. Do not use in actual game.

### What is this?
Roblox's replication is slow - physics is replicated at 20hz, and there is a massive interpolation buffer designed for mobile ppl.
My custom replication solution aims to solve both these issues, while also providing lower bandwidth than roblox's solution. 

Features:
* Proximity based replication - Using my spatial hashing grid library that I have open sourced [here](https://parihsz.github.io/Schlop/Grid.html), I can efficiently find players in proximity & dynamically calculate the tick rate for their replication. What this does, is it reduces updates for player's far away / not in combat - which will reduce bandwidth.
* Dynamic interpolation buffer - My interpolation buffer is dynamically calculated and scales off the player's ping - between a maximum and minimum buffer time. My system lets low ping users have extremely responsive updates.
* Snapshot interpolation - Smoothly interpolates between snapshots to provide non jittery movement mechanics and deal with packet loss.
* Buffer based networking - Packs data into buffers to lower bandwidth even at higher tick rates.

Upcoming:
* Custom characters - Characters parented to the camera do not replicate to the client, but they are physically simulated. Using this, I can completely disable roblox's character replication, create my own custom character controller - and potentially a custom animation system
* Dynamic precision compression 