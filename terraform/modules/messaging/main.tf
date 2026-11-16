locals {
  name  = "${var.project_name}-${var.environment}"
  topic = "oficina-domain-events"

  # Mesmos filtros do LocalStack (MessageAttributes.type).
  filters = {
    order-events = [
      "billing.budget.generated",
      "billing.budget.failed",
      "billing.payment.created",
      "billing.payment.confirmed",
      "billing.payment.failed",
      "stock.reservation.failed",
    ]
    stock-events = [
      "billing.budget.generated",
      "order.budget.approved",
      "order.budget.rejected",
      "order.cancelled",
      "billing.payment.confirmed",
      "billing.payment.failed",
    ]
    billing-events = [
      "order.budget.requested",
      "order.budget.approved",
      "order.budget.rejected",
      "order.cancelled",
      "stock.reserved",
      "stock.reservation.failed",
    ]
  }
}

resource "aws_sns_topic" "domain_events" {
  name = local.topic
  tags = merge(var.tags, { Name = "${local.name}-${local.topic}" })
}

resource "aws_sns_topic_policy" "domain_events" {
  arn = aws_sns_topic.domain_events.arn
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowPublishers"
        Effect    = "Allow"
        Principal = { AWS = "*" }
        Action    = "sns:Publish"
        Resource  = aws_sns_topic.domain_events.arn
      },
      {
        Sid       = "AllowQueueSubscriptions"
        Effect    = "Allow"
        Principal = { AWS = "*" }
        Action = [
          "sns:Subscribe",
          "sns:Receive",
          "sns:ListSubscriptionsByTopic",
        ]
        Resource = aws_sns_topic.domain_events.arn
      },
    ]
  })
}

resource "aws_sqs_queue" "domain" {
  for_each = local.filters

  name                       = each.key
  visibility_timeout_seconds = 60
  message_retention_seconds  = 345600
  receive_wait_time_seconds  = 10
  tags                       = merge(var.tags, { Name = "${local.name}-${each.key}" })
}

resource "aws_sqs_queue_policy" "domain" {
  for_each = local.filters

  queue_url = aws_sqs_queue.domain[each.key].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowSnsDelivery"
        Effect    = "Allow"
        Principal = { AWS = "*" }
        Action    = "sqs:SendMessage"
        Resource  = aws_sqs_queue.domain[each.key].arn
        Condition = {
          ArnEquals = { "aws:SourceArn" = aws_sns_topic.domain_events.arn }
        }
      },
      {
        Sid       = "AllowConsumers"
        Effect    = "Allow"
        Principal = { AWS = "*" }
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:ChangeMessageVisibility",
          "sqs:GetQueueUrl",
        ]
        Resource = aws_sqs_queue.domain[each.key].arn
      },
    ]
  })
}

resource "aws_sns_topic_subscription" "domain" {
  for_each = local.filters

  topic_arn            = aws_sns_topic.domain_events.arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.domain[each.key].arn
  raw_message_delivery = false
  filter_policy_scope  = "MessageAttributes"
  filter_policy = jsonencode({
    type = each.value
  })

  depends_on = [aws_sqs_queue_policy.domain]
}
