extends GutTest
## Check build-time failures and fractional clip endpoints in a separate headless engine.


func test_builder_rejects_missing_sources_and_keeps_final_samples() -> void:
	var output: Array = []
	var args: PackedStringArray = ["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"-s", "res://tests/helpers/character_clip_builder_probe.gd"]
	var status: int = OS.execute(OS.get_executable_path(), args, output, true)
	var log: String = "".join(output)
	assert_eq(status, 0, log)
	assert_false(log.contains("SCRIPT ERROR"), log)
	assert_string_contains(log, "clip builder probe passed")
