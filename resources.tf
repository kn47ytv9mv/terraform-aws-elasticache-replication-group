resource "random_uuid" "resource" {}

resource "aws_elasticache_replication_group" "resource" {
  replication_group_id = coalesce(var.replication_group_id, "cache-${substr(random_uuid.resource.id, 0, 34)}")
  description          = var.description

  engine         = var.engine
  engine_version = var.engine_version
  node_type      = var.node_type

  num_cache_clusters      = var.num_cache_clusters
  num_node_groups         = var.num_node_groups
  replicas_per_node_group = var.replicas_per_node_group

  automatic_failover_enabled = var.automatic_failover_enabled
  multi_az_enabled           = var.multi_az_enabled

  at_rest_encryption_enabled = var.at_rest_encryption_enabled
  transit_encryption_enabled = var.transit_encryption_enabled
  transit_encryption_mode    = var.transit_encryption_mode
  kms_key_id                 = var.kms_key_id

  auth_token                 = var.auth_token
  auth_token_wo              = var.auth_token_wo
  auth_token_wo_version      = var.auth_token_wo_version
  auth_token_update_strategy = var.auth_token_update_strategy

  subnet_group_name           = var.subnet_group_name
  security_group_ids          = var.security_group_ids
  preferred_cache_cluster_azs = var.preferred_cache_cluster_azs
  port                        = var.port
  network_type                = var.network_type
  ip_discovery                = var.ip_discovery

  parameter_group_name = var.parameter_group_name

  snapshot_retention_limit  = var.snapshot_retention_limit
  snapshot_window           = var.snapshot_window
  maintenance_window        = var.maintenance_window
  final_snapshot_identifier = var.final_snapshot_identifier
  snapshot_name             = var.snapshot_name
  snapshot_arns             = var.snapshot_arns

  notification_topic_arn     = var.notification_topic_arn
  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  apply_immediately          = var.apply_immediately
  data_tiering_enabled       = var.data_tiering_enabled
  user_group_ids             = var.user_group_ids

  dynamic "log_delivery_configuration" {
    for_each = var.log_delivery_configurations

    content {
      destination      = log_delivery_configuration.value.destination
      destination_type = log_delivery_configuration.value.destination_type
      log_type         = log_delivery_configuration.value.log_type
      log_format       = log_delivery_configuration.value.log_format
    }
  }

  tags = var.tags
}

output "id" {
  description = "The ID of the replication group."
  value       = aws_elasticache_replication_group.resource.id
}

output "replication_group_id" {
  description = "The replication group's identifier. Feed this into terraform-aws-monitoring-baseline's elasticache_replication_groups."
  value       = aws_elasticache_replication_group.resource.replication_group_id
}

output "arn" {
  description = "The ARN of the replication group."
  value       = aws_elasticache_replication_group.resource.arn
}

output "primary_endpoint_address" {
  description = "Endpoint of the primary node, for writes. Empty for a cluster-mode group, which uses configuration_endpoint_address instead."
  value       = aws_elasticache_replication_group.resource.primary_endpoint_address
}

output "reader_endpoint_address" {
  description = "Endpoint load-balancing reads across the group's replicas. Empty for a cluster-mode group."
  value       = aws_elasticache_replication_group.resource.reader_endpoint_address
}

output "configuration_endpoint_address" {
  description = "Endpoint a cluster-mode client connects to for shard discovery. Empty for a group without cluster mode."
  value       = aws_elasticache_replication_group.resource.configuration_endpoint_address
}

output "port" {
  description = "Port the cache accepts connections on."
  value       = aws_elasticache_replication_group.resource.port
}

output "member_clusters" {
  description = "Identifiers of every cache node in the group."
  value       = aws_elasticache_replication_group.resource.member_clusters
}
