extends Control

const WelcomeScreen := preload("./welcome_screen/WelcomeScreen.gd")
const LoadingScreen := preload("./LoadingScreen.gd")
const ReportFormPopup := preload("./components/popups/ReportFormPopup.gd")
const SettingsPopup := preload("./components/popups/SettingsPopup.gd")

export var default_course := "res://course/course-learn-gdscript.tres"

var _unloading_target: Control
var _loading_target: Control
var _course_navigator: UINavigator

onready var _pages := $Pages as Control
onready var _loading_screen := $Pages/LoadingScreen as LoadingScreen
onready var _welcome_screen := $Pages/WelcomeScreen as WelcomeScreen
onready var _end_screen := $Pages/EndScreen as Control
onready var _settings_screen := $Pages/SettingsScreen as Control
onready var _course_screen := $Pages/CourseScreen as Control

onready var _settings_popup := $SettingsPopup as SettingsPopup
onready var _report_form_popup := $ReportFormPopup as ReportFormPopup


func _ready() -> void:
	_settings_popup.hide()
	_report_form_popup.hide()

	if not default_course.empty():
		var user_profile = UserProfiles.get_profile()
		var lesson_id = user_profile.get_last_started_lesson(default_course)
		if not lesson_id.empty():
			_welcome_screen.set_button_continue()

	_loading_screen.connect("faded_in", self, "_on_loading_faded_in")
	_loading_screen.connect("loading_finished", self, "_on_loading_finished")
	_welcome_screen.connect("course_requested", self, "_on_course_requested")

	Events.connect("report_form_requested", _report_form_popup, "show")
	Events.connect("settings_requested", _settings_popup, "show")
	Events.connect("course_completed", self, "_show_end_screen")

	NavigationManager.connect("welcome_screen_navigation_requested", self, "_go_to_welcome_screen")

	if NavigationManager.current_url != "":
		_on_course_requested()
		return

	load_immediately(_welcome_screen)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_full_screen"):
		OS.window_fullscreen = not OS.window_fullscreen


# Use this function to manually display the loading screen and control its
# progress. To increase the loading progress, set
# _loading_screen.progress_value. When the value reaches 1.0, the loading screen
# disappears automatically.
func start_loading(target: Control) -> void:
	_loading_target = target
	_loading_screen.reset_progress_value()
	_loading_screen.fade_in()


# Immediately displays the loaded target after playing the loading screen
# animation. If the loading screen is transparent, this function doesn't fade it
# in.
func load_immediately(target: Control) -> void:
	_loading_target = target
	_loading_screen.reset_progress_value()
	_loading_screen.show()
	_loading_screen.progress_value = 1.0


func _on_course_requested(force_outliner: bool = false) -> void:
	_unloading_target = _welcome_screen
	start_loading(_course_screen)

	_loading_screen.progress_value = 0.5
	yield(get_tree(), "idle_frame")

	if default_course.empty():
		# We completely failed, chief!
		printerr("Missing the default course path, make sure to set it in the UICore scene.")
		return

	# We don't preload this scene, nor the course resource, so that the initial load into the app
	# is faster.
	# FIXME: Use interactive loader instead?
	var course_navigator_scene := load("res://ui/UINavigator.tscn") as PackedScene
	_course_navigator = course_navigator_scene.instance()
	_course_navigator.course = load(default_course) as Course

	var user_profile = UserProfiles.get_profile()
	var lesson_id = user_profile.get_last_started_lesson(default_course)
	if not lesson_id.empty():
		_course_navigator.set_start_from_lesson(lesson_id)

	_course_navigator.load_into_outliner = force_outliner
	_course_screen.add_child(_course_navigator)

	_loading_screen.progress_value = 1.0


func _on_loading_faded_in() -> void:
	if _unloading_target and is_instance_valid(_unloading_target):
		_unloading_target.hide()
		_unloading_target = null


func _on_loading_finished() -> void:
	if _loading_target and is_instance_valid(_loading_target):
		_loading_target.show()
		_loading_target = null


func _show_end_screen(_course: Course) -> void:
	for page in _pages.get_children():
		page.hide()
	_end_screen.show()


func _go_to_welcome_screen() -> void:
	_course_screen.hide()
	_course_navigator.queue_free()
	start_loading(_welcome_screen)
	_loading_screen.progress_value = 1.0
