# Custom replication v.0.2.0

###
Replication itself is mostly ready. Use with caution in actual game and please report any bugs you find. Thanks!

### What is this?
Roblox's replication is slow - physics is replicated at 20hz, and there is a massive interpolation buffer designed for mobile ppl.
My custom replication solution aims to solve both these issues, while also providing lower bandwidth than roblox's solution. 

Features:
* Proximity based replication - Using my spatial hashing grid library that I have open sourced [here](https://parihsz.github.io/Schlop/Grid.html), I can efficiently find players in proximity & dynamically calculate the tick rate for their replication. What this does, is it reduces updates for player's far away - which will reduce bandwidth.
* Dynamic interpolation buffer - My interpolation buffer is dynamically calculated using tick rate + the average latency of the preceding packets - and then checking the packet offset distance between the arrived & average latency
* Snapshot interpolation - Smoothly interpolates between snapshots to provide non jittery movement mechanics and deal with packet loss.
* Buffer based networking - Packs data into buffers to lower bandwidth even at higher tick rates. Convert CFrames into vectors and quaternions. Packs quaternions into f16s and position vectors. 
* Disabled roblox replication - Fully disable roblox character replication to lower bandwidth and use custom replication to its full capacity. (This is to opt to continue using roblox's character system. If you want to have a custom character system, look at the next bullet point.)
* Custom characters - By parenting the character to the camera on the server and creating a simulated rig on the client, my system allows for a custom character controller - server authoritative movement and custom physics / collissions. This feature is still in the works.
* Full configurability - toggle whether you want to disable roblox replication, have custom characters and more. Edit any settings, magic numbers, smoothing factors, thresholds etc. Fully documented functionalities for easy code editing.

Upcoming:
* Custom character controller & server authoritative movement
