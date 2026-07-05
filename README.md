# DevOps Assessment — Terraform + Database Reliability

## Tech Stack

- Terraform
- AWS (Design Only)
- Docker Compose
- PostgreSQL
- GitHub Actions
- Shell Scripting

---

# Project Structure

```bash
devops-assessment/
│
├── infra/
│   ├── modules/
│   │   ├── network/
│   │   ├── ecs/
│   │   └── rds/
│   └── envs/
│       ├── dev/
│       └── prod/
│
├── database/
│   ├── migrations/
│   ├── seed/
│   └── queries/
│
├── scripts/
│   ├── backup.sh
│   └── restore.sh
│
├── .github/workflows/
├── docker-compose.yml
└── README.md
```

---

# Part 1: Terraform Infrastructure

Infrastructure Design:

Internet → ALB → ECS/Fargate → RDS

Includes:
- VPC
- Public Subnets
- Private Subnets
- ECS Cluster
- ECS Service
- RDS PostgreSQL

---

# Part 2: Environments

Two environments supported:

- dev
- prod

Differences:
- resource sizing
- DB config
- backup retention

---

# Terraform Validation

## DEV

```bash
cd infra/envs/dev
terraform init
terraform fmt
terraform validate
terraform plan -var-file=dev.tfvars
```

## PROD

```bash
cd infra/envs/prod
terraform init
terraform fmt
terraform validate
terraform plan -var-file=prod.tfvars
```

---

# Part 3: Database Setup

Start database:

```bash
docker compose up -d
```

Verify:

```bash
docker ps
```

---

# Schema Creation

Tables:
- hotel_bookings
- booking_events

Schema auto-runs from:

database/migrations/init.sql

---

# Seed Data

Load seed data:

```bash
docker exec -i hotel-postgres psql -U postgres -d hotel_db < database/seed/seed.sql
```

Verify:

```sql
SELECT COUNT(*) FROM hotel_bookings;
SELECT COUNT(*) FROM booking_events;
```

Expected:
- 100 hotel bookings
- 50 booking events

---

# Query Optimization

Query:

```sql
SELECT org_id, status, COUNT(*), SUM(amount)
FROM hotel_bookings
WHERE city = 'delhi'
AND created_at >= NOW() - INTERVAL '30 days'
GROUP BY org_id, status;
```

Added index:

```sql
CREATE INDEX idx_hotel_bookings_city_created_status
ON hotel_bookings(city, created_at, status);
```

Reason:
- city used in WHERE
- created_at used in WHERE
- status used in GROUP BY

This improves filtering and aggregation.

---

# Part 4: Backup

Run backup:

```bash
./scripts/backup.sh
```

Example output:

```bash
Backup completed: ./backups/hotel_db_20250706.sql
```

---

# Restore

Run restore:

```bash
./scripts/restore.sh backups/hotel_db_20250706.sql
```

---

# Verify Restore

Run:

```sql
SELECT COUNT(*) FROM hotel_bookings;
SELECT COUNT(*) FROM booking_events;
```

Restore successful if counts match.

---

# Part 5: GitHub Actions

Workflow runs:

- terraform fmt
- terraform init
- terraform validate
- terraform plan

On:
- Pull Requests