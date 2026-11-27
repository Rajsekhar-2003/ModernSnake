
extends Node2D

# =====================================
# MODERN SNAKE GAME - GODOT 4
# =====================================

const CELL_SIZE := 24
const GRID_WIDTH := 28
const GRID_HEIGHT := 19

const BOARD_WIDTH := CELL_SIZE * GRID_WIDTH
const BOARD_HEIGHT := CELL_SIZE * GRID_HEIGHT

const SCREEN_WIDTH := 800
const SCREEN_HEIGHT := 600

const BOARD_OFFSET := Vector2(
    (SCREEN_WIDTH - BOARD_WIDTH) / 2.0,
    105
)

const BG_COLOR := Color("#101827")
const BOARD_COLOR := Color("#172438")
const GRID_COLOR := Color("#21334a")
const SNAKE_COLOR := Color("#38e58a")
const HEAD_COLOR := Color("#78ffb5")
const FOOD_COLOR := Color("#ff5277")
const TEXT_COLOR := Color("#f1f5f9")
const MUTED_COLOR := Color("#91a4bd")

enum GameState {
    PLAYING,
    PAUSED,
    GAME_OVER
}

var snake: Array[Vector2i] = []
var direction := Vector2i.RIGHT
var next_direction := Vector2i.RIGHT
var food := Vector2i.ZERO

var score := 0
var high_score := 0
var game_state := GameState.PLAYING

var move_timer := 0.0
var move_interval := 0.14

var touch_start := Vector2.ZERO

var rng := RandomNumberGenerator.new()


func _ready() -> void:
    rng.randomize()
    load_high_score()
    start_game()


func _process(delta: float) -> void:
    if game_state == GameState.PLAYING:
        move_timer += delta

        if move_timer >= move_interval:
            move_timer -= move_interval
            move_snake()

    queue_redraw()


func start_game() -> void:
    snake.clear()

    var center := Vector2i(
        GRID_WIDTH / 2,
        GRID_HEIGHT / 2
    )

    snake.append(center)
    snake.append(center + Vector2i.LEFT)
    snake.append(center + Vector2i.LEFT * 2)

    direction = Vector2i.RIGHT
    next_direction = Vector2i.RIGHT

    score = 0
    move_timer = 0.0
    move_interval = 0.14

    game_state = GameState.PLAYING

    spawn_food()
    queue_redraw()


func spawn_food() -> void:
    var attempts := 0

    while attempts < 1000:
        var candidate := Vector2i(
            rng.randi_range(0, GRID_WIDTH - 1),
            rng.randi_range(0, GRID_HEIGHT - 1)
        )

        if not snake.has(candidate):
            food = candidate
            return

        attempts += 1

    game_state = GameState.GAME_OVER


func move_snake() -> void:
    direction = next_direction

    var new_head: Vector2i = snake[0] + direction

    # Wall collision
    if (
        new_head.x < 0
        or new_head.x >= GRID_WIDTH
        or new_head.y < 0
        or new_head.y >= GRID_HEIGHT
    ):
        end_game()
        return

    var eating := new_head == food

    # Allow movement into the old tail cell
    var collision_length := snake.size()

    if not eating:
        collision_length -= 1

    for i in range(collision_length):
        if snake[i] == new_head:
            end_game()
            return

    snake.push_front(new_head)

    if eating:
        score += 10

        if score > high_score:
            high_score = score
            save_high_score()

        move_interval = maxf(
            0.055,
            0.14 - (score / 10) * 0.004
        )

        spawn_food()
    else:
        snake.pop_back()

    queue_redraw()


func end_game() -> void:
    game_state = GameState.GAME_OVER
    save_high_score()
    queue_redraw()


func set_direction(new_direction: Vector2i) -> void:
    if new_direction + direction != Vector2i.ZERO:
        next_direction = new_direction


func _unhandled_input(event: InputEvent) -> void:

    if event is InputEventKey and event.pressed and not event.echo:

        match event.keycode:
            KEY_UP, KEY_W:
                set_direction(Vector2i.UP)

            KEY_DOWN, KEY_S:
                set_direction(Vector2i.DOWN)

            KEY_LEFT, KEY_A:
                set_direction(Vector2i.LEFT)

            KEY_RIGHT, KEY_D:
                set_direction(Vector2i.RIGHT)

            KEY_P, KEY_ESCAPE:
                toggle_pause()

            KEY_ENTER, KEY_SPACE:
                if game_state != GameState.PLAYING:
                    start_game()

    # Mobile touch controls
    if event is InputEventScreenTouch:
        if event.pressed:
            touch_start = event.position
        else:
            var swipe: Vector2 = event.position - touch_start

            if swipe.length() > 30:
                if absf(swipe.x) > absf(swipe.y):
                    if swipe.x > 0:
                        set_direction(Vector2i.RIGHT)
                    else:
                        set_direction(Vector2i.LEFT)
                else:
                    if swipe.y > 0:
                        set_direction(Vector2i.DOWN)
                    else:
                        set_direction(Vector2i.UP)

    # Mouse swipe support
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            if event.pressed:
                touch_start = event.position
            else:
                var swipe: Vector2 = event.position - touch_start

                if swipe.length() > 30:
                    if absf(swipe.x) > absf(swipe.y):
                        set_direction(
                            Vector2i.RIGHT if swipe.x > 0
                            else Vector2i.LEFT
                        )
                    else:
                        set_direction(
                            Vector2i.DOWN if swipe.y > 0
                            else Vector2i.UP
                        )


func toggle_pause() -> void:
    if game_state == GameState.PLAYING:
        game_state = GameState.PAUSED
    elif game_state == GameState.PAUSED:
        game_state = GameState.PLAYING


# =====================================
# HIGH SCORE STORAGE
# =====================================

func save_high_score() -> void:
    var config := ConfigFile.new()
    config.set_value("game", "high_score", high_score)
    config.save("user://snake.cfg")


func load_high_score() -> void:
    var config := ConfigFile.new()

    if config.load("user://snake.cfg") == OK:
        high_score = config.get_value(
            "game",
            "high_score",
            0
        )


# =====================================
# DRAWING FUNCTIONS
# =====================================

func _draw() -> void:
    draw_background()
    draw_header()
    draw_board()
    draw_food()
    draw_snake()
    draw_footer()

    if game_state == GameState.PAUSED:
        draw_overlay("PAUSED", "Press P or ESC to continue")

    elif game_state == GameState.GAME_OVER:
        draw_overlay(
            "GAME OVER",
            "Press ENTER or SPACE to play again"
        )


func draw_background() -> void:
    draw_rect(
        Rect2(Vector2.ZERO, Vector2(SCREEN_WIDTH, SCREEN_HEIGHT)),
        BG_COLOR
    )


func draw_header() -> void:
    draw_string(
        ThemeDB.fallback_font,
        Vector2(40, 48),
        "SNAKE",
        HORIZONTAL_ALIGNMENT_LEFT,
        -1,
        30,
        SNAKE_COLOR
    )

    draw_string(
        ThemeDB.fallback_font,
        Vector2(40, 78),
        "MODERN ARCADE",
        HORIZONTAL_ALIGNMENT_LEFT,
        -1,
        12,
        MUTED_COLOR
    )

    draw_string(
        ThemeDB.fallback_font,
        Vector2(BOARD_OFFSET.x + BOARD_WIDTH - 180, 43),
        "SCORE",
        HORIZONTAL_ALIGNMENT_CENTER,
        110,
        12,
        MUTED_COLOR
    )

    draw_string(
        ThemeDB.fallback_font,
        Vector2(BOARD_OFFSET.x + BOARD_WIDTH - 180, 76),
        str(score),
        HORIZONTAL_ALIGNMENT_CENTER,
        110,
        25,
        TEXT_COLOR
    )

    draw_string(
        ThemeDB.fallback_font,
        Vector2(BOARD_OFFSET.x + BOARD_WIDTH - 65, 43),
        "BEST",
        HORIZONTAL_ALIGNMENT_CENTER,
        65,
        12,
        MUTED_COLOR
    )

    draw_string(
        ThemeDB.fallback_font,
        Vector2(BOARD_OFFSET.x + BOARD_WIDTH - 65, 76),
        str(high_score),
        HORIZONTAL_ALIGNMENT_CENTER,
        65,
        25,
        SNAKE_COLOR
    )


func draw_board() -> void:
    var board_rect := Rect2(
        BOARD_OFFSET,
        Vector2(BOARD_WIDTH, BOARD_HEIGHT)
    )

    draw_rect(board_rect, BOARD_COLOR)

    # Grid lines
    for x in range(GRID_WIDTH + 1):
        var px := BOARD_OFFSET.x + x * CELL_SIZE

        draw_line(
            Vector2(px, BOARD_OFFSET.y),
            Vector2(px, BOARD_OFFSET.y + BOARD_HEIGHT),
            GRID_COLOR,
            1.0
        )

    for y in range(GRID_HEIGHT + 1):
        var py := BOARD_OFFSET.y + y * CELL_SIZE

        draw_line(
            Vector2(BOARD_OFFSET.x, py),
            Vector2(BOARD_OFFSET.x + BOARD_WIDTH, py),
            GRID_COLOR,
            1.0
        )


func draw_snake() -> void:
    for i in range(snake.size()):
        var segment := snake[i]

        var position := BOARD_OFFSET + Vector2(
            segment.x * CELL_SIZE,
            segment.y * CELL_SIZE
        )

        var rect := Rect2(
            position + Vector2(2, 2),
            Vector2(CELL_SIZE - 4, CELL_SIZE - 4)
        )

        if i == 0:
            draw_rect(rect, HEAD_COLOR)
            draw_snake_eyes(position)
        else:
            var color := SNAKE_COLOR

            # Subtle tail gradient
            color.a = maxf(
                0.45,
                1.0 - float(i) / maxf(10.0, snake.size() * 1.5)
            )

            draw_rect(rect, color)


func draw_snake_eyes(position: Vector2) -> void:
    var eye_color := Color("#10251d")

    var center := position + Vector2(
        CELL_SIZE / 2.0,
        CELL_SIZE / 2.0
    )

    var eye_offset := Vector2(
        direction.x * 4,
        direction.y * 4
    )

    var perpendicular := Vector2(
        -direction.y,
        direction.x
    )

    draw_circle(
        center + eye_offset + perpendicular * 5,
        2.2,
        eye_color
    )

    draw_circle(
        center + eye_offset - perpendicular * 5,
        2.2,
        eye_color
    )


func draw_food() -> void:
    var center := BOARD_OFFSET + Vector2(
        (food.x + 0.5) * CELL_SIZE,
        (food.y + 0.5) * CELL_SIZE
    )

    draw_circle(center, 9, Color("#702d49"))
    draw_circle(center, 6, FOOD_COLOR)

    draw_circle(
        center + Vector2(-2, -2),
        2,
        Color("#ffffff")
    )


func draw_footer() -> void:
    draw_string(
        ThemeDB.fallback_font,
        Vector2(BOARD_OFFSET.x, 590),
        "ARROWS / WASD  MOVE     P  PAUSE     ENTER  RESTART",
        HORIZONTAL_ALIGNMENT_LEFT,
        BOARD_WIDTH,
        12,
        MUTED_COLOR
    )


func draw_overlay(title_text: String, subtitle: String) -> void:
    draw_rect(
        Rect2(
            BOARD_OFFSET,
            Vector2(BOARD_WIDTH, BOARD_HEIGHT)
        ),
        Color(0.03, 0.06, 0.11, 0.82)
    )

    var center_x := BOARD_OFFSET.x + BOARD_WIDTH / 2.0
    var center_y := BOARD_OFFSET.y + BOARD_HEIGHT / 2.0

    var title_color := (
        FOOD_COLOR if game_state == GameState.GAME_OVER
        else SNAKE_COLOR
    )

    draw_string(
        ThemeDB.fallback_font,
        Vector2(center_x - 200, center_y - 20),
        title_text,
        HORIZONTAL_ALIGNMENT_CENTER,
        400,
        36,
        title_color
    )

    draw_string(
        ThemeDB.fallback_font,
        Vector2(center_x - 250, center_y + 25),
        subtitle,
        HORIZONTAL_ALIGNMENT_CENTER,
        500,
        15,
        TEXT_COLOR
    )

    if game_state == GameState.GAME_OVER:
        draw_string(
            ThemeDB.fallback_font,
            Vector2(center_x - 150, center_y + 65),
            "FINAL SCORE: " + str(score),
            HORIZONTAL_ALIGNMENT_CENTER,
            300,
            17,
            SNAKE_COLOR
        )
