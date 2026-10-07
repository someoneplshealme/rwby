# Game design

This doc describes how *Grimmfall* plays, and which file controls each part. All numbers
live in `src/shared/Config`, mostly in `Combat.luau`. Values below are current defaults; times are
in seconds.

## Core loop

1. **Create a Huntsman** (first join):
   - Name.
   - Kingdom of origin.
   - Human or Faunus (with a trait).
   - Signature color.
   - Starting weapon.

   Your Semblance is rolled, and you start with 120 Lien and a few Dust vials.
2. **Gear up at Beacon** (safe zone). Weapon lockers (prompt key G) let you switch weapons. Launch pads on the cliff fling you into the Emerald Forest.
3. **Hunt Grimm** in the Emerald Forest and Forever Fall. Everyone who dealt a real share of a Grimm's damage gets its full XP. Its Lien is split by each player's share.
4. **Restock in Vale** (safe zone). The Dust shop *From Dust Till Dawn* sells vials.
5. **Level up** to 30. You get 3 attribute points per level and a Semblance Spin every 5 levels.
6. **Fight other Huntsmen** anywhere outside Beacon and Vale.

## Combat

Combat is server-authoritative. Each fighter (player, Grimm or shadow clone) is a `Combatant`
(`src/server/Combat/Combatant.luau`), and its state is copied to model attributes. The client plays your own actions immediately using sequence numbers, and rolls them back if the server rejects them (`CombatController`).

### Timing comes from the animations

A move's hit frames are the `Hit` markers inside its animation clip. When a clip has several Hit markers, each one gets its own `HitDef`. Chaining, shots, Dust casts and lunges are also clip markers. Because of this, gameplay and visuals can't drift apart. The content tests fail if a move's hit count doesn't match its clip.

### Offense

- **M1 strings.**
  - Chained light attacks: 4–5 per weapon.
  - The next input is accepted once the clip's `Chain` marker opens; the server allows inputs up to 0.12 early.
  - A pause of 0.8 after a hit resets the string.
  - Finishing a string adds 0.5 recovery.
  - Inputs pressed during an action are buffered for 0.35.
- **Criticals.** Each weapon form has a signature heavy attack with its own cooldown (4–6). Some have hyper armor (they can't be flinched).
- **Feints.** Right-click before an attack lands to cancel it.
  - Works on M1s and melee criticals until 0.05 before the hit.
  - Cooldown 2.2.
  - Gauntlet jabs land too fast to feint.
- **Backstabs** deal 1.2× damage.
- **Ranged forms** shoot instead of using M1s.
  - Shot types: hitscan rifle, shotgun pellets, arcing grenades.
  - Many shots push you away from your aim direction while airborne, so the recoil works as movement.

### Defense

- **Block** (hold F). Covers a 115° frontal cone.
  - Blocked hits deal *posture* damage instead of health damage.
  - Shields take only 0.55× posture damage.
- **Parry.** Hits that land in the first 0.2 after raising guard are deflected.
  - The attacker is staggered for 0.95.
  - The parrier recovers 22 posture.
  - A parry that misses locks parrying for 0.55, so spamming block doesn't work.
- **Posture.** The bar starts at 100.
  - It regenerates 16/s after 1.6 without taking posture damage.
  - When it fills, your **guard breaks** and you're stunned for 1.6.
- **Dodge** (Q). A directional dash with 0.24 of i-frames. Cooldown 1.35.
- **Air dash.** Dodging in the air gives one dash per airtime; the Glyph Semblance adds a second.
- **Slide** (C while sprinting). Cooldown 1.2.
- **Unparryable attacks** flash a red glint as they wind up. Dodge them; don't parry.

### Aura and health

- **Aura.** RWBY's soul shield.
  - It absorbs damage before health; half of any overflow reaches health.
  - When it shatters you're staggered for 0.55, and it stays down for 14 before regenerating.
  - Otherwise it regenerates 7% of its max per second after 7 without taking damage.
  - While Aura is broken, health damage is multiplied by 1.15.
- **Health** regenerates slowly, but only after 12 out of combat.

### Hit resolution

When a hitbox overlaps a target, the server checks these in order (`CombatService.resolve`):

1. **Hostility.** The target must be alive and not already knocked. Players in a safe zone can't hurt other players.
2. **I-frames.** Dodges and some Semblances make the target invulnerable, so the hit misses.
3. **Parry.** The target is blocking inside the parry window, facing the attacker, and the attack is parryable.
4. **Block.** The target is blocking and facing the attacker, and the attack is blockable. The hit deals posture damage, which can cause a guard break.
5. **Clean hit.** The game applies, in this order:
   1. Damage multipliers (attributes, backstab, buffs).
   2. Aura, then health.
   3. Hitstun, unless the target has hyper armor. Grimm resist hitstun by size.
   4. Knockback.
   5. Status effects.

Facing checks use the server's view of where each character is facing. A client's hint about its aim is accepted only within 100° of that.

### Status effects

| Status | Effect |
|---|---|
| Burn | Damage every second |
| Chill | Slows movement (by the effect's power) |
| Shock | Stuns for its duration |
| Slow | Slows movement (time glyphs) |

### Knocked, executed, dead

- **Players at 0 health are knocked**, not killed.
  - They crawl at 1.5 speed.
  - After 15 they recover with 20% health.
- **Execute** (B near a knocked enemy) takes 1.4 and kills them. Grimm maul knocked players after 2.5.
- **Death.** The dead character stays down, and you respawn at Beacon after 5.
- **Grimm** die outright at 0 health and dissolve into black smoke.

## Weapons

Every weapon has two forms. Pressing T plays a **mecha-shift**: the weapon's parts fold into the handle and out into the new shape, one after another. Data lives in two files:
- `Config/Weapons.luau`: gameplay.
- `Config/WeaponModels.luau`: the part-built model, with a position for each part in each form.

| Weapon | Form | Style |
|---|---|---|
| **Crescent Scythe** | Scythe | Wide sweeping reach. M1 3 is a spin. Critical *Reaper's Waltz* lifts the target, then slams them back down. |
| | Sniper | Long-range hitscan. Recoil launches you when airborne. Critical *Recoil Rush* is a rifle-propelled lunge. |
| **Ember Gauntlets** | Fists | The fastest string (5 hits). Critical *Dragon Breaker* dashes in and rockets the target skyward, setting it on fire. |
| | Shotgun | Seven-pellet blasts that alternate hands; they propel you in the air. Critical *Ember Rush*. |
| **Aegis Blade** | Sword & Shield | Steady sword. Blocking with the shield takes only 0.55× posture damage. M1 4 is a shield bash. Critical *Bulwark Charge*. |
| | Greatsword | Slow and crushing. The last M1 and the critical *Judgement* have hyper armor. |
| **Thunder Hammer** | Hammer | Heavy posture damage. The last M1 and the critical *Thunderclap* have hyper armor and shock. |
| | Launcher | Arcing grenades with an area blast. Critical *Barrage* fires three grenades in a fan. |

The movement speed multiplier differs by form, from 0.9 (Greatsword, Hammer) to 1.04 (Fists).

## Semblances

Your Semblance is rolled at creation, weighted by rarity. Rerolling costs a Semblance Spin and never gives the one you have. Press E to activate. Each Semblance also has a passive. Data lives in `Config/Semblances.luau` and the server logic in `Combat/Abilities.luau`.

| Semblance | Rarity | Active | Passive |
|---|---|---|---|
| Velocity | Rare | A burst of petals that dashes through enemies with i-frames | Sprint 8% faster |
| Shadow | Uncommon | Blink backward and leave a shadow clone that draws aggro | Dodge cooldown −15% |
| Retribution | Rare | Taking damage or blocking builds Fury. Ignite it to deal more damage and resist flinching. | Builds Fury |
| Polarity | Uncommon | Magnetically yank an enemy onto your weapon | −15% projectile damage taken |
| Glyph | Common | Launch skyward from a glyph that leaves a slowing time glyph | One extra air dash |
| Bulwark | Common | Harden your Aura: no flinching, −35% damage taken | +15% max posture |

## Dust

Keys 1–4 cast Dust techniques. Each cast uses one vial, and you can hold up to 9 of each type. The Affinity attribute scales Dust damage and cooldowns. Data lives in `Config/Dust.luau`.

| Dust | Technique | Effect | Price |
|---|---|---|---|
| Fire | Burning Arc | A cone of flame that sets enemies burning | 30 Lien |
| Ice | Frost Spire | A line of ice spikes that chills | 30 Lien |
| Lightning | Arc Bolt | A bolt that stuns, then jumps to a second enemy | 35 Lien |
| Gravity | Gravity Burst | A shockwave that throws enemies back. In the air, it launches you instead. | 40 Lien |

## Grimm

Grimm use the same combat pipeline as players, so their attacks can be blocked, parried and dodged. The AI (`Grimm/GrimmService.luau`):
- Chases targets within its aggro range.
- Circles while its attack cooldown runs.
- Picks an attack by weighted chance from the ones whose range reaches the target.
- Returns to its spawn area when it gets too far away (leash range).
- Mauls knocked players.

| Grimm | Health | Attacks | Notes |
|---|---|---|---|
| Beowolf | 85 | Swipe, double swipe, pounce | Packs in both forests |
| Alpha Beowolf | 210 | Stronger versions of the Beowolf attacks | Resists flinching (0.6× hitstun). Guards the temple. |
| Ursa | 300 | Maul, ground slam (unparryable, hyper armor) | 0.35× hitstun. Found in Forever Fall. |

## Progression

- **Levels 1–30.** XP needed for the next level is `60 + 38 · level^1.35`.
- **Attribute points.** 3 per level, up to 40 in each attribute:
  - Strength: +2.5% weapon damage and +1% posture damage per point.
  - Agility: +0.5% move speed and −1% dodge cooldown per point.
  - Willpower: +5 Aura and +2% Aura regeneration per point.
  - Vitality: +5 health per point.
  - Dust Affinity: +3% Dust damage and −1.5% Dust cooldowns per point.
- **Base stats.** 100 health and 100 Aura, plus 4 of each per level.
- **Kingdom bonus:**
  - Vale: +6% Aura.
  - Atlas: +8% Dust damage.
  - Mistral: +6% posture damage.
  - Vacuo: +6% health.
- **Faunus.** +4% move speed, night vision, and a visible trait (cat, wolf, rabbit, fox or bull).

Profiles are saved in the DataStore `RemnantProfiles_v1` (`Services/DataService.luau`):
- They are session-locked with `UpdateAsync`, so one account can't load in two servers at once and duplicate items.
- They autosave every 90 seconds and save again on leave and on server shutdown.

## World

`World/MapBuilder.luau` builds the map in code when the server starts. Zone bounds, spawns and landmarks are in `Config/World.luau`.

- **Beacon Academy.** A cliff plateau with:
  - The statue, the tower and the halls.
  - Weapon lockers.
  - Three launch pads aimed at the forest.

  It's a safe zone.
- **Vale.** The commercial district east of Beacon, with the Dust shop. It's a safe zone.
- **Emerald Forest** (north). Beowolf packs, with an Alpha guarding the ruined temple.
- **Forever Fall** (west). A red forest with Ursai and Beowolves.
- **Sky.** The shattered moon hangs overhead, and a full day lasts 20 minutes.
