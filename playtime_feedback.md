I've read the agent's feedback, and I agree with your instinct. Adding more spirits is probably the most valuable next content expansion for Spiritwright. I'd actually move it higher in the implementation order than the agent suggests.

The agent highlights something important: you already have 21 wild spirits with implemented combat traits, but only 6 playable spirits. That's a substantial amount of existing content that could become part of the player's collection.

And there's a bigger design issue here.

## Six spirits for six positions means there's no real roster-building

Currently, the player gets six spirits and eventually six golems. There's effectively no decision about who joins the team.

With 15–20 spirits but only six active slots, the player must start making interesting choices.

PROPOSED COLLECTION SYSTEM

# 6

Active golems

Battle team remains 3×2

# 15–20

Owned spirits

Choose who inhabits each vessel

But I would take the collection design slightly further than the agent.

## 1. Give spirits distinct identities, not just different elements

I wouldn't start by designing 10 more elements or adding new combat mechanics.

Use the existing elemental system, but create very different spirits within the same element.

For example:

| Spirit         | Identity                   | Preferred role                  |
| -------------- | -------------------------- | ------------------------------- |
| Pyra           | Brash fire spirit          | Aggressive burst damage         |
| Cinder Mote    | Reckless, unstable flame   | Burn spreading and self-risk    |
| Ember Guardian | Patient, protective flame  | Defensive retaliation           |
| Neris          | Calm water spirit          | Balanced support                |
| Brine Sprite   | Opportunistic water spirit | Disruption and Soaked synergies |
| Bog Lurker     | Stubborn marsh spirit      | Front-line control              |

These are proposed identities, not confirmation of the existing wild spirits' stats.

The goal is to make choosing between two Fire spirits meaningful, even if they're using the exact same golem parts.

I especially like your original Fire Emblem-inspired idea: different growth rates mean a spirit might naturally excel in one area, but players can build it however they like.

## 2. Make recruitment part of normal progression

Here's where I'd diverge from the agent.

It suggests unlocking wild spirits through optional challenges, like defeating a stage without losing a front-row golem.

That's a good idea for rare spirits, but I wouldn't make it the primary recruitment method.

Collecting spirits should be something the player experiences regularly, not something locked behind a challenge menu.

I'd use three recruitment methods:

- Campaign recruits: Some spirits automatically join after specific encounters. These establish a reliable growing collection.
- Wild spirit recruitment: Defeated wild spirits have an opportunity to join through a deterministic condition, such as defeating them with a particular element or status effect.
- Rare challenge recruits: Unusual spirits require optional encounters or specific achievements.

I would avoid random recruitment percentages initially. Players can work toward something specific without replaying the same encounter hoping for a lucky roll.

## 3. Make swapping spirits into bodies effortless

This might be the most important mechanical change.

Imagine you have a Bulwark built from Stone, carrying a Hammer and Guard Bell.

You could put Odo inside for a defensive Earth build, or Pyra for an aggressive counterattacking build.

[Voyagers of Nera ⛵OUT NOW on PC Steam! (@VoyagersofNera) on X](https://images.openai.com/static-rsc-4/sT2SpCPKXwlc1qzbA2IoKMO6mtblRbitqwzkdv460LpgRcDrdE5tP514bDtwJJcW7PraqJ0rtMccbJRTz-LGAFhtZSfSya_2pURXkpLitG_KyG8tFlBU47WmBm4V9s3KRBE5RSs3IHYIpmc-N7zlBkp6K0cUkcYqW3_IQ7YXzFk?purpose=inline)

Odo

Earth • Stubborn

[little elementals (1) | Images :: Behance](https://images.openai.com/static-rsc-4/oy9QzwAXzfpop0S-hvENsAkVFDuHJCuKfKuczctlFKoXGaP27JL7GfIFWxPpeoHZiaNahqF4cimR5b3vj3ncl-sYdd5OspB4qE3TMHfcCupzFUvjiArOLyw9bgkHOPOPwDC7jWpW0emVebXxv18ugPaXIdEH4mXTAqr9yZ7b1cU?purpose=inline)

Pyra

Fire • Brash

Shared Bulwark Vessel

Stone + Hammer + Pillar Legs + Guard Bell

Same body, different abilities and behaviour

If the game lets players swap spirits freely into existing vessels, their collection becomes useful immediately.

I'd keep experience and growth attached to the spirit, while equipment and material properties belong to the vessel.

That maintains the fantasy that the spirit is a persistent character and the golem is something the player engineers.

## 4. Don't introduce every new spirit at once

I'd distribute the next nine recruitable spirits across the existing campaign.

| Region          | New spirits | Total roster |
| --------------- | ----------- | ------------ |
| Starting roster | 3           | 3            |
| Ancient Ruins   | +3          | 6            |
| Glimmer Fen     | +3          | 9            |
| Ember Steppe    | +3          | 12           |
| Frostspine Pass | +2          | 14           |
| Storm Crown     | +1          | 15           |

This is an illustrative redistribution of recruits, replacing the existing reward schedule rather than adding them on top.

Players would regularly unlock new combinations, while being limited to six active golems.

By the mid-game, they could have nine or twelve spirits to choose from. That creates a genuine reason to experiment.

## 5. Be careful with the agent's balance recommendations

There is one area where I would challenge its conclusions.

The report says the Great Kiln has a 19.6% random-build win rate, while later stages can exceed 60%.

That's useful information, but random-build win rate isn't necessarily a good measure of actual difficulty.

A stage that defeats 90% of randomly generated teams might be trivial for a sensible team. Conversely, a stage that random teams beat 60% of the time might be frustrating because no strategy feels particularly effective.

I really like the agent's proposed counter-build gap metric, comparing previous-stage builds with builds optimised for the current encounter.

However, I'd also measure whether players can easily obtain and assemble the counter-build using the spirits and parts available at that stage.

Otherwise, it's possible to design theoretically solvable encounters that players cannot realistically prepare for.

## My suggested next development milestone

I'd call it The Living Roster Update.

SPIRITWRIGHT • NEXT MILESTONE

Implementation checklist

0/6

Add 9 recruitable wild spirits

Reuse existing wild spirit traits, with individual stats, growth rates, temperament and awakening.

Allow spirits to swap between vessels

Keep progression attached to spirits and equipment attached to bodies.

Update recruitment rewards

Spread new spirits across the campaign with a mixture of guaranteed and conditional recruitment.

Build a roster bench

Show available, active and resting spirits. Make team changes straightforward.

Add a few spirit-specific challenges

Give players a reason to revisit an encounter with a newly recruited spirit.

Run balance simulations

Check whether new recruits create meaningful choices rather than obvious upgrades.

&#x20;Copy milestone for development agent

One additional consideration: I'd delay raising the level cap from 20 to 30. More levels don't make a collection more interesting by themselves, and could worsen the gap between older and newly recruited spirits. The agent's existing catch-up-level rule is a good starting point.

### The bigger question for Spiritwright

I think there are two directions you could take this game:

A collection-focused autobattler, where the appeal is finding new spirits, building interesting bodies, developing favourites and trying combinations. The campaign and battles exist to support your collection.

A tactical puzzle autobattler, where the appeal is studying opponents, constructing counter-builds and overcoming progressively more complex encounters.

They aren't mutually exclusive, but they lead to different development priorities.

Given your original concept, I would make collection and golem engineering the main attraction, with tactical encounters encouraging players to use what they've collected.

That gives Spiritwright a stronger identity than simply being another autobattler with 30 stages to clear.