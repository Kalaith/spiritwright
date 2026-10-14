# Spirit art prompts

Image-generator prompts for a 2D portrait sprite of every collectable spirit (28: the 7 player spirits and the 21 wild spirits, bosses included). The spirit is the character and the golem is only its body, so these show the spirit itself, outside any vessel: a small elemental being, never armour or golem parts.

Ids, names, elements and temperaments come from `data/spirits.json`. If a spirit is added there, add its entry here.

## Image specification

| | |
| --- | --- |
| Generate at | **1024 x 1024 px**, square, PNG |
| Background | **Transparent (alpha)**. If the generator cannot do transparency, use a **flat solid `#FF00FF` magenta** with no gradient, texture, floor or vignette, and key it out afterwards. Never use green (it collides with Nature spirits) or white (it eats the glows). |
| Framing | One spirit, whole body, centred horizontally. It fills about **75%** of the canvas height (bosses about **90%**), with at least 64 px of empty margin on every side. The lowest point of the body (feet, tail, base of a wisp) sits about 90 px above the bottom edge. Nothing cropped. |
| Facing | Three-quarter view **facing right**, like the golems. The game mirrors enemies itself, so do not make left-facing versions. |
| Light | Key light from the upper right (the direction it faces), plus the spirit's own inner glow. |
| Shadow | **No ground shadow, no floor, no cast shadow.** The game draws its own shadow. |
| Glow | Glows and sparks stay close to the silhouette. No large soft halo filling the canvas: it turns into a grey fog once the background is removed. |
| Text | None: no name, letters, watermark, signature or frame. |

**Sizes used in game**: downscale the master with a good filter (Lanczos) to **512 x 512** (Codex card and spirit details), **256 x 256** (laboratory roster and result screen) and **128 x 128** (small icons). Check the 128 px version still reads: if the silhouette turns to mush, simplify the prompt.

**Files**: save as `assets/spirits/<id>.png` (for example `assets/spirits/pyra.png`), the master in `assets/spirits/source/<id>_1024.png`. Keep the ids exactly as below.

## Shared style

Paste this before every subject prompt so all 28 read as one set and sit beside the procedural golems:

> 2D game character sprite, stylised hand-painted cel shading with a bold dark outline (#17151e), clean readable silhouette, two to three tones of shading per colour, soft inner glow, small rim light, chibi-leaning proportions with a large head and expressive eyes, cute but not babyish, fantasy auto-battler collectible creature, full body, three-quarter view facing right, isolated on a transparent background, no ground, no shadow, no text.

Negative prompt (where the generator takes one):

> background scenery, floor, ground shadow, cast shadow, vignette, frame, border, text, letters, watermark, signature, logo, multiple characters, cropped, cut off, photorealistic, 3D render, blurry, armour, robot, golem body, weapon, extra limbs, large halo, smoke filling the frame

Element colours (the game shows a spirit's element by these, so keep each spirit's dominant glow on its element's colour):

| Element | Colour | Mood |
| --- | --- | --- |
| Fire | `#FF7A3D` (cores `#FFD36B`) | embers, flame tongues, heat shimmer |
| Water | `#4FB6FF` | droplets, tide, foam, mist |
| Earth | `#C99A5B` | stone, gravel, clay, rough crystal |
| Wind | `#9FE8C8` | swirls, ribbons, feathers, dust |
| Nature | `#7FD35A` | leaves, moss, vines, blossom |
| Lightning | `#F2E15A` | sparks, forked arcs, crackle |
| Echo | `#D8C8FF` | translucent layers, after-images, faint ghostly copies |

## Player spirits

### Pyra, the Emberling (`pyra`)
Fire, Brash. Starter.
> A small, quick-tempered fire spirit: a living ember the size of a cat, with a teardrop body of glowing coal cracked with bright orange-gold seams, a crest of flickering flame for hair swept forward, two stubby flame arms raised in a cocky fighting stance, a wide toothy grin and narrowed bright yellow eyes. Sparks spit off her edges. Orange #FF7A3D and yellow-gold, dark charcoal shadows.

### Neris, the Calm Tide (`neris`)
Water, Calm. Starter.
> A serene water spirit: a slender, floating figure made of clear deep-blue water, her lower body a curling wave instead of legs, long hair flowing like a slow current that ends in drifting droplets, eyes half-closed and peaceful, hands held before her shaping a small sphere of water. A ring of gentle ripples circles her. Blue #4FB6FF with pale foam highlights and deep navy shadows.

### Odo, the Gravemind (`odo`)
Earth, Stubborn. Starter.
> An old, heavy earth spirit: a squat, hunched being of weathered grey-brown stone with moss in its cracks, a great boulder-like head with a heavy brow ledge, small deep-set amber eyes glowing from shadow, a long beard of hanging pebbles, stubby thick arms crossed over its chest. It looks ancient, patient and immovable. Warm clay #C99A5B and grey stone, amber eye glow.

### Sefa, the Zephra (`sefa`)
Wind, Curious. Rescued in the Ember Steppe.
> A restless wind spirit: a light, airy sprite whose body tapers into a swirling little whirlwind below the waist, with long ribbon-like streamers of pale mint air trailing behind, a feather-like crest, big curious eyes, one hand reaching forward as if to touch something new. Leaves and a few water droplets spin in her wake. Mint #9FE8C8 with white highlights and soft teal shadows.

### Volta, the Sparkwright (`volta`)
Lightning, Patient. Rescued in the Glimmer Fen.
> A crackling lightning spirit: a small, poised figure made of bright yellow electricity with a body like a glowing filament, hair standing up in jagged forked arcs, calm focused eyes, one finger raised with a tiny spark held ready on its tip. Thin lightning arcs jump between her hands. Yellow #F2E15A with white-hot cores and deep violet-blue shadow accents.

### Briar, the Thornheart (`briar`)
Nature, Loyal. Rescued in the Ancient Ruins.
> A guarded nature spirit: a small figure woven of dark green bramble and thorny vines, with a bark-like face and wary bright green eyes, a single pink-white wild rose blooming over her heart, thorned vine arms wrapped protectively around herself, leaves sprouting from her shoulders. Gentle but prickly. Green #7FD35A, dark bark brown, one rose accent.

### Vesper, the Crucible Spirit (`vesper`)
Echo, Restless. Reward for completing the Crucible's Classic Royale.
> A mysterious echo spirit: a slender, genderless figure of translucent pale lavender light with two or three faint offset after-images of itself trailing behind it, a smooth mask-like face with glowing white eyes, a cloak that frays into drifting shards, and faint silhouettes of other spirits' features (a flame tip, a leaf, a droplet) flickering inside its body. Restless, mid-step. Lavender #D8C8FF, white glow, soft violet shadows.

## Wild spirits: Ancient Ruins

### Moss Wisp, the Mossling (`moss_wisp`)
Nature, Calm.
> A soft, round nature wisp: a floating puff of glowing green moss with a sleepy, content face, tiny sprouts and a little white mushroom on its head, small leaf hands, faint spores drifting around it. Green #7FD35A with pale yellow-green glow.

### Rubble Imp, the Pebblekin (`rubble_imp`)
Earth, Stubborn.
> A grumpy little earth imp: a lumpy heap of gravel and pebbles shaped into a short creature with a big frowning face, arms folded, one foot stamped down. Small grit falls from it. Clay #C99A5B and grey pebbles, small orange eye glow.

### Brine Sprite, the Saltspray (`brine_sprite`)
Water, Curious.
> A playful sea sprite: a splash of sea water shaped like a small child-like sprite, a frothy foam crest on its head, salt crystals glinting on its skin, a tiny shell on one ear, leaning forward with wide curious eyes as if asking a question. Blue #4FB6FF, white foam, sea-green tints.

### Cinder Mote, the Flicker (`cinder_mote`)
Fire, Brash.
> A tiny fire mote: a single bright spark with a flame tail, two big fierce eyes, a toothy grin, bristling with excitement, its tail half-burnt to grey ash at the tip as if about to gutter out. Orange #FF7A3D and gold, charcoal ash.

### Root Warden, the Old Growth (`root_warden`), boss
Nature, Loyal. Boss of the Ancient Ruins.
> The ancient keeper of the ruins: a towering, stooped nature spirit like a walking old oak, a mossy bark body with knotted root legs, long branch arms trailing hanging vines, a face carved into the trunk with deep glowing green eyes under a heavy brow, a crown of leaves and a broken carved stone fragment grown into its shoulder. Grave and dignified. Green #7FD35A glow, dark bark, grey stone. Fill 90% of the canvas height.

## Wild spirits: Glimmer Fen

### Bog Lurker, the Mirefoot (`bog_lurker`)
Water, Stubborn.
> A lumpy marsh spirit: a squat blob of dark muddy water with lily pads and reeds stuck to its back, two heavy-lidded bored eyes peering out, half sunk into itself, slow and unbothered. Murky teal-brown with blue #4FB6FF glow in its eyes and drips.

### Spark Newt, the Skitter (`spark_newt`)
Lightning, Curious.
> A quick little lightning newt: a slim lizard-like spirit made of yellow electricity, mid-skitter with its tail curled, glowing spots along its back, sparks leaping from its toes, big bright eyes. Yellow #F2E15A with white cores and a blue-violet rim.

### Reed Sprite, the Whistler (`reed_sprite`)
Nature, Patient.
> A slender fen sprite: a tall thin figure of green reeds bound together, hollow reed pipes forming its arms, holding one reed to its mouth to play, eyes closed in concentration, little musical wisps of light drifting from the pipe. Green #7FD35A, pale straw, soft gold.

### Fen Mother, the Drowned Matron (`fen_mother`), boss
Water, Calm. Boss of the Glimmer Fen.
> The fen's old mother: a tall, robed water spirit made of dark still marsh water, a long veil of hanging weed and lily blossoms over her head, a pale calm face with glowing blue eyes, long hands spread protectively, a skirt that dissolves into rippling water and drifting glowing wisps. Solemn, protective, a little eerie. Blue #4FB6FF glow, deep teal and black-green. Fill 90% of the canvas height.

## Wild spirits: Ember Steppe

### Ash Hound, the Cinderpup (`ash_hound`)
Fire, Loyal.
> A fire pup: a lean dog-like spirit of grey ash and glowing embers, flames for ears and tail, one ear flopped, tongue of flame lolling, eager loyal eyes, pawing the air ready to run. Orange #FF7A3D and gold over ash grey.

### Dust Devil, the Whirl (`dust_devil`)
Wind, Curious.
> A spinning dust spirit: a small whirlwind column of sandy grit with a mischievous face in the middle of the spin, two wispy arms flung out, pebbles and dry grass caught in its swirl. Mint #9FE8C8 air streaks over sandy beige.

### Slag Brute, the Slagheap (`slag_brute`)
Earth, Stubborn.
> A hulking slag spirit: a heavy, broad brute of cooled black-brown lava rock, glowing orange cracks still smouldering across its chest and knuckles, huge fists, a scowling face. Clay #C99A5B and dark basalt, orange glow in the cracks.

### Kiln Tyrant, the Forgelord (`kiln_tyrant`), boss
Fire, Brash. Boss of the Ember Steppe.
> The lord of the Great Kiln: a massive, imperious fire spirit with a body like a living furnace, a chest of glowing molten metal behind a grille of dark iron ribs, a crown of roaring flame, arms ending in molten fists, a commanding sneer, sparks and drips of molten metal falling from it. Orange #FF7A3D and gold, blackened iron. Fill 90% of the canvas height.

## Wild spirits: Frostspine Pass

### Frost Wisp, the Rimelight (`frost_wisp`)
Water, Patient.
> A cold drifting light: a pale blue-white wisp with a soft face, a trailing tail of snowflakes and frost crystals, a few ice crystals ringing it like a crown, watching with calm, patient eyes. Blue #4FB6FF and icy white.

### Gale Kite, the Updraft (`gale_kite`)
Wind, Brash.
> A darting wind spirit shaped like a living kite: a diamond-shaped body of taut mint air with long ribbon tails snapping in the wind, sharp eager eyes, swept back as if diving forward. Mint #9FE8C8 with white streaks.

### Rime Ogre, the Frostback (`rime_ogre`)
Earth, Calm.
> A huge, gentle frost ogre: a big round-shouldered spirit of grey stone with a thick back of frost and icicles, a kind, sleepy face, small eyes, big careful hands cupped as if holding something small. Clay #C99A5B stone with pale blue frost.

### Crag Sovereign, the Mountain King (`crag_sovereign`), boss
Earth, Stubborn. Boss of the Frostspine Pass.
> The ruler of the White Crag: a colossal, regal earth spirit like a mountain given a body, a broad chest of layered rock, snow on its shoulders, a jagged crown of mountain peaks, a stern ancient face with glowing amber eyes, one huge hand resting on a stone. Unmoving and majestic. Clay #C99A5B, grey granite, white snow, amber glow. Fill 90% of the canvas height.

## Wild spirits: Storm Crown

### Storm Hawk, the Talon (`storm_hawk`)
Wind, Brash.
> A fierce wind hawk: a bird-like spirit of storm-grey and mint air, wings half-spread in a climbing pose, feather tips trailing into wisps, sharp golden eyes, talons outstretched. Mint #9FE8C8 with slate grey.

### Volt Shade, the Afterimage (`volt_shade`)
Lightning, Patient.
> A flickering lightning shade: a thin, shadowy humanoid wisp edged in yellow electric light, its outline broken and glitching, a faint offset copy of itself beside it, glowing eyes, half turned as if already moving. Yellow #F2E15A edges on deep indigo shadow.

### Thunder Drake, the Stormscale (`thunder_drake`)
Lightning, Loyal.
> An old storm drake: a compact dragon spirit with dark scales veined with yellow lightning, a crest of jagged horns, wings folded protectively, wise watchful eyes, small sparks crackling along its spine. Yellow #F2E15A with deep slate-blue scales.

### Storm Sovereign, the Crowned Tempest (`storm_sovereign`), boss
Lightning, Patient. Boss of the Storm Crown and the game's finale.
> The storm that sits on the Crown: a vast, regal lightning spirit made of churning dark storm cloud, a calm still face at the eye of the storm with brilliant white-yellow eyes, a crown of forked lightning, arms of cloud with lightning coiling round them, rain and wind spiralling about its edges. Calm, overwhelming. Yellow #F2E15A and white lightning over deep indigo and grey cloud. Fill 90% of the canvas height.

## Tips

- Generate each spirit in a few variations with the same seed or style reference, and keep one image (Pyra works well) as the reference for the rest so the set stays consistent.
- Look at all 28 side by side at 128 px before using them: each element should read by colour and each spirit by silhouette.
- Check the alpha edge after keying: halo pixels of the old background colour show badly against the game's dark screens. Defringe or erode by 1 px if needed.
