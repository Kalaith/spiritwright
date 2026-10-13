extends RefCounted
## The Crucible's persistent state, owned by Progression and saved with it:
## the run in progress (its locked team and sequence), the records of every
## Royale and tier, the milestones met, the encounters beaten at least once,
## the chosen title, and the last run's setup and fate (shown when choosing
## the next). Rules live in crucible.gd; validation in save_schema.gd.

const Catalog = preload("res://scripts/core/catalog.gd")
const Crucible = preload("res://scripts/core/crucible.gd")
## How many winning teams each record keeps, newest first.
const KEPT_TEAMS: int = 5

## {} when no run is under way, else {"mode", "tier", "seed", "sequence":
## [{"encounter", "variant"}], "next": index of the step to fight, "team":
## [loadouts, locked], "history": {spirit id: Builds history}}.
var run: Dictionary = {}
## "mode:tier" -> {"best": most steps won in one run, "runs", "completions",
## "teams": [{"seed", "golems": [loadouts]}]}.
var records: Dictionary = {}
var milestones: Array = []
var seen: Array = []
var title: String = ""
## {"mode", "tier", "seed"} of the last run begun, and, once it ended without
## completing, "fell_at" (step index) too.
var last: Dictionary = {}


static func empty() -> Dictionary:
	return {"run": {}, "records": {}, "milestones": [], "seen": [], "title": "", "last": {}}


func to_dict() -> Dictionary:
	return {"run": run, "records": records, "milestones": milestones, "seen": seen, "title": title, "last": last}


## Loads a block save_schema.gd has already validated.
func apply(data: Dictionary) -> void:
	run = data.run.duplicate(true)
	if not run.is_empty():
		run.seed = int(run.seed)
		run.next = int(run.next)
		for step in run.sequence:
			step.variant = int(step.variant)
		for loadout in run.team:
			loadout["lane"] = int(loadout.lane)
	records = {}
	for key in data.records:
		var entry: Dictionary = data.records[key]
		records[key] = {"best": int(entry.best), "runs": int(entry.runs), "completions": int(entry.completions),
			"teams": entry.teams.map(func(t): return {"seed": int(t.seed), "golems": t.golems.duplicate(true)})}
	milestones = data.milestones.map(func(id): return String(id))
	seen = data.seen.map(func(id): return String(id))
	title = String(data.title)
	last = data.last.duplicate(true)
	for key in ["seed", "fell_at"]:
		if last.has(key):
			last[key] = int(last[key])


func record(mode: String, tier_id: String) -> Dictionary:
	return records.get(Crucible.record_key(mode, tier_id), {"best": 0, "runs": 0, "completions": 0, "teams": []})


## Begins a run with `team` (loadouts) locked as it stands and each spirit's
## `history` (see Builds.preference) fixed with it.
func start(catalog: Catalog, mode: String, tier_id: String, seed: int, team: Array, history: Dictionary) -> void:
	run = {"mode": mode, "tier": tier_id, "seed": seed, "sequence": Crucible.sequence(catalog, mode, seed), "next": 0,
		"team": team.duplicate(true), "history": history.duplicate(true)}
	last = {"mode": mode, "tier": tier_id, "seed": seed}
	var entry: Dictionary = record(mode, tier_id)
	entry.runs += 1
	records[Crucible.record_key(mode, tier_id)] = entry


func step() -> Dictionary:
	return run.sequence[int(run.next)]


## Applies the current step's result. A win moves on (or completes the run);
## anything else ends it. Returns the result screen's report: {"mode", "tier",
## "encounter", "index", "steps", "won", "complete", "ended", "best",
## "new_best", "milestones": [ids met now]}. Spirits a milestone brings are
## granted through `grant` (Progression._grant) into `report.rewards`.
func apply_result(catalog: Catalog, outcome: String, grant: Callable) -> Dictionary:
	var index: int = int(run.next)
	var won: bool = outcome == "win"
	var key: String = Crucible.record_key(run.mode, run.tier)
	var entry: Dictionary = record(run.mode, run.tier)
	var report: Dictionary = {"mode": run.mode, "tier": run.tier, "encounter": step().encounter, "index": index,
		"steps": run.sequence.size(), "won": won, "complete": false, "ended": not won, "best": int(entry.best),
		"new_best": false, "milestones": [], "rewards": []}
	if won:
		if not report.encounter in seen:
			seen.append(report.encounter)
		run.next = index + 1
		report.complete = run.next >= run.sequence.size()
		report.ended = report.complete
		if run.next > int(entry.best):
			entry.best = run.next
			report.new_best = true
		if report.complete:
			entry.completions += 1
			entry.teams.push_front({"seed": int(run.seed), "golems": run.team.duplicate(true)})
			entry.teams = entry.teams.slice(0, KEPT_TEAMS)
	report.best = int(entry.best)
	records[key] = entry
	var result: Dictionary = {"won": int(run.next) if won else index, "complete": report.complete, "mode": run.mode,
		"tier": run.tier, "golems": run.team.size()}
	for id in catalog.crucible_index.milestones:
		var milestone: Dictionary = catalog.crucible_index.milestones[id]
		if not id in milestones and Crucible.milestone_met(milestone.rules, result):
			milestones.append(id)
			report.milestones.append(id)
			grant.call({"spirits": milestone.rewards.get("spirits", [])}, report.rewards)
			for kind in ["titles", "finishes"]:
				for reward in milestone.rewards.get(kind, []):
					report.rewards.append({"kind": kind, "id": reward})
	if report.ended:
		if not report.complete:
			last["fell_at"] = index
		run = {}
	return report


## Gives up the run in progress; it counts as falling at the step it stood on.
func abandon() -> void:
	if not run.is_empty():
		last["fell_at"] = int(run.next)
	run = {}
