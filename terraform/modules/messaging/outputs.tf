output "sns_topic_arn" {
  value = aws_sns_topic.domain_events.arn
}

output "order_queue_url" {
  value = aws_sqs_queue.domain["order-events"].url
}

output "stock_queue_url" {
  value = aws_sqs_queue.domain["stock-events"].url
}

output "billing_queue_url" {
  value = aws_sqs_queue.domain["billing-events"].url
}
