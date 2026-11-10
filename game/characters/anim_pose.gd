class_name AnimPose
extends RefCounted
## Presentation request for one frame. Times below refer to the source animation clips.

var locomotion: bool = true
var speed_mps: float = 0.0
var move_angle: float = 0.0
var base_clip: StringName = &""
var base_time_s: float = -1.0
var action_clip: StringName = &""
var action_time_s: float = 0.0
var action_upper: bool = false
var overlay_clip: StringName = &""
var overlay_time_s: float = 0.0
