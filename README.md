# terraform-aws-elasticache-replication-group

Terraform module for an ElastiCache replication group — a Valkey,
Redis, or Memcached cache with a primary, read replicas, and automatic
failover.

## Cost

ElastiCache bills per node-hour by node type, so the node count
(`num_cache_clusters`, or `num_node_groups` multiplied out by
`replicas_per_node_group`) is the direct cost multiplier. Snapshot
storage beyond the free allotment and cross-AZ data transfer bill
separately. See AWS's
[ElastiCache pricing](https://aws.amazon.com/elasticache/pricing/) page
for current rates.

## Design

Two mutually exclusive topologies:

- **Without cluster mode** — `num_cache_clusters` sets one primary plus
  replicas, all holding the same data. Clients use
  `primary_endpoint_address` to write and `reader_endpoint_address` to
  read.
- **With cluster mode** — `num_node_groups` shards the keyspace, each
  shard having `replicas_per_node_group` replicas. Clients use
  `configuration_endpoint_address` and must speak the cluster protocol.
  The parameter group's family must enable cluster mode.

Setting `num_cache_clusters` alongside either cluster-mode variable is
rejected at plan time.

### Defaults chosen over AWS's own

- `at_rest_encryption_enabled` and `transit_encryption_enabled` both
  default **true**. A cache commonly holds session tokens and personal
  data; without TLS they cross the VPC in plain text, and at-rest
  encryption cannot be enabled in place afterward. **Clients must be
  configured for TLS** once transit encryption is on — this breaks a
  client that was not expecting it.
- `automatic_failover_enabled` defaults **true**, which requires at
  least two nodes.
- `snapshot_retention_limit` defaults to **7** days rather than AWS's
  own default of 0, which keeps no snapshots at all. Not supported on
  the smallest burstable node types, which reject it.
- `description` defaults to a placeholder because AWS rejects an empty
  one, so the variable cannot simply default to null like every other
  optional input in this family.

Moving an existing group from no transit encryption to `'required'`
must pass through `transit_encryption_mode = 'preferred'` first, which
accepts both encrypted and plain connections while clients migrate.

`final_snapshot_identifier` defaults to null, meaning a destroy
discards the cached data. That is appropriate for a genuine cache and
wrong for anything treated as a datastore — set it in the latter case.

### A provider quirk worth knowing

`at_rest_encryption_enabled` is typed as a **string** by the AWS
provider, while every other boolean-looking attribute on this resource
(`transit_encryption_enabled`, `automatic_failover_enabled`,
`multi_az_enabled`, `data_tiering_enabled`) is a real bool. Passing a
bool works — Terraform coerces it — but a comparison against the
resource's attribute has to be made as a string.

### Deliberately not covered

The cache subnet group is a separate AWS resource this family does not
yet wrap; supply an existing one by name through `subnet_group_name`.
Parameter groups, user groups, and standalone (non-replicated) cache
clusters are likewise out of scope.

## Usage

```hcl
module "cache" {
  source = "kn47ytv9mv/elasticache-replication-group/aws"

  replication_group_id = "sessions"
  description          = "Session cache"

  engine             = "valkey"
  node_type          = "cache.t4g.micro"
  num_cache_clusters = 2

  subnet_group_name  = "production-cache"
  security_group_ids = [module.security_group.id]
}
```

Or directly from this repository, sharded across three node groups:

```hcl
module "cache" {
  source = "github.com/kn47ytv9mv/terraform-aws-elasticache-replication-group"

  replication_group_id = "sessions"
  engine               = "valkey"
  node_type            = "cache.r7g.large"

  num_node_groups         = 3
  replicas_per_node_group = 1
  multi_az_enabled        = true

  subnet_group_name  = "production-cache"
  security_group_ids = ["sg-1111"]
}
```

## Requirements

| Name | Version |
|---|---|
| terraform | >= 1.11 |
| aws | ~> 6.61 |
| random | ~> 3.9 |

## Providers

| Name | Version |
|---|---|
| aws | ~> 6.61 |
| random | ~> 3.9 |

## Inputs

| Name | Description | Default | Required |
|---|---|---|---|
| replication_group_id | Identifier of the group. At most 40 characters, beginning with a letter, lowercase alphanumeric and hyphens, ending alphanumeric. If null, a unique identifier is generated. | `null` | no |
| description | Description of the group. AWS requires a non-empty value. | `"Managed by Terraform"` | no |
| engine | Cache engine (`'valkey'`, `'redis'`, or `'memcached'`). Valkey is cheaper per node. | `null` | no |
| engine_version | Engine version (e.g. `'7.2'`). | `null` | no |
| node_type | Instance type of each node (e.g. `'cache.t4g.micro'`). | `null` | no |
| num_cache_clusters | Nodes in a group without cluster mode. Mutually exclusive with the cluster-mode variables. | `null` | no |
| num_node_groups | Shards in a cluster-mode group. | `null` | no |
| replicas_per_node_group | Read replicas per shard, 0 to 5. | `null` | no |
| automatic_failover_enabled | Whether a replica is promoted automatically when the primary fails. Requires at least two nodes. | `true` | no |
| multi_az_enabled | Whether replicas sit in a different availability zone. Requires `automatic_failover_enabled`. | `null` | no |
| at_rest_encryption_enabled | Whether data is encrypted at rest. Cannot be enabled in place afterward. | `true` | no |
| transit_encryption_enabled | Whether client connections use TLS. Clients must be configured for TLS once enabled. | `true` | no |
| transit_encryption_mode | `'preferred'` or `'required'`. Moving from disabled to required must pass through `'preferred'`. | `null` | no |
| kms_key_id | ARN of the KMS key encrypting data at rest, from `terraform-aws-kms-key`. | `null` | no |
| auth_token | Password clients present, 16 to 128 characters. Stored in state — prefer `auth_token_wo`. | `null` | no |
| auth_token_wo | Password as a write-only value, never persisted to state. Requires `auth_token_wo_version`. | `null` | no |
| auth_token_wo_version | Version counter for `auth_token_wo`. | `null` | no |
| auth_token_update_strategy | How a token change applies: `'ROTATE'` or `'SET'`. | `null` | no |
| subnet_group_name | Name of the cache subnet group placing this group in a VPC. | `null` | no |
| security_group_ids | IDs of the security groups controlling access, from `terraform-aws-vpc-security-groups`. | `null` | no |
| preferred_cache_cluster_azs | Availability zones to place nodes in, in order. Non-clustered groups only. | `null` | no |
| port | Port the cache accepts connections on. | `null` | no |
| network_type | `'ipv4'`, `'ipv6'`, or `'dual_stack'`. | `null` | no |
| ip_discovery | Protocol clients use to discover node addresses. Must match `network_type`. | `null` | no |
| parameter_group_name | Name of the cache parameter group. Cluster mode requires a cluster-mode family. | `null` | no |
| snapshot_retention_limit | Days automatic snapshots are retained, 0 to 35. | `7` | no |
| snapshot_window | Daily UTC snapshot window (e.g. `'03:00-05:00'`). Must not overlap `maintenance_window`. | `null` | no |
| maintenance_window | Weekly UTC maintenance window (e.g. `'sun:05:00-sun:06:00'`). | `null` | no |
| final_snapshot_identifier | Snapshot taken when the group is destroyed. If null, the data is discarded. | `null` | no |
| snapshot_name | Existing snapshot to seed this group from. | `null` | no |
| snapshot_arns | ARNs of RDB files in S3 to seed this group from. | `null` | no |
| notification_topic_arn | SNS topic receiving ElastiCache events for this group. | `null` | no |
| log_delivery_configurations | Logs streamed off the group. `log_type` `'slow-log'`/`'engine-log'`; `destination_type` `'cloudwatch-logs'`/`'kinesis-firehose'`. | `[]` | no |
| auto_minor_version_upgrade | Whether minor upgrades apply automatically during the maintenance window. | `null` | no |
| apply_immediately | Whether modifications apply immediately rather than at the next maintenance window. | `null` | no |
| data_tiering_enabled | Whether infrequent data moves to local SSD. r6gd node types only. | `null` | no |
| user_group_ids | IDs of user groups providing role-based access control. Requires `transit_encryption_enabled`. | `null` | no |
| tags | A map of tags to assign to the replication group. | `null` | no |

## Outputs

| Name | Description |
|---|---|
| id | The ID of the replication group. |
| arn | The ARN of the replication group. |
| primary_endpoint_address | Endpoint of the primary node, for writes. Empty for a cluster-mode group. |
| reader_endpoint_address | Endpoint load-balancing reads across replicas. Empty for a cluster-mode group. |
| configuration_endpoint_address | Endpoint a cluster-mode client connects to. Empty for a group without cluster mode. |
| port | Port the cache accepts connections on. |
| member_clusters | Identifiers of every cache node in the group. |
| replication_group_id | The replication group's identifier. Feed this into terraform-aws-monitoring-baseline's elasticache_replication_groups. |

## License

MIT — see [LICENSE.md](LICENSE.md).
