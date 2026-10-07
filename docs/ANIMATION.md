# Animation engine

The game animates R6 rigs with its own engine instead of Roblox animation assets. The parts are procedural locomotion, keyframe clips written as Luau tables, layering rules, two-hand IK and springs. Everything ships with the place, so there's nothing to upload or keep track of. The same code runs in three places:
- the client, to draw what you see
- the server, which reads hit frames from the clips
- the offline preview tool, which renders contact sheets

All engine code is in `src/shared/Animation`. The per-rig driver is `src/client/Animation/CharacterAnimator.luau`.

## The frame pipeline

Every frame, `AnimationController` updates each character on screen: players, Grimm and shadow clones. It does this in `RunService.PreSimulation`, after Roblox's own Animator step, so this engine has the final say on every `Motor6D.Transform`.

For each rig, the `Composer` builds one pose from these layers, bottom to top:

1. **Locomotion** (`Locomotion.luau`) is computed from the rig's real velocity:
   - The gait phase advances with distance travelled, so steps match ground speed.
   - Legs swing along the actual direction of movement, so strafing and backpedalling look right.
   - The torso leans into acceleration and banks into turns.
   - It handles idle breathing, the airborne pose and three gait styles: `Huntsman`, `Feral` (Beowolves) and `Heavy` (Ursa).
2. **Stance**: how the current weapon form is held (`StanceDef`).
   - The arms and grips replace the locomotion values.
   - Root and Neck are added on top of locomotion.
   - Stance legs only apply while standing still.
   - `armSwing` mixes some of the walk's arm swing back in.
3. **State loops**: looping clips weighted by attributes the server replicates (`Aiming`, `Blocking`, `Stunned`, `GuardBroken`, `Knocked`, `Dead`). A state clip is looked up in this order:
   1. `<stance>_<state>`, e.g. `Scythe.Rifle_Block`.
   2. `<prefix>.<state>`.
   3. `Common.<state>`.
4. **Actions**: one-shot clips (attacks, dodges, casts, reactions) with fade in and fade out. A clip only affects the joints it mentions. For example, an upper-body slash leaves the legs to the walk cycle.
5. **Two-hand IK** (`Composer.applyTwoHand`). On two-handed forms, the off hand finds where it can reach the weapon's shaft (a sphere-segment intersection). How strongly it holds on depends on `twoHand` / `twoHandRun`. A layer that animates the left arm itself overrides the IK.
6. **Additive springs**:
   - Flinches tilt away from where the hit came from.
   - Landings dip the body.
   - Shots kick back with recoil.
   - Aim pitch follows where the player is aiming.
   - Capes have their own spring.
7. **Finalize**. Legs are authored in root (ground) space and converted to torso space here, so leaning the torso never swings the legs.

Rigs far from the camera update less often: at 30 Hz beyond 140 studs and 12 Hz beyond 260.

## Pose conventions

A pose is a table `{ [joint] = CFrame }`. The joints are `Root`, `Neck`, `RightArm`, `LeftArm`, `RightLeg`, `LeftLeg`, `RightGrip` and `LeftGrip`. The grips are motors from each arm to its weapon handle.

Each joint's CFrame is written in its parent part's axes. `Joints.toTransform` converts it to `Motor6D.Transform` by conjugating with the motor's C0 rotation (`R0⁻¹ · pose · R0`). That's why you can use plain angles even though R6's joint frames are rotated.

Pose helpers take angles in degrees:

| Helper | Arguments | Meaning |
|---|---|---|
| `T` | pitch, yaw, roll, x, y, z | Torso, pivoting at the hips. +pitch leans forward, +yaw turns right, +roll tilts right. y < 0 crouches. |
| `H` | pitch, yaw, roll | Head. +pitch looks down. |
| `RA` / `LA` | pitch, out, twist | Arms. +pitch raises forward, +out raises sideways. |
| `RL` / `LL` | pitch, out, twist | Legs. +pitch kicks forward, +out spreads. |
| `RG` / `LG` | pitch, roll, spin, x, y, z | Grips. The weapon points along the handle's +Y. |

Left-side helpers mirror the right side, so the same numbers give a mirrored pose. `Joints.mirrorPose` flips a whole pose.

## Authoring weapon poses by intent

Setting raw arm and grip angles for a weapon is slow and easy to get wrong. Instead, `Author.armed` takes three directions in torso space (+X right, +Y up, −Z forward) and solves the arm and wrist for you:

```lua
armed(pose, reach, shaft, edge, slide?)
-- reach  where the right hand goes, as a direction from the shoulder
-- shaft  where the weapon's long axis points (blade, pole or barrel)
-- edge   where its "front" faces (scythe blade, cutting edge, muzzle)
-- slide  optional: move the grip along the handle
```

- `Author.swing(shaft, axis)` gives the leading edge of a blade sweeping around `axis` (`axis × shaft`):
  - `UP` for a horizontal right-to-left sweep.
  - `v(-1, 0, 0)` for an overhead chop.
- `armedLeft` does the same for the left hand (shields and off-hand weapons).
- `point(side, reach)` aims an arm without changing its grip, which suits punches.

A real keyframe from `Clips/Scythe.luau`:

```lua
{
	t = 0.24,
	ease = "Expo.Out",   -- how this key is approached
	pose = armed({
		Root = T(16, -35, 6, 0, -0.3, -0.3),
		Neck = H(6, 25, 0),
		RightLeg = RL(-26, 12),
		LeftLeg = LL(30, 8),
	}, v(-0.35, 0.05, -1), v(-0.2, 0.1, -1), swing(v(-0.2, 0.1, -1), UP)),
},
```

## Clips

Each module in `Animation/Clips` returns `{ prefix, stances, clips }`, and each clip is addressed as `"<prefix>.<name>"`. The full format is documented at the top of `Clip.luau`:

```lua
M1_1 = {
	fadeIn = 0.06, fadeOut = 0.22,   -- blend times
	-- optional: looped, speed, legSpace = "Torso" (for flips), lag = { RightGrip = 0.02 }
	keyframes = {
		{ t = 0, pose = ready() },
		{ t = 0.13, ease = "Quad.Out", pose = ... },
		...
	},
	markers = {
		{ t = 0.12, name = "TrailOn" },
		{ t = 0.23, name = "Hit" },
		{ t = 0.35, name = "Chain" },
	},
},
```

- A joint keeps its last value until a later keyframe changes it. Joints a clip never mentions are left to the layers underneath.
- `ease` is any `Style.Direction` pair, such as `Back.Out` or `Expo.In`; see `Easing.luau`.
- `lag` delays one joint's motion slightly, which gives weapons follow-through.

### Markers

Gameplay timing is read from clip markers, so a move's hit lands exactly where its animation shows it.

| Marker | Data | Used by |
|---|---|---|
| `Hit` | | Server: query the hitbox and resolve one `HitDef`. One marker per hit. |
| `Chain` | | Server and client: the next M1 is accepted from here. Must come after the last `Hit`. |
| `Shoot` | | Server: fire the move's shot. Client: apply recoil. Several markers fire several shots in a fan. |
| `Cast` | | Server: the moment a Semblance or Dust technique takes effect. Getting hit before it cancels the cast. |
| `Lunge` | speed | Moves the character forward. Players move on their own client; the server moves Grimm. |
| `TrailOn` / `TrailOff` | | Client: weapon trail. |
| `Swing` | `"Heavy"`? | Client: whoosh sound. |
| `Glint` | `"Red"`? | Client: wind-up flash. Red means the attack can't be parried. |
| `Shake` | strength | Client: camera shake (your own character only). |
| `Sound` | sound name | Client: play a sound from `Config/Sounds.luau`. |
| `Step` | | Client: dust puff at the feet. |

## Mecha-shift

A weapon model (`Config/WeaponModels.luau`) is built from simple parts. Each part, called a piece, stores a CFrame for every form, in handle space:
- +Y points along the weapon.
- −Z points away from the wielder.

Pieces can also be hidden in some forms.

When the form changes, `WeaponShift.sample` animates each piece:
- Pieces start one after another across about 45% of the shift time.
- Each piece folds toward the handle (Quad.In), then unfolds into its new position (Back.Out).
- Pieces that disappear or appear fade out or in.

The client writes the result to the pieces' motors. Meanwhile the `Common.Shift` clip twirls the wrist.

## Adding a weapon

1. **Model.** Add a `WeaponModel` in `Config/WeaponModels.luau`:
   - Give each piece a CFrame for every form.
   - Set `trails`, `muzzles` for ranged forms, and `twoHand` for forms held in both hands.
2. **Animations.** Create `Animation/Clips/<Prefix>.luau`:
   - A stance per form.
   - Its M1s and critical.
   - `Block` and `Aim` clips for each stance, where they shouldn't fall back to the shared ones.
3. **Gameplay.** Add a `WeaponDef` in `Config/Weapons.luau`:
   - Its forms reference the stance ids and clip ids.
   - Each `HitDef` matches a `Hit` marker, in order.
4. **Preview.** Check it offline:

   ```sh
   lune run tools/preview/export.luau /tmp/f.json sheet <Prefix>.M1_1 <Prefix>.Critical \
     stance=<Prefix>.<Form> weapon=<ModelId> form=<Form>
   python3 tools/preview/render.py /tmp/f.json /tmp/sheet.png
   lune run tools/preview/export.luau /tmp/s.json shift <FormA> <FormB> weapon=<ModelId> stance=<Prefix>.<FormA>
   ```
5. **Test.** Run `lune run tests/run.luau`. The content tests check that:
   - Every form has a stance, a block clip and, for ranged forms, an aim clip and `Shoot` markers.
   - Every move's clip exists and its `Hit` count matches its hits.
   - Every model piece has a position in every form.
   - Feintable moves leave time to feint.

## Tuning feel

Most of what makes the animation feel good is a handful of numbers:

- **Anticipation and release.** In a clip, slow down into the wind-up (`Quad.Out`, `Sine.InOut`), then snap through the strike (`Expo.Out`, `Back.Out`). Put the `Hit` marker on or just before the snap frame.
- **Hitstop.** `HitstopLight`, `HitstopHeavy` and `HitstopParry` in `Config/Combat.luau` slow the attacker's and victim's animations almost to a stop for a moment when a hit lands.
- **Gait.** `Locomotion.Styles` sets stride, lean, bob, counter-twist and hunch for each gait style.
- **Reactions.** The flinch and landing springs, and how strongly they're kicked, live in `CharacterAnimator.luau`.
