mock_provider "aws" {}

run "invalid_replication_group_id_is_rejected" {
  command = plan

  variables {
    replication_group_id = "0Bad_ID-"
    node_type            = "cache.t4g.micro"
  }

  expect_failures = [var.replication_group_id]
}

run "cluster_mode_and_plain_node_count_are_mutually_exclusive" {
  command = plan

  variables {
    node_type               = "cache.t4g.micro"
    num_cache_clusters      = 2
    num_node_groups         = 2
    replicas_per_node_group = 1
  }

  expect_failures = [var.replicas_per_node_group]
}

run "both_auth_token_forms_are_rejected" {
  command = plan

  variables {
    node_type             = "cache.t4g.micro"
    auth_token            = "correct-horse-battery-staple-1"
    auth_token_wo         = "correct-horse-battery-staple-2"
    auth_token_wo_version = 1
  }

  expect_failures = [var.auth_token_wo]
}

run "auth_token_wo_requires_its_version" {
  command = plan

  variables {
    node_type     = "cache.t4g.micro"
    auth_token_wo = "correct-horse-battery-staple-1"
  }

  expect_failures = [var.auth_token_wo_version]
}

run "invalid_log_type_is_rejected" {
  command = plan

  variables {
    node_type = "cache.t4g.micro"
    log_delivery_configurations = [
      { destination = "/aws/cache", destination_type = "cloudwatch-logs", log_type = "audit-log", log_format = "json" },
    ]
  }

  expect_failures = [var.log_delivery_configurations]
}

run "invalid_destination_type_is_rejected" {
  command = plan

  variables {
    node_type = "cache.t4g.micro"
    log_delivery_configurations = [
      { destination = "/aws/cache", destination_type = "s3", log_type = "slow-log", log_format = "json" },
    ]
  }

  expect_failures = [var.log_delivery_configurations]
}

run "overlong_replication_group_id_is_rejected" {
  command = plan

  variables {
    replication_group_id = "a-very-long-replication-group-identifier-well-past-the-limit"
    node_type            = "cache.t4g.micro"
  }

  expect_failures = [var.replication_group_id]
}

run "replication_group_id_defaults_to_prefixed_random_uuid" {
  command = apply

  variables {
    node_type = "cache.t4g.micro"
  }

  assert {
    condition     = aws_elasticache_replication_group.resource.replication_group_id == "cache-${substr(random_uuid.resource.id, 0, 34)}"
    error_message = "Leaving replication_group_id unset should fall back to a letter-prefixed random_uuid, truncated to fit AWS's 40-character cap."
  }

  assert {
    condition     = length(aws_elasticache_replication_group.resource.replication_group_id) == 40
    error_message = "The generated identifier should land exactly on AWS's 40-character limit, not past it."
  }
}

run "secure_defaults_are_applied" {
  command = plan

  variables {
    node_type = "cache.t4g.micro"
  }

  assert {
    condition     = tostring(aws_elasticache_replication_group.resource.at_rest_encryption_enabled) == "true"
    error_message = "Encryption at rest should be enabled by default, since it cannot be enabled in place afterward. Compared as a string because the provider types this one attribute as a string, unlike every other boolean on the resource."
  }

  assert {
    condition     = aws_elasticache_replication_group.resource.transit_encryption_enabled == true
    error_message = "TLS should be enabled by default, since a cache commonly holds session tokens and personal data."
  }

  assert {
    condition     = aws_elasticache_replication_group.resource.automatic_failover_enabled == true
    error_message = "Automatic failover should be enabled by default."
  }

  assert {
    condition     = aws_elasticache_replication_group.resource.snapshot_retention_limit == 7
    error_message = "Snapshots should be retained for 7 days by default, rather than AWS's own default of none at all."
  }
}

run "description_defaults_to_a_placeholder" {
  command = plan

  variables {
    node_type = "cache.t4g.micro"
  }

  assert {
    condition     = aws_elasticache_replication_group.resource.description == "Managed by Terraform"
    error_message = "AWS requires a non-empty description, so it should default to a placeholder rather than null."
  }
}

run "no_log_delivery_by_default" {
  command = plan

  variables {
    node_type = "cache.t4g.micro"
  }

  assert {
    condition     = length(aws_elasticache_replication_group.resource.log_delivery_configuration) == 0
    error_message = "Leaving log_delivery_configurations unset should emit no log delivery blocks."
  }
}

run "log_delivery_creates_one_block_each" {
  command = plan

  variables {
    node_type = "cache.t4g.micro"
    log_delivery_configurations = [
      { destination = "/aws/cache/slow", destination_type = "cloudwatch-logs", log_type = "slow-log", log_format = "json" },
      { destination = "/aws/cache/engine", destination_type = "cloudwatch-logs", log_type = "engine-log", log_format = "json" },
    ]
  }

  assert {
    condition     = length(aws_elasticache_replication_group.resource.log_delivery_configuration) == 2
    error_message = "Each log_delivery_configurations entry should produce one block."
  }
}

run "readme_default_example" {
  command = plan

  variables {
    replication_group_id = "sessions"
    description          = "Session cache"
    engine               = "valkey"
    node_type            = "cache.t4g.micro"
    num_cache_clusters   = 2
    subnet_group_name    = "production-cache"
    security_group_ids   = ["sg-1111"]
  }
}

run "readme_cluster_mode_example" {
  command = plan

  variables {
    replication_group_id    = "sessions"
    engine                  = "valkey"
    node_type               = "cache.r7g.large"
    num_node_groups         = 3
    replicas_per_node_group = 1
    multi_az_enabled        = true
    subnet_group_name       = "production-cache"
    security_group_ids      = ["sg-1111"]
  }
}
