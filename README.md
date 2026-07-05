# DevOps Assessment: Terraform + Database Reliability

Hotel bookings platform infrastructure-as-code and local database reliability
exercise. Covers Terraform design for `Internet -> ALB -> ECS/Fargate -> RDS`,
a two-environment (`dev`/`prod`) Terraform layout, a CI plan-review workflow,
and a fully working local PostgreSQL setup with seed data, an optimized
reporting query, and backup/restore tooling.

> **Actual AWS deployment is not performed or required.** Terraform is
> validated locally via `fmt`, `init`, and `plan -refresh=false`. Database
> tasks (Part 4-6) run entirely against a local Docker container.

---

## Repository layout

```
infra/
  modules/
    network/   # VPC, public/private subnets, ALB/ECS/RDS security groups
    ecs/       # ALB, target group, ECS cluster, task definition, service
    rds/       # Private RDS instance, subnet group
  envs/
    dev/       # Small instance, short backup retention, deletion_protection=false
    prod/      # Larger instance, long backup retention, deletion_protection=true, Multi-AZ
.github/workflows/terraform.yml   # PR workflow: fmt, init, validate, plan (+ PR comment)
db/
  migrations/  # 001_create_tables.sql, 002_indexes.sql
  seed/        # generate_seed.py + generated seed.sql (160 bookings)
  init/        # docker-entrypoint-initdb.d script that runs migrations + seed on first boot
scripts/
  backup.sh    # timestamped pg_dump (custom format)
  restore.sh   # restores into a fresh database + verifies row counts
docker-compose.yml
```

---

## Part 1-2: Terraform infrastructure

**Topology:** Internet -> ALB (public subnets) -> ECS/Fargate service (private
subnets) -> RDS (private subnets, no public access).

- `modules/network`: VPC with 2 public + 2 private subnets across AZs, an
  Internet Gateway, a single NAT Gateway for private-subnet egress, and three
  security groups:
  - `alb-sg`: allows `80`/`443` from the internet.
  - `ecs-sg`: allows the container port **only** from `alb-sg`.
  - `rds-sg`: allows the DB port **only** from `ecs-sg`. RDS has
    `publicly_accessible = false` and lives only in private subnets, so it is
    unreachable from the internet by construction, not just by security group.
- `modules/ecs`: ALB + target group + listener, ECS cluster (Container
  Insights on), Fargate task definition/service, IAM execution/task roles,
  CloudWatch log group. Container image defaults to public Nginx as a
  placeholder backend.
- `modules/rds`: Single-AZ/Multi-AZ configurable Postgres RDS instance in a
  DB subnet group built from the private subnets.

**Environments** (`infra/envs/dev`, `infra/envs/prod`) each have their own
`variables.tf`, `terraform.tfvars`, and backend configuration, and pass
different sizing/reliability settings into the same modules:

| Setting | dev | prod |
|---|---|---|
| RDS instance class | `db.t4g.micro` | `db.r6g.large` |
| Backup retention | 3 days | 30 days |
| Deletion protection | `false` | `true` |
| Multi-AZ | `false` | `true` |
| ECS task size | 256 CPU / 512 MB | 1024 CPU / 2048 MB |
| Desired task count | 1 | 2 |

Each environment uses a `local` Terraform backend so `terraform init` and
`terraform plan` work out of the box without a real S3 bucket. A
production-style S3 + DynamoDB backend is documented (commented out) in
`backend.tf.example` in each environment folder.

### Validating the Terraform locally

```bash
cd infra/envs/dev        # or infra/envs/prod
terraform fmt -check -recursive ../../..
terraform init
terraform validate
terraform plan -refresh=false
```

`db_password` is a sensitive variable with a placeholder default so `plan`
works without any extra setup; override it via `TF_VAR_db_password` for
anything beyond a syntax/plan review.

---

## Part 3: Terraform plan in GitHub Actions

`.github/workflows/terraform.yml` runs on every pull request that touches
`infra/**`, for both `dev` and `prod` as a matrix:

1. `terraform fmt -check -recursive`
2. `terraform init`
3. `terraform validate`
4. `terraform plan -refresh=false -out=tfplan`

The plan is:
- Uploaded as a **workflow artifact** (`terraform-plan-<env>`), and
- Posted as a **PR comment** (via `actions/github-script`) inside a collapsible
  `<details>` block, along with a pass/fail summary of each step.

Dummy AWS credentials are used so `plan` can run without any real AWS access
or deployment — this is a plan-only review workflow.

---

## Part 4: Local database

`docker-compose.yml` runs a single PostgreSQL 16 service. On **first** start,
Postgres's `docker-entrypoint-initdb.d` hook runs `db/init/00-run-migrations-and-seed.sh`,
which applies the migrations in `db/migrations/` and then the seed data in
`db/seed/`, both in filename order.

```bash
docker compose up -d
docker compose logs -f db   # watch migrations + seed apply on first boot
```

Tables created (`db/migrations/001_create_tables.sql`):

- `hotel_bookings (id, org_id, hotel_id, city, checkin_date, checkout_date, amount, status, created_at)`
- `booking_events (id, booking_id, event_type, payload, created_at)`

---

## Part 5: Seed data and query optimization

`db/seed/generate_seed.py` deterministically generates `db/seed/seed.sql`
(already committed, re-run the script only if you want to regenerate it):

- **160 hotel bookings** (well over the required 100)
- **6 organizations**, **6 cities** (`delhi`, `mumbai`, `bengaluru`, `chennai`,
  `hyderabad`, `pune`)
- **5 statuses** (`confirmed`, `pending`, `cancelled`, `completed`, `refunded`)
- `booking_events` for ~70% of bookings (1-4 events each)
- ~40% of bookings are timestamped within the last 30 days, so the query
  below has meaningful data to aggregate

### The query being optimized

```sql
SELECT org_id, status, COUNT(*), SUM(amount)
FROM hotel_bookings
WHERE city = 'delhi'
  AND created_at >= NOW() - INTERVAL '30 days'
GROUP BY org_id, status;
```

### Index added (`db/migrations/002_indexes.sql`)

```sql
CREATE INDEX idx_hotel_bookings_city_created_at
    ON hotel_bookings (city, created_at)
    INCLUDE (org_id, status, amount);
```

**Why this shape:**

- `city` is filtered with **equality** (`= 'delhi'`), so it's the leading
  index column — Postgres can jump straight to the matching rows.
- `created_at` is filtered with a **range** (`>= NOW() - INTERVAL '30 days'`),
  so it goes second. Together, `(city, created_at)` lets Postgres do one
  contiguous index range scan instead of scanning all `delhi` rows and then
  filtering by date in a second pass.
- `org_id`, `status`, and `amount` are added via **`INCLUDE`** rather than as
  regular key columns, since the query only needs to *read* them (for the
  `GROUP BY` and `SUM`), not filter on them. This makes the index a covering
  index for the query — once table pages are all-visible (tracked by
  Postgres's visibility map), the planner can satisfy the whole query from
  the index alone (an **index-only scan**) without touching the heap.
- `ANALYZE hotel_bookings;` is run right after seeding so the planner's
  statistics reflect the real data distribution immediately, rather than
  waiting for autovacuum.

### Verifying the optimization

```bash
docker compose exec db psql -U app_user -d bookings -c "
EXPLAIN ANALYZE
SELECT org_id, status, COUNT(*), SUM(amount)
FROM hotel_bookings
WHERE city = 'delhi'
  AND created_at >= NOW() - INTERVAL '30 days'
GROUP BY org_id, status;
"
```

Look for `Index Only Scan using idx_hotel_bookings_city_created_at` (or
`Index Scan` if some pages aren't yet marked all-visible) in the plan, instead
of a `Seq Scan on hotel_bookings`.

---

## Part 6: Backup and restore

```bash
./scripts/backup.sh                                     # -> backups/bookings_YYYYMMDD_HHMMSS.dump
./scripts/restore.sh                                     # restores the most recent backup
./scripts/restore.sh backups/bookings_20260101_120000.dump  # or a specific file
```

- **`scripts/backup.sh`** runs `pg_dump` in custom format inside the running
  `db` container and copies the timestamped dump out to `./backups/` on the
  host.
- **`scripts/restore.sh`** does **not** overwrite the live `bookings`
  database. It drops and recreates a separate database
  (`bookings_restore_test` by default, override with `RESTORE_DB_NAME`),
  restores the dump into it with `pg_restore --clean --if-exists`, and then
  runs verification queries.

### How to verify the restore worked

`restore.sh` verifies itself automatically by printing row counts:

```
>> Restore complete. Verifying...
   -> hotel_bookings rows restored: 160
   -> booking_events rows restored: <N>
>> SUCCESS: restore verified, bookings_restore_test contains 160 booking rows.
```

The script exits non-zero if `hotel_bookings` comes back empty. To verify
manually, or spot-check further:

```bash
docker compose exec db psql -U app_user -d bookings_restore_test -c "SELECT COUNT(*) FROM hotel_bookings;"
docker compose exec db psql -U app_user -d bookings_restore_test -c "SELECT city, COUNT(*) FROM hotel_bookings GROUP BY city;"
docker compose exec db psql -U app_user -d bookings_restore_test -c "SELECT COUNT(*) FROM booking_events;"
```

Row counts and per-city distribution should match the source `bookings`
database.

---

## End-to-end local run

```bash
# 1. Start the database (applies migrations + seed on first boot)
docker compose up -d

# 2. Confirm tables + data
docker compose exec db psql -U app_user -d bookings -c "\dt"
docker compose exec db psql -U app_user -d bookings -c "SELECT COUNT(*) FROM hotel_bookings;"

# 3. Back it up
./scripts/backup.sh

# 4. Restore into a fresh database and verify
./scripts/restore.sh

# 5. Terraform (plan-only, no AWS deployment)
cd infra/envs/dev
terraform fmt -check -recursive ../../..
terraform init
terraform validate
terraform plan -refresh=false
```
