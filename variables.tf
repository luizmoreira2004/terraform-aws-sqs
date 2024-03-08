variable "max_message_size" {
    type    = number
    default = 262144
}

variable "receive_wait_time_seconds" {
    type    = number
    default = 20
}

variable "visibility_timeout_seconds" {
    type    = number
    default = 30
}

variable "delay_seconds" {
    type    = number
    default = 0
}

variable "message_retention_seconds" {
    type    = number
    default = 1209600
}

variable "name_topic_alert_dead_letter" {
    type    = string
    default = "alarme-fila-morta"
}

variable "email_topic_subscription" {
    type    = string
}
