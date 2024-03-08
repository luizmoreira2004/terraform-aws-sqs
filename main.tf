#CRIAR FILA
resource "aws_sqs_queue" "terraform_queue" {
    for_each = {for sqs, sqs_list in local.sqs_list[*] : sqs => sqs_list}
    name                       = "${each.value.name}_${each.value.env}"
    delay_seconds              = var.delay_seconds
    max_message_size           = var.max_message_size
    message_retention_seconds  = var.message_retention_seconds
    receive_wait_time_seconds  = var.receive_wait_time_seconds
    visibility_timeout_seconds = var.visibility_timeout_seconds
    sqs_managed_sse_enabled    = false
    redrive_policy = jsonencode({
        deadLetterTargetArn = values(aws_sqs_queue.terraform_queue_deadletter)[each.key].arn
        maxReceiveCount     = 10
    })

    tags = {
        Environment = "${each.value.env}"
    }
}

#CRIAR FILA MORTA
resource "aws_sqs_queue" "terraform_queue_deadletter" {
    for_each = {for sqs, sqs_list in local.sqs_list[*] : sqs => sqs_list}
    name                       = "${each.value.name}_dead_letter_${each.value.env}"
    delay_seconds              = var.delay_seconds
    max_message_size           = var.max_message_size
    message_retention_seconds  = var.message_retention_seconds
    receive_wait_time_seconds  = var.receive_wait_time_seconds
    visibility_timeout_seconds = var.visibility_timeout_seconds
    sqs_managed_sse_enabled    = false

    tags = {
        Environment = "${each.value.env}"
    }
}

#CRIAR POLITICA CONSUMO DA FILA
resource "aws_iam_policy" "politica_consumo" {
    for_each = {for sqs, sqs_list in local.sqs_list[*] : sqs => sqs_list}
    name = "${each.value.name}_${each.value.env}_consumo_politica"

    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
        {
            Action = [
            "sqs:DeleteMessage",
            "sqs:ReceiveMessage"
            ]
            Effect   = "Allow"
            Resource = values(aws_sqs_queue.terraform_queue)[each.key].arn
        },
        ]
    })
}
resource "aws_iam_user" "user_consumo" {
    for_each = {for sqs, sqs_list in local.sqs_list[*] : sqs => sqs_list}
    name = "${each.value.name}_${each.value.env}_consumo_politica"
}

resource "aws_iam_user_policy_attachment" "user_politica_attach_consumo" {
    for_each = {for sqs, sqs_list in local.sqs_list[*] : sqs => sqs_list}
    user       = values(aws_iam_user.user_consumo)[each.key].name
    policy_arn = values(aws_iam_policy.politica_consumo)[each.key].arn
}

resource "aws_iam_access_key" "user_consumo_access_key" {
    for_each = {for sqs, sqs_list in local.sqs_list[*] : sqs => sqs_list}
    user       = values(aws_iam_user.user_consumo)[each.key].name
}

#CRIAR POLITICA PRODUTOR DA FILA
resource "aws_iam_policy" "politica_envio" {
    for_each = {for sqs, sqs_list in local.sqs_list[*] : sqs => sqs_list}
    name = "${each.value.name}_${each.value.env}_envio_politica"

    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
        {
            Action = [
            "sqs:SendMessage"
            ]
            Effect   = "Allow"
            Resource = values(aws_sqs_queue.terraform_queue)[each.key].arn
        }
        ]
    })
}

resource "aws_iam_user" "user_envio" {
    for_each = {for sqs, sqs_list in local.sqs_list[*] : sqs => sqs_list}
    name = "${each.value.name}_${each.value.env}_envio_politica"
}

resource "aws_iam_user_policy_attachment" "user_policy_attach_envio" {
    for_each = {for sqs, sqs_list in local.sqs_list[*] : sqs => sqs_list}
    user       = values(aws_iam_user.user_envio)[each.key].name
    policy_arn = values(aws_iam_policy.politica_envio)[each.key].arn
}

resource "aws_iam_access_key" "user_envio_access_key" {
    for_each = {for sqs, sqs_list in local.sqs_list[*] : sqs => sqs_list}
    user       = values(aws_iam_user.user_envio)[each.key].name
}

#CRIAR POLITICA PARA TROUBLESHOOTING TIME DE DESENVOLVIMENTO
resource "aws_iam_policy" "politica_sqs_dev" {
    name = "politica_sqs_dev"

    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
        {
            Action = [
            "sqs:DeleteMessage",
            "sqs:GetQueueUrl",
            "sqs:ListDeadLetterSourceQueues",
            "sqs:ReceiveMessage",
            "sqs:SendMessage",
            "sqs:GetQueueAttributes",
            "sqs:ListQueueTags"
            ]
            Effect   = "Allow"
            Resource = concat(
                    [for queue in aws_sqs_queue.terraform_queue : queue.arn if queue.tags["Environment"] != "prd"],
                    [for queue in aws_sqs_queue.terraform_queue_deadletter : queue.arn if queue.tags["Environment"] != "prd"]
            )
            
        },
        ]
    })
    depends_on = [aws_sqs_queue.terraform_queue, aws_sqs_queue.terraform_queue_deadletter]
}

# #CRIAR POLITICA PARA TROUBLESHOOTING TIME DE ESPECIALISTAS E INFRAESTRUTURA
resource "aws_iam_policy" "politica_sqs_prd" {
    name = "politica_sqs_prd"

    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
        {
            Action = [
            "sqs:GetQueueUrl",
            "sqs:ListDeadLetterSourceQueues",
            "sqs:ReceiveMessage",
            "sqs:SendMessage",
            "sqs:GetQueueAttributes",
            "sqs:ListQueueTags"
            ]
            Effect   = "Allow"
            Resource = concat(
                    [for queue in aws_sqs_queue.terraform_queue : queue.arn if queue.tags["Environment"] == "prd"],
                    [for queue in aws_sqs_queue.terraform_queue_deadletter : queue.arn if queue.tags["Environment"] == "prd"]
            )
        },
        ]
    })
    depends_on = [aws_sqs_queue.terraform_queue, aws_sqs_queue.terraform_queue_deadletter]
}

#CRIAR TOPICO E ALERTAS POR FILA MORTA DE PRD
resource "aws_sns_topic" "topico_sns_dead_letter" {
    name = var.name_topic_alert_dead_letter
}

resource "aws_sns_topic_subscription" "topico_sns_dead_letter_sqs_target" {
    topic_arn = aws_sns_topic.topico_sns_dead_letter.arn
    protocol  = "email"
    endpoint  = var.email_topic_subscription
}

resource "aws_cloudwatch_metric_alarm" "foobar" {
    for_each = {for sqs, sqs_list in aws_sqs_queue.terraform_queue_deadletter : sqs => sqs_list if contains(keys(sqs_list.tags), "Environment") && sqs_list.tags["Environment"] == "prd"}
    namespace           = "AWS/SQS"
    metric_name         = "ApproximateNumberOfMessagesVisible"
    alarm_name          = "alarme_${each.value.name}"
    comparison_operator = "GreaterThanOrEqualToThreshold"
    statistic           = "Sum"
    evaluation_periods  = 1
    period              = 60
    threshold           = 1
    dimensions = {
        QueueName = each.value.name
    }
    alarm_actions = [aws_sns_topic.topico_sns_dead_letter.arn]
    ok_actions    = [aws_sns_topic.topico_sns_dead_letter.arn]
}
