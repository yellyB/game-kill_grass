extends Control

signal dialog_confirmed
signal dialog_cancelled

@onready var overlay: ColorRect = $Overlay
@onready var dialog_panel: Panel = $DialogPanel
@onready var message_label: Label = $DialogPanel/VBox/MessageLabel
@onready var confirm_btn: Button = $DialogPanel/VBox/BtnRow/ConfirmBtn
@onready var cancel_btn: Button = $DialogPanel/VBox/BtnRow/CancelBtn

func _ready() -> void:
  visible = false
  confirm_btn.pressed.connect(_on_confirm)
  cancel_btn.pressed.connect(_on_cancel)
  GameManager.style_button(confirm_btn)
  GameManager.style_button(cancel_btn, "muted")

func show_dialog(message: String, confirm_text: String = "확인", cancel_text: String = "취소") -> void:
  message_label.text = message
  confirm_btn.text = confirm_text
  cancel_btn.text = cancel_text
  visible = true

func hide_dialog() -> void:
  visible = false

func _on_confirm() -> void:
  GameManager.play_confirm_click()
  visible = false
  dialog_confirmed.emit()

func _on_cancel() -> void:
  GameManager.play_button_click()
  visible = false
  dialog_cancelled.emit()
