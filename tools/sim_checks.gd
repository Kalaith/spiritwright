extends "res://addons/hatchery/testing/check_runner.gd"
## Headless checks for the data and the simulation, on the toolkit's check
## runner: every `check_*` scenario of every module below prints PASS or FAIL
## (with the assertions that failed) and the run exits non-zero on a failure.
##   godot --headless --path . --script res://tools/sim_checks.gd [-- --only=<text>] [--module=<text>]
## Pass `-- --report` to also print every stage's outcome and the Crucible's for
## balance work, or `-- --crucible` for the Crucible alone.

const CheckModule = preload("res://tools/checks/check_module.gd")
const BalanceReport = preload("res://tools/checks/balance_report.gd")
const CrucibleChecks = preload("res://tools/checks/checks_crucible.gd")


## Only the data checks run when the catalog does not load: every other
## scenario would fail for the same reason.
func modules() -> Array[String]:
	if not CheckModule.shared_catalog().errors.is_empty():
		return ["res://tools/checks/checks_progression.gd"]
	return ["res://tools/checks/checks_progression.gd", "res://tools/checks/checks_battle.gd",
		"res://tools/checks/checks_collection.gd", "res://tools/checks/checks_crucible.gd",
		"res://tools/checks/checks_settings.gd"]


func after_all() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if failures > 0 or not CheckModule.shared_catalog().errors.is_empty():
		return
	if "--report" in args:
		BalanceReport.new().run()
	if "--report" in args or "--crucible" in args:
		CrucibleChecks.new().report()
