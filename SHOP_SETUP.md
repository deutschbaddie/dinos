# Shop setup: create these on Roblox, paste the ids

Creator Hub → your experience → **Monetization → Developer Products** (and **Passes**). Create each one with the
name, price and icon below, then paste its id into `src/ReplicatedStorage/DinoExpedition/Game/Config.luau`
(`Config.Products` / `Config.Passes`, the `Id = 0` field). Until an id is filled in, that button says SOON.
The shop always shows the **live Roblox price**, so you can reprice on the dashboard without touching code
(update `Price` in Config too: it feeds the honest "SAVE %" and "X VALUE" tags).

## Developer products

| Config key | Name on Roblox | Robux | Icon | What it gives |
|---|---|---|---|---|
| StarterPack1 | Explorer Pack | 49 | Chest | RARE+ egg + 5,000 coins + 15 min luck (once per player) |
| StarterPack2 | Ranger Pack | 199 | Chest | EPIC+ egg + 3 premium eggs + 25,000 coins + 2 instant hatches (once) |
| StarterPack3 | Titan Pack | 499 | Crown | LEGENDARY egg + 5 premium eggs + 100,000 coins + 1 companion slot (once) |
| PremiumEgg | Premium Egg | 49 | Egg | 1 premium egg |
| PremiumEgg3 | 3 Premium Eggs | 129 | Egg | 3 premium eggs (save 12%) |
| PremiumEgg10 | 10 Premium Eggs | 399 | Chest | 10 premium eggs (save 19%) |
| RareEgg | Rare+ Egg | 99 | Egg | 1 egg, Rare or better |
| EpicEgg | Epic+ Egg | 249 | Egg | 1 egg, Epic or better |
| LegendaryEgg | Legendary Egg | 599 | Egg | 1 egg, Legendary or Secret |
| LuckBoost | Luck Boost 15 Min | 49 | Star | 15 min of better nest eggs |
| LuckBoost60 | Luck Boost 1 Hour | 149 | Star | 60 min (save 24%) |
| InstantHatch | Instant Hatch | 25 | Clock | finishes your next egg |
| InstantHatch5 | 5 Instant Hatches | 99 | Clock | five of them (save 21%) |
| CompanionSlot | +1 Companion Slot | 149 | Buddy | one more companion (a premium egg if you're maxed) |

## Game passes (unchanged)

| Config key | Suggested Robux |
|---|---|
| DoubleMoney | 399 |
| MoreIncubators | 199 |
| VipRack | 149 |
| AutoCollect | 249 |

## Odds (shown in game under SEE ODDS, required by Roblox for paid random items)

Shop eggs roll from fixed odds (luck boosts don't change them). The species is one of the player's unlocked
non-boss dinos, equal chance each.

| Egg | Common | Uncommon | Rare | Epic | Legendary | Secret |
|---|---|---|---|---|---|---|
| Premium | 23.05% | 43.36% | 21.85% | 9.32% | 2.13% | 0.29% |
| Rare+ | | | 65.07% | 27.75% | 6.33% | 0.85% |
| Epic+ | | | | 79.44% | 18.12% | 2.44% |
| Legendary | | | | | 88.14% | 11.86% |

The luck boost's own effect is shown on its card: a nest egg's Legendary chance goes from 0.45% to 1.49%.
