variable "replication_group_id" {
  default     = null
  description = "Identifier of the replication group. At most 40 characters, beginning with a letter, containing only lowercase alphanumeric characters and hyphens, and ending with an alphanumeric. If null, a unique identifier is generated."

  validation {
    condition     = var.replication_group_id == null || can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.replication_group_id))
    error_message = "A replication group ID must begin with a letter, contain only lowercase alphanumeric characters and hyphens, and end with an alphanumeric character."
  }

  validation {
    condition     = var.replication_group_id == null || length(var.replication_group_id) <= 40
    error_message = "A replication group ID may be at most 40 characters."
  }
}

variable "description" {
  default     = "Managed by Terraform"
  description = "Description of the replication group. AWS requires a non-empty value, so this defaults to a placeholder rather than null."
}

variable "engine" {
  default     = null
  description = "Cache engine ('valkey', 'redis', or 'memcached'). Valkey is the open-source fork AWS now steers new Redis-compatible workloads toward, and is cheaper per node. If null, AWS's own default applies."
}

variable "engine_version" {
  default     = null
  description = "Engine version (e.g. '7.2'). If null, AWS picks its own current default for the engine."
}

variable "node_type" {
  default     = null
  description = "Instance type of each cache node (e.g. 'cache.t4g.micro', 'cache.r7g.large'). Every node in the group is the same type."
}

variable "num_cache_clusters" {
  default     = null
  description = "Number of nodes in a group without cluster mode — one primary plus the rest as read replicas. Mutually exclusive with num_node_groups and replicas_per_node_group, which configure a cluster-mode group instead. Needs at least 2 for automatic_failover_enabled to be meaningful."
}

variable "num_node_groups" {
  default     = null
  description = "Number of shards in a cluster-mode group, each holding a slice of the keyspace. Pairs with replicas_per_node_group, and is mutually exclusive with num_cache_clusters."
}

variable "replicas_per_node_group" {
  default     = null
  description = "Read replicas per shard in a cluster-mode group, 0 to 5. Only used alongside num_node_groups."

  validation {
    condition     = var.num_cache_clusters == null || (var.num_node_groups == null && var.replicas_per_node_group == null)
    error_message = "num_cache_clusters configures a non-clustered group and cannot be combined with num_node_groups or replicas_per_node_group."
  }
}

variable "automatic_failover_enabled" {
  default     = true
  description = "Whether AWS promotes a read replica to primary automatically when the primary fails. Defaults true, matching this family's direction of enabling availability protections out of the box. Requires at least two nodes, and is mandatory for a cluster-mode group."
}

variable "multi_az_enabled" {
  default     = null
  description = "Whether replicas are placed in a different availability zone from the primary, so a zone failure does not take the whole group. Requires automatic_failover_enabled. If null, AWS's own default (disabled) applies."
}

variable "at_rest_encryption_enabled" {
  default     = true
  description = "Whether data is encrypted at rest. Defaults true — encryption cannot be enabled in place afterward, only by restoring a snapshot into a new group."
}

variable "transit_encryption_enabled" {
  default     = true
  description = "Whether client connections are encrypted with TLS. Defaults true — a cache commonly holds session tokens and personal data, and without this they cross the VPC in plain text. Clients must be configured for TLS to connect once enabled."
}

variable "transit_encryption_mode" {
  default     = null
  description = "How strictly TLS is enforced: 'preferred' (accept both encrypted and plain connections, for migrating clients) or 'required'. Moving an existing group from disabled to required must pass through 'preferred' first. If null, AWS's own default applies."
}

variable "kms_key_id" {
  default     = null
  description = "ARN of the KMS key encrypting data at rest, from terraform-aws-kms-key. Only used when at_rest_encryption_enabled is true. If null, AWS's own managed key is used."
}

variable "auth_token" {
  default     = null
  description = "Password clients present to connect, 16 to 128 printable characters. Stored in Terraform state in plain text — prefer auth_token_wo. Requires transit_encryption_enabled. Mutually exclusive with auth_token_wo."
  sensitive   = true
}

variable "auth_token_wo" {
  default     = null
  description = "Password as a write-only value — sent to AWS during apply but never persisted to Terraform state. Requires auth_token_wo_version and transit_encryption_enabled. Mutually exclusive with auth_token."
  sensitive   = true

  validation {
    condition     = var.auth_token == null || var.auth_token_wo == null
    error_message = "At most one of auth_token or auth_token_wo may be set."
  }
}

variable "auth_token_wo_version" {
  default     = null
  description = "Version counter for auth_token_wo. Increment it to push a changed token; leaving it unchanged leaves the token alone, since Terraform cannot see the write-only value itself to diff it."

  validation {
    condition     = (var.auth_token_wo == null) == (var.auth_token_wo_version == null)
    error_message = "auth_token_wo and auth_token_wo_version must be set together."
  }
}

variable "auth_token_update_strategy" {
  default     = null
  description = "How a token change is applied: 'ROTATE' (accept both old and new during a transition) or 'SET' (replace immediately, dropping clients still using the old one). If null, AWS's own default applies."
}

variable "subnet_group_name" {
  default     = null
  description = "Name of the cache subnet group placing this group in a VPC. Distinct from an RDS subnet group — ElastiCache has its own resource type, which this family does not yet wrap."
}

variable "security_group_ids" {
  default     = null
  description = "IDs of the security groups controlling network access to the group, from terraform-aws-vpc-security-groups."
}

variable "preferred_cache_cluster_azs" {
  default     = null
  description = "Availability zones to place nodes in, in order. Only used for a group without cluster mode. If null, AWS distributes nodes itself."
}

variable "port" {
  default     = null
  description = "Port the cache accepts connections on. If null, the engine's own default applies (6379 for Valkey and Redis, 11211 for Memcached)."
}

variable "network_type" {
  default     = null
  description = "Network protocol the group accepts ('ipv4', 'ipv6', or 'dual_stack'). If null, AWS's own default applies."
}

variable "ip_discovery" {
  default     = null
  description = "Protocol clients use to discover node addresses ('ipv4' or 'ipv6'). Must be consistent with network_type."
}

variable "parameter_group_name" {
  default     = null
  description = "Name of the cache parameter group applying engine configuration. A cluster-mode group requires a parameter group whose family enables cluster mode. If null, AWS's default for the engine applies."
}

variable "snapshot_retention_limit" {
  default     = 7
  description = "Days automatic snapshots are retained, 0 to 35. Defaults to 7 rather than AWS's own default of 0 (no snapshots at all), matching this family's direction of enabling durability protections out of the box. Not supported on every node type — the smallest burstable types reject it."
}

variable "snapshot_window" {
  default     = null
  description = "Daily UTC window snapshots are taken in (e.g. '03:00-05:00'). Must not overlap maintenance_window. If null, AWS assigns one."
}

variable "maintenance_window" {
  default     = null
  description = "Weekly UTC window AWS applies maintenance in (e.g. 'sun:05:00-sun:06:00'). If null, AWS assigns one."
}

variable "final_snapshot_identifier" {
  default     = null
  description = "Name of the snapshot taken when the group is destroyed. If null, no final snapshot is taken and the cached data is gone — acceptable for a genuine cache, and not for anything treated as a datastore."
}

variable "snapshot_name" {
  default     = null
  description = "Name of an existing snapshot to seed this group from, instead of starting empty."
}

variable "snapshot_arns" {
  default     = null
  description = "ARNs of RDB snapshot files in S3 to seed this group from, for migrating a self-managed instance into ElastiCache."
}

variable "notification_topic_arn" {
  default     = null
  description = "ARN of an SNS topic receiving ElastiCache events for this group — failovers, node replacements, snapshot completions. Without one, those events go unnoticed."
}

variable "log_delivery_configurations" {
  default     = []
  description = "Logs streamed off the group. log_type is 'slow-log' (commands exceeding the slow-log threshold) or 'engine-log'. destination_type is 'cloudwatch-logs' (destination is a log group name, see terraform-aws-cloudwatch-log-group) or 'kinesis-firehose' (a delivery stream name). log_format is 'text' or 'json'."
  type = list(object({
    destination      = string
    destination_type = string
    log_type         = string
    log_format       = string
  }))

  validation {
    condition     = alltrue([for l in var.log_delivery_configurations : contains(["slow-log", "engine-log"], l.log_type)])
    error_message = "A log delivery configuration's log_type must be 'slow-log' or 'engine-log'."
  }

  validation {
    condition     = alltrue([for l in var.log_delivery_configurations : contains(["cloudwatch-logs", "kinesis-firehose"], l.destination_type)])
    error_message = "A log delivery configuration's destination_type must be 'cloudwatch-logs' or 'kinesis-firehose'."
  }
}

variable "auto_minor_version_upgrade" {
  default     = null
  description = "Whether AWS applies minor engine version upgrades automatically during the maintenance window. If null, AWS's own default (enabled) applies."
}

variable "apply_immediately" {
  default     = null
  description = "Whether modifications are applied immediately rather than deferred to the next maintenance window. Immediate application can disrupt connections. If null, AWS's own default (defer) applies."
}

variable "data_tiering_enabled" {
  default     = null
  description = "Whether infrequently accessed data moves to local SSD, expanding effective capacity well past memory. Only supported on r6gd node types."
}

variable "user_group_ids" {
  default     = null
  description = "IDs of ElastiCache user groups providing role-based access control, an alternative to a shared auth_token. Requires transit_encryption_enabled."
}

variable "tags" {
  default     = null
  description = "A map of tags to assign to the replication group."
}
