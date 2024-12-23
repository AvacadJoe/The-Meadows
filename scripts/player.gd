class_name Player extends CharacterBody3D

@export_category("Player")
@export_range(1, 35, 1) var speed: float = 10 # m/s
@export_range(10, 400, 1) var acceleration: float = 100 # m/s^2

@export_range(0.1, 3.0, 0.1) var jump_height: float = 1 # m
@export_range(0.1, 3.0, 0.1, "or_greater") var camera_sens: float = 1
@export var balloon_gravity = 5.0
@export var balloon_jump_height = 5.0

@onready var balloon_mesh = $Balloon
@onready var flash_light = $Camera/Flashlight

var jumping: bool = false
var mouse_captured: bool = false

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var move_dir: Vector2 # Input direction for movement
var look_dir: Vector2 # Input direction for look/aim

var walk_vel: Vector3 # Walking velocity 
var grav_vel: Vector3 # Gravity velocity 
var jump_vel: Vector3 # Jumping velocity

var balloon_active = false :
    set (value):
        balloon_active = value
        
        if value:
            %BalloonInflateSound.playing = true
            balloon_mesh.visible = value
            balloon_mesh.scale = Vector3(0.1,0.1,0.1)
            var tween = get_tree().create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
            tween.tween_property(balloon_mesh, "scale", Vector3(0.5,0.5,0.5), 1)
            %BalloonLabel.text = "[center]Press B to deflate balloon[/center]"
        else:
            %BalloonDeflateSound.playing = true
            var tween = get_tree().create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
            tween.tween_property(balloon_mesh, "scale", Vector3(0.1,0.1,0.1), 1)
            tween.tween_property(balloon_mesh, "visible", value, 0)
            %BalloonLabel.text = "[center]Press B to inflate balloon[/center]"
    get:
        return balloon_active
        
var flashlight_active = false :
    set (value):
        flashlight_active    = value
        flash_light.visible  = value
        %SwitchSound.playing = true
        if value:
            %FlashlightLabel.text = "[center]Press F to turn off flashlight[/center]"
        else:
            %FlashlightLabel.text = "[center]Press F to turn on flashlight[/center]"
    get:
        return flashlight_active
        
               
var in_convo = false :
    set (value):
        in_convo = value
        if value:
            %InteractLabel.visible = !value
            release_mouse()
        else:
            capture_mouse()
    get:
        return in_convo

signal interact()
signal player_position_change(player_position)

@onready var camera: Camera3D = $Camera

var interactable = false :
    set (value):
        %InteractLabel.visible = value            
        interactable = value
    get:
        return interactable


func _ready() -> void:
    capture_mouse()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion:
        look_dir = event.relative * 0.001
        if mouse_captured: _rotate_camera()
    if Input.is_action_just_pressed("jump"): jumping = true
    if Input.is_action_just_pressed("exit"): get_tree().quit()
    if Input.is_action_just_pressed("interact"): interact.emit()
    if Input.is_action_just_pressed("balloon") and is_on_floor() and GameManager.balloon_unlocked: balloon_active = not balloon_active
    if Input.is_action_just_pressed("flashlight") and GameManager.flashlight_unlocked: flashlight_active = not flashlight_active
    if Input.is_action_just_pressed("menu"): 
        %EscMenu.visible = not %EscMenu.visible
        if %EscMenu.visible:
            release_mouse()
        else:
            capture_mouse()

func _physics_process(delta: float) -> void:
    if mouse_captured: _handle_joypad_camera_rotation(delta)
    
    if walk_vel == Vector3(0,0,0):
        %WalkingSounds.stream_paused = true
    elif is_on_floor() and not in_convo:
        %WalkingSounds.stream_paused = false
        if  %WalkingSounds.playing == false:
            %WalkingSounds.playing = true

    
    velocity = _walk(delta) + _gravity(delta) + _jump(delta)
    if not in_convo:
        move_and_slide()
    
    # Push the Character Position to the Shader
    player_position_change.emit(self.global_position)

func capture_mouse() -> void:
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
    mouse_captured = true
 
func release_mouse() -> void:
    Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
    mouse_captured = false

func _rotate_camera(sens_mod: float = 1.0) -> void:
    camera.rotation.y -= look_dir.x * GameManager.camera_sens * sens_mod
    camera.rotation.x = clamp(camera.rotation.x - look_dir.y * GameManager.camera_sens * sens_mod, -1.5, 1.5)

func _handle_joypad_camera_rotation(delta: float, sens_mod: float = 1.0) -> void:
    var joypad_dir: Vector2 = Input.get_vector("look_left","look_right","look_up","look_down")
    if joypad_dir.length() > 0:
        look_dir += joypad_dir * delta
        _rotate_camera(sens_mod)
        look_dir = Vector2.ZERO

func _walk(delta: float) -> Vector3:
    move_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backwards")
    var _forward: Vector3 = camera.global_transform.basis * Vector3(move_dir.x, 0, move_dir.y)
    var walk_dir: Vector3 = Vector3(_forward.x, 0, _forward.z).normalized()
    walk_vel = walk_vel.move_toward(walk_dir * speed * move_dir.length(), acceleration * delta)
    return walk_vel

func _gravity(delta: float) -> Vector3:
    if balloon_active:
        grav_vel = Vector3.ZERO if is_on_floor() else grav_vel.move_toward(Vector3(0, velocity.y - balloon_gravity, 0), balloon_gravity * delta)
    else:
        grav_vel = Vector3.ZERO if is_on_floor() else grav_vel.move_toward(Vector3(0, velocity.y - gravity, 0), gravity * delta)
   
    return grav_vel

func _jump(delta: float) -> Vector3:
    if jumping:
        if is_on_floor():
            %WalkingSounds.stream_paused = true
            if balloon_active:
                %BalloonJumpSound.playing = true
                jump_vel = Vector3(0, sqrt(4 * balloon_jump_height * balloon_gravity), 0)
            else:
                %JumpSound.playing = true
                jump_vel = Vector3(0, sqrt(4 * jump_height * gravity), 0)
                
        jumping = false
        return jump_vel
    jump_vel = Vector3.ZERO if is_on_floor() else jump_vel.move_toward(Vector3.ZERO, gravity * delta)
    return jump_vel
