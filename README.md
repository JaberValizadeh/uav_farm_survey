# uav_farm_survey

A **hector quadrotor** flying line by line over an apple orchard, finding the
ripe fruit and reporting where it is, on ROS Noetic.

The drone knows nothing about the orchard. It gets a rectangle, a camera and its
own pose, flies a lawnmower pattern over the rows, and turns red pixels into a
list of map coordinates. Nothing in the flying or the detecting reads the ground
truth — that file exists only to mark the answers afterwards.

```
boustrophedon coverage  ->  red blobs in frame  ->  world positions  ->  merged map
```

```bash
source ~/uav_ws/src/uav_pick_place/setup_uav.bash
roslaunch uav_farm_survey farm_survey.launch
```

`gui:=false` to run it headless, `rviz:=true` for the map building up as it
flies, `camera_view:=false` to suppress the camera window.

To run RViz separately and view the fruit map and coverage pattern:

```bash
roslaunch uav_farm_survey farm_rviz.launch
```

A run takes about four minutes of flight and prints a scored report at the end.

### Or one stage at a time

`farm_survey.launch` is nothing but these four run together, and takes the same
arguments. Run them separately when working on one piece — the world is the
slowest part to load and the part you least often want to restart:

| | terminal | |
|---|---|---|
| 1 | `roslaunch uav_farm_survey orchard_world.launch` | Gazebo + the orchard. Leave it up. |
| 2 | `roslaunch uav_farm_survey survey_robot.launch` | airframe + the three nodes |
| 3 | `roslaunch uav_farm_survey farm_rviz.launch` | the map and the coverage pattern |
| 4 | `roslaunch uav_farm_survey farm_rqt.launch` | what the camera sees |

Step 1 brings up the roscore, so it has to be first. Steps 3 and 4 only listen —
start, kill and restart them at any point in a run without disturbing anything.

Step 2 is the one to iterate on, and a parameter sweep costs one relaunch
instead of reloading 96 trees:

```bash
rosrun uav_farm_survey reset_robot
roslaunch uav_farm_survey survey_robot.launch sat_min:=180
```

**The reset is not optional.** Killing `survey_robot.launch` stops its nodes but
leaves the spawned model in gzserver — the model belongs to Gazebo, not to the
launch that asked for it. Relaunching without resetting still flies, because the
old model is there with its controllers loaded, but it logs
`SpawnModel: Failure - entity already exists` and the aircraft starts from
wherever it was left instead of from the corner of the field.

---

## What it does, and how well

The orchard is **96 apple trees** in 6 rows of 16, carrying **478 apples** — 231
ripe and 247 unripe, on a fenced farm with a shed, a headland track, bulk bins,
hives and a windbreak. The drone sweeps the 35 x 15 m block in **6 legs at
5.5 m**, about four minutes in the air, and the last thing it prints is this:

```
   sightings 12949, merged into 293 blobs, 239 believed (>= 15 frames)
   position spread: median 0.162 m, worst 0.279 m

   scored against orchard_truth.yaml
   ripe fruit on the farm : 231
   found                  : 222   (recall 96.1%)
   missed                 : 9
   false positives        : 17   (precision 92.9%)
     of which on unripe fruit: 0
   position error         : mean 0.054 m, median 0.060 m, worst 0.146 m
```

Every fruit it reports is written to `~/ripe_fruit_report.csv`.

### What the size change did to the score

The farm was 4 rows of 10 before, and everything below the resize was measured
on that block. The comparison is not clean the way the texturing one was — the
world is a different world, not the same one lit differently, so the truth file
changed and this is two different populations rather than one seen twice. What
it does say is that the numbers held up at 2.5x the area:

| | trees | ripe | recall | precision | position error |
|---|---|---|---|---|---|
| 4 x 10, 22 x 9 m, 4 legs | 40 | 94 | 94.7% | 94.7% | 0.059 m |
| **6 x 16, 35 x 15 m, 6 legs** | **96** | **231** | **96.1%** | **92.9%** | **0.054 m** |

Recall and position error came out slightly better, precision slightly worse.
The precision figure is the one to read carefully: 17 false positives against 5
is not the detector degrading over a longer flight, it is **2.5x the fruit
generating 2.5x the chances to double-count one** — the rate per ripe apple
went from 5.3% to 7.4%, and every one of the 17 is a duplicate rather than a
piece of scenery (below). A longer flight does not accumulate error, because
nothing in the pipeline integrates: each sighting is projected from the pose it
was taken at, and the map is a set of running means.

**Zero false positives on unripe fruit still holds at this size**, which is the
number that says the colour test is discriminating ripeness rather than finding
round things — and there are now 247 green apples for it to fall for.

### Making the world realistic, measured rather than assumed

Texturing the farm and lighting it properly changes what a colour detector
sees, so it is not a change that can be made on the strength of a screenshot.
The tree and fruit geometry was left untouched and the furniture given its own
random stream, so `config/orchard_truth.yaml` came out **byte-identical** and
the comparison was exact — same 94 apples, in the same places, seen against a
different world. (These runs are all on the 4 x 10 block, which is what the
farm was at the time. They are kept as measured rather than re-run at the new
size: the point they make is about lighting, and re-running them on a different
world would not make it better.)

| | found | recall | false pos | precision | position error |
|---|---|---|---|---|---|
| flat colour, one sun | 88 | 93.6% | 6 | 93.6% | 0.057 m |
| textured farm, run 1 | 89 | 94.7% | 6 | 93.7% | 0.060 m |
| textured farm, run 2 | 89 | 94.7% | 5 | 94.7% | 0.060 m |
| textured farm, run 3 | 90 | 95.7% | 7 | 92.8% | 0.062 m |
| final, foliage reworked | 89 | **94.7%** | 5 | **94.7%** | 0.059 m |

**Recall went up in every run**, and that was the predicted direction: the fill
light is there to keep shadowed fruit above the detector's value floor, and
apples the old lighting lost in the shade of a canopy now clear it. False
positives at 5-7 bracket the old 6, so the difference there is run-to-run
scatter and not a regression — three runs were needed to say that, because one
run showing 8 looks like damage until you have the spread to compare it to.
Position error is 3 mm worse, which is the same number.

Worth knowing about the false positives, whichever world they come from and
whatever size it is: they sit **0.16 to 0.35 m from a real ripe apple**, 15 of
17 within 0.33 m, against a 0.15 m match radius. They are not the scenery being
mistaken for fruit — they are one apple that landed in the map twice, just past
the radius that would have merged it. The farm still produces no detection of
its own at the larger size: the nearest false positive to any bin, post, hive,
shed or tank is **1.43 m** away, and the nearest one to an *unripe* apple is
0.32 m.

Position error is measured against the generated truth by greedy nearest
matching within `match_radius` (0.15 m — deliberately tighter than half the
0.31 m minimum spacing between any two *ripe* apples in this orchard, so a
report cannot be credited to a fruit it is not actually on). That 0.31 m is not
a number the bigger farm was allowed to break: 231 ripe apples in 96 trees have
far more chances to land next to each other than 94 did, and the closest pair
still comes out at 0.3105 m, which is what keeps the radius honest.

**Zero false positives land on unripe fruit.** That is the number worth watching,
because it is the one that says the detector is discriminating ripeness rather
than merely finding objects — the unripe fruit is green, and so is every leaf
around it.

---

## The three nodes

| node | job | reads |
|---|---|---|
| `survey_pilot` | flies the coverage pattern | its own pose |
| `fruit_detector` | red blobs -> world positions | image, `camera_info`, pose |
| `orchard_map` | sightings -> a map of fruit | sightings (+ truth, to score) |

They are separate because they fail separately. A pilot that flies a bad pattern
and a detector that mis-projects look identical in the final map unless you can
watch `/farm/progress` and `/farm/sightings` on their own.

### survey_pilot — line by line

A boustrophedon (lawnmower) sweep: fly a leg, turn, fly the next one back.
`leg_spacing` defaults to **3.0 m**, which is the *row* spacing, not the widest
spacing the camera could support:

```
  field    : x -17.6..17.6   y -7.5..7.5   (528 m2)
  pattern  : 6 legs, 3.00 m apart, at 5.5 m
  camera   : 9.2 m swath, so legs overlap by 67%
```

That 67% overlap is not waste. Flying directly along each row puts the fruit
near the middle of the frame, and everything in the projection below gets worse
towards the edges — lens distortion, the lever arm on any pose error, and the
chance of a half-occluded blob. Coverage is cheap here; accuracy is not.

Commands go out on `cmd_vel`, which for this controller is the **yaw-stabilized
body frame**, so the pilot converts its world-frame waypoints itself.

### fruit_detector — pixels to a place on the farm

**Ripe means red**, in HSV: hue near 0 (which wraps, so it takes two bands),
saturation above `sat_min`, value above `val_min`. Then contours, filtered by
area, with a close-then-open so an apple with a specular highlight through the
middle stays one fruit rather than becoming two.

Saturation is the guard that matters. An early run scored 41.8% precision
because the *soil and bark* sat at hue 14.9 and 13.9 — four units off the
threshold — and passed the other tests. Desaturating both in the world
generator and raising `sat_min` to 160 (apples sit at 241) cut spurious
detections from 31 to 11.

The projection assumes the camera looks straight down, mounted `rpy (0, pi/2, 0)`:

```
image right (+u)  ->  body -y
image down  (+v)  ->  body -x
```

so a blob at `(u, v)` seen from range `d` is at `body_x = -(v-cy)/fy * d`,
`body_y = -(u-cx)/fx * d`, rotated by yaw and added to the aircraft position.
`fx, fy, cx, cy` come from `camera_info` rather than being recomputed from the
FOV, so changing the lens in the xacro cannot silently leave this projecting
with the old numbers.

#### On ranging, and a change that was measured and reverted

`d` is the camera's height above the apple, and there are two ways to get it.

The flat-plane assumption uses altitude less `fruit_plane_z`. It is wrong by up
to half a metre here, because apples hang anywhere from 1.45 m to 2.46 m.

The alternative is to measure it — an apple is a known size, so
`d = fx * 0.11 / apparent_diameter_px`. That is textbook monocular ranging and
it removes the flat-plane error completely for any clean blob.

It was tried, and it made everything worse. Same orchard, one variable:

| | size ranging on | **off (default)** |
|---|---|---|
| recall | 86.2% | **94.7%** |
| precision | 62.8% | **92.7%** |
| false positives | 48 | **7** |
| position error | 0.077 m | **0.056 m** |

An apple is only about **12 px across** at 5.5 m, so blob area is dominated by
noise, and a noisy range throws each sighting to a different place — which
splits one fruit into several map entries. It lost on position error too, which
is the metric it was supposed to win.

`range_from_size` is still there as a launch arg, defaulting to `false`. At a
lower altitude, or with a longer lens, it should start to pay.

### orchard_map — sightings are not fruit

A fruit is seen in twenty or thirty consecutive frames from slightly different
poses. The map merges sightings within `merge_radius` (0.28 m) into running
means, then re-consolidates — merging can leave two clusters that are now closer
to each other than the threshold, so the pass repeats until nothing moves.

A cluster is only believed at `min_sightings` (**15 frames**). Across the 239
fruit reported in the last run the mean was **53.2 sightings**; the worst *real*
apple earned **18**, so the floor still clears it, though the margin is three
frames now rather than the nine it had on the smaller block.

Raising the floor is not the way to spend that, and the run says why. Sorting
the 17 false positives by sightings puts their median at **33** — they are not
red pixels that flickered once, they are duplicate clusters of real apples seen
about as often as the apples themselves. A floor of 30 would drop 4 real fruit
to remove 4 false ones:

```
  floor 15  ->  222/222 real,  17/17 false     (default)
  floor 20  ->  221/222 real,  14/17 false
  floor 30  ->  218/222 real,  13/17 false
```

The floor is doing the job it was set for — rejecting speckle — and `merge_radius`
is the parameter that would actually address what is left.

`spread` is published per fruit: how far apart the sightings that formed it
were. A tight cluster seen many times is a confident detection; a wide one means
the projection is disagreeing with itself and the position is soft.

---

## Seeing what the drone sees

`camera_view:=true` (the default) opens `rqt_image_view` on
`/uav_0/detections/image` — the camera with the detector's reasoning drawn on
it:

- everything the **colour test accepted** is tinted, including blobs later
  rejected on area or roundness, which is the difference between "the threshold
  is wrong" and "the filters are too tight"
- accepted apples are **ringed** and labelled with the world position and range
  the detector decided on — amber when the range came from the plane, green when
  it was measured from the blob
- a HUD with the count in frame, the altitude over the plane, and the running
  totals
- a crosshair on the one pixel where the projection has no lever arm at all

> **Note for anyone publishing images in this workspace:** this node builds its
> outgoing `sensor_msgs/Image` by hand rather than with
> `cv_bridge.cv2_to_imgmsg`, which raises `KeyError: 16` on this install for
> every `bgr8` image (a cv_bridge/OpenCV version mismatch in `core.py:266`).
> Inbound `imgmsg_to_cv2` is fine. See the comment at the publish site.

---

## The orchard, and the farm around it

`worlds/orchard.world` and `config/orchard_truth.yaml` are **generated
together**, by one pass of one loop in `scripts/make_orchard`. They cannot drift
apart, which matters because the whole scenario is "did the robot find things"
and there is no way to answer that without a trustworthy list of what was there.

```bash
rosrun uav_farm_survey make_orchard_textures     # the tiling textures
rosrun uav_farm_survey make_orchard              # defaults: seed 5, 6 rows, 16 trees
rosrun uav_farm_survey make_orchard --seed 7 --rows 8 --trees 20
```

### Resizing the farm

`--rows` and `--trees` move the whole place, not just the trees. Nothing in the
world is written at an absolute coordinate: the fence, the headland track, the
packing shed, the tank, the hives, the irrigation header, the bulk bins and the
windbreak are all placed from the block's own half-extents, so a bigger orchard
grows a bigger farm around itself rather than sprouting extra rows through the
middle of a fixed fence.

**The flight plan is the part that does not follow automatically**, because it
lives in the launch files rather than in the world. That is a seam worth
knowing about, because getting it wrong is quiet: a field left at the old size
flies a perfectly correct pattern over *part* of the new orchard, reaches
`covered 100.0%` of the rectangle it was given, and scores every row it never
visited as a miss — which reads as a broken detector rather than a stale launch
file.

So the generator prints the arguments that match what it just wrote:

```
  launch arguments for this farm (defaults in survey_robot.launch):
    field_x_min:=-17.6 field_x_max:=17.6 field_y_min:=-7.5 field_y_max:=7.5
    spawn_x:=-18.1 spawn_y:=-9.2  leg_spacing:=3.0  fruit_plane_z:=1.99
    6 legs of 35.2 m at 1.2 m/s ~ 189 s in the air
```

Those are the current defaults. After regenerating at a different size, either
pass them on the command line or edit the defaults in `survey_robot.launch`
(and `farm_survey.launch`, which repeats them so the one-command form takes the
same arguments).

One leg per row means **flight time scales with `--rows`, not with area** —
`--trees` makes each leg longer, which is cheap; `--rows` adds a whole leg plus
a turn. `node_delay` is the other thing to watch: it has to cover Gazebo
loading the world, and 96 trees of stacked primitives is a slower load than 40.

There is no model database on this machine and no tree meshes in the workspace,
so a tree is primitives. Four things stop it reading as a lollipop on a stick: a
**tapered, slightly leaning trunk** of three stacked cylinders; five or six
**real branches** at irregular bearings; a **layered canopy** of twelve to
eighteen overlapping spheres rather than one big one (the silhouette is the
whole tell); and **per-tree variation** in height, lean, density and green,
because a row of identical trees looks like wallpaper. Apples get a specular
highlight and a short brown stem.

### Texture, and the reason it is not just decoration

Every surface used to be a flat `<diffuse>` colour: plastic-green foliage
spheres, a plastic-brown trunk, and one unbroken green box for the grass. Flat
colour is what makes a rendered world read as a diagram of a place rather than
a place, and it costs nothing to fix — a tiled 256 px image is cheaper than the
geometry you would otherwise need to break up a flat surface.

`scripts/make_orchard_textures` generates all of them procedurally: grass with
mower stripes, the weed-free strip kept under the tree row, fissured
lichen-flecked bark, four foliage variants, weathered timber and galvanised
sheet. Four foliage textures rather than one, because the trees are otherwise
built from the same handful of primitives and ninety-six of them in one identical
green reads as wallpaper — the same reason the generator picked a random leaf
shade per sphere before any of this existed.

**The apples are deliberately left as flat colour.** They are what is being
measured; texturing them would change the measurement, and at 5.5 m an apple is
eleven pixels across — there is nothing there to texture.

### The colour constraint every texture has to satisfy

`fruit_detector` calls a pixel ripe fruit when its hue is red **and** its
saturation is at least 160. Bark and soil are brown, and brown *is* dark orange:
it lands in the low red band by definition. So the world cannot rely on hue to
stay out of the detector's way — and this is not hypothetical. An earlier
orchard had bark and soil at hue 14 and 15 on OpenCV's scale, four units off the
threshold and clearing both the saturation and value guards, so every shadow
that nudged a pixel across the line became a false apple. Thirty-one of them.

The texture generator therefore **checks itself against the detector's own
thresholds and refuses to write a texture that could be read as fruit.** It
checks the worst pixel, not the average: a texture has a spread, and a mean
comfortably under the floor tells you nothing about the tail.

```
texture          mean rgb        worst red-hued saturation   reads as fruit
bark             (104, 95, 85)              0 / 130              0.0000
foliage0         ( 60, 94, 35)              0 / 130              0.0000
grass_sward      ( 89,111, 52)              0 / 130              0.0000
herbicide_strip  (122,109, 94)              0 / 130              0.0000
timber           ( 99, 86, 69)              0 / 130              0.0000
metal_sheet      (157,160,163)             30 / 130              0.0000
```

The floor is the detector's 160 less 30 of headroom, because a surface that
just scrapes under is one lighting change away from being fruit. The browns
land at hue 14-18 with peak saturation 52, 63 and 82 — the same hue band as the
bark that caused the trouble, and nowhere near the saturation that let it
through. Zero of their pixels satisfy all three of the detector's tests at
once, which is the column that actually matters.

### Two lights, because outdoors has two

The world had one directional sun. Outdoors, the sky fills shadow from every
direction at once, and a single sun leaves the underside of a canopy nearly
black — which looks wrong and, worse, is a real problem for a colour detector,
because a dark red apple in shadow drops below the value floor and stops being
fruit. There is now a weak, cool, shadowless fill from the opposite side.

One thing worth knowing before trying to tune this: **a Gazebo camera sensor
does not take its light from `<scene><ambient>`.** That setting is the viewer's.
Raising it changes the Gazebo window and changes the survey not at all.

The stock `model://ground_plane` is gone too. Its grey chequerboard is the most
recognisable thing in any generated Gazebo world, and laying grass over the
middle only hid the middle — the squares still ran to the horizon in a wide
shot. The grass box carries the collision now.

### The rest of the farm

An orchard is not ninety-six trees in a void. The world now also has a deer fence, a
headland track where the tractor turns, a packing shed and a water tank, bulk
bins, beehives, drip irrigation down each row, and a windbreak along the
weather side.

Two rules govern all of it. **Height**: the aircraft surveys at 5.5 m, so
nothing it flies over comes near that; the windbreak is the only tall thing and
it stands outside the block where no leg goes. **Colour**: several of these sit
inside the camera swath, and they are textured with the same checked materials
as everything else.

The **bulk bins in the alleys are there on purpose**. A 1.15 m wooden crate
directly under the camera, in a scene where the robot is hunting for
brown-adjacent red, is a specificity test that costs nothing — and if timber at
saturation 71 ever starts reading as fruit, the survey score says so in the same
run.

### The constraint that governs the whole world

An apple the drone cannot see is not a detection problem, it is a **scenario
bug** — and the first version of this world had one. Fruit was placed at a fixed
height that happened to sit *inside* the foliage spheres, and recall came out at
42.9% for reasons that had nothing to do with the detector.

Every apple is now ray-tested against every canopy sphere before it is written,
and only apples actually visible from above are marked ripe in the truth file:

```python
def _visible_from_above(self, ax, ay, az):
    for fx, fy, fz, fr in self.foliage:
        dh = math.hypot(ax - fx, ay - fy)
        if dh >= fr - APPLE_R * 0.5:
            continue                       # ray misses this sphere
        top = fz + math.sqrt(max(fr * fr - dh * dh, 0.0))
        if top > az + APPLE_R * 0.5:
            return False                   # leaves above the apple
    return True
```

The remaining misses are apples on the edge of visibility, which is the honest
residue of an overhead survey rather than a bug.

---

## Topics

| topic | type | |
|---|---|---|
| `/farm/sightings` | `FruitSighting` | one fruit, seen once, in one frame |
| `/farm/map` | `FruitMap` | everything believed so far, republished as it grows |
| `/farm/markers` | `MarkerArray` | the same, for RViz |
| `/farm/progress` | `SurveyProgress` | state, leg, area covered |
| `/farm/survey_path` | `nav_msgs/Path` | the planned pattern |
| `/uav_0/detections/image` | `Image` | the annotated camera view |

## Layout

```
launch/farm_survey.launch          all four stages at once, all tuning as args
launch/orchard_world.launch          1. Gazebo + the orchard
launch/survey_robot.launch           2. airframe + the three nodes
launch/farm_rviz.launch              3. the map
launch/farm_rqt.launch               4. the camera
scripts/make_orchard               generates the world AND the truth
scripts/make_orchard_textures      the tiling textures, checked against the detector
models/orchard/                    those textures and their Ogre materials
scripts/survey_pilot               coverage pattern
scripts/fruit_detector             colour -> blobs -> world positions
scripts/orchard_map                sightings -> fruit, and the scoring
scripts/reset_robot                remove the drone before relaunching stage 2
urdf/quadrotor_survey_cam.gazebo.xacro   quadrotor + downward camera
worlds/orchard.world               generated
config/orchard_truth.yaml          generated
```

## Tuning worth knowing

| arg | default | |
|---|---|---|
| `leg_spacing` | 3.0 | row spacing; overlap is deliberate |
| `survey_altitude` | 5.5 | |
| `fruit_plane_z` | 1.99 | mean apple height, from the truth file |
| `range_from_size` | false | measured worse here — see above |
| `sat_min` | 160 | the main colour guard; apples sit at 241 |
| `merge_radius` | 0.28 | sightings closer than this are one fruit |
| `min_sightings` | 15 | a real apple earns 53 on average, 18 at worst |
| `match_radius` | 0.15 | scoring only; under half the 0.31 m ripe-fruit spacing |
