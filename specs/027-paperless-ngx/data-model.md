# Data Model: Paperless-ngx Document Management

**Feature**: 027-paperless-ngx
**Date**: 2026-01-01

## Overview

This document describes the data entities managed by Paperless-ngx and the infrastructure resources created by OpenTofu.

## Application Data Model (Paperless-ngx)

Paperless-ngx manages these core entities in PostgreSQL:

### Document

Primary entity representing a digitized document.

| Field | Type | Description |
|-------|------|-------------|
| id | integer | Primary key |
| title | varchar(128) | Document title (auto-generated or manual) |
| content | text | OCR-extracted text content |
| created | timestamp | Document creation date (from metadata or manual) |
| added | timestamp | Date added to Paperless |
| modified | timestamp | Last modification timestamp |
| correspondent_id | integer | FK to Correspondent |
| document_type_id | integer | FK to DocumentType |
| storage_path_id | integer | FK to StoragePath |
| archive_serial_number | integer | Optional ASN for physical filing |
| original_filename | varchar(1024) | Original uploaded filename |
| archived_filename | varchar(1024) | Generated archive filename |
| checksum | varchar(32) | MD5 checksum of original file |
| archive_checksum | varchar(32) | MD5 checksum of archived file |
| mime_type | varchar(256) | MIME type of original file |

**Relationships**:
- Has many Tags (M:N via documents_document_tags)
- Belongs to Correspondent (optional)
- Belongs to DocumentType (optional)
- Has many Notes

### Correspondent

Entity that sent or is associated with documents.

| Field | Type | Description |
|-------|------|-------------|
| id | integer | Primary key |
| name | varchar(128) | Correspondent name (unique) |
| slug | varchar(128) | URL-safe identifier |
| match | varchar(256) | Auto-matching pattern |
| matching_algorithm | integer | Algorithm type (exact, fuzzy, regex, etc.) |
| is_insensitive | boolean | Case-insensitive matching |

### DocumentType

Category classification for documents.

| Field | Type | Description |
|-------|------|-------------|
| id | integer | Primary key |
| name | varchar(128) | Type name (unique) |
| slug | varchar(128) | URL-safe identifier |
| match | varchar(256) | Auto-matching pattern |
| matching_algorithm | integer | Algorithm type |
| is_insensitive | boolean | Case-insensitive matching |

### Tag

User-defined labels for organizing documents.

| Field | Type | Description |
|-------|------|-------------|
| id | integer | Primary key |
| name | varchar(128) | Tag name (unique) |
| slug | varchar(128) | URL-safe identifier |
| color | varchar(7) | Hex color code (#RRGGBB) |
| match | varchar(256) | Auto-matching pattern |
| matching_algorithm | integer | Algorithm type |
| is_insensitive | boolean | Case-insensitive matching |
| is_inbox_tag | boolean | Marks unprocessed documents |

### User (Django Auth)

Authentication and authorization entity.

| Field | Type | Description |
|-------|------|-------------|
| id | integer | Primary key |
| username | varchar(150) | Login username (unique) |
| email | varchar(254) | Email address |
| password | varchar(128) | Hashed password |
| is_staff | boolean | Admin access |
| is_superuser | boolean | Full permissions |
| date_joined | timestamp | Account creation date |

## Infrastructure Data Model (OpenTofu)

### Kubernetes Resources

#### Namespace
```hcl
resource "kubernetes_namespace" "paperless" {
  metadata {
    name = "paperless"
    labels = {
      "app.kubernetes.io/name"       = "paperless-ngx"
      "app.kubernetes.io/managed-by" = "opentofu"
      "feature"                      = "027-paperless-ngx"
    }
  }
}
```

#### PersistentVolumeClaims

| Name | Size | StorageClass | Purpose |
|------|------|--------------|---------|
| paperless-data | 5Gi | local-path | Application data, SQLite index |
| paperless-media | 40Gi | local-path | Original and archived documents |
| paperless-consume | 5Gi | local-path | Incoming documents (shared with Samba) |

#### Secrets

| Name | Keys | Description |
|------|------|-------------|
| paperless-credentials | PAPERLESS_SECRET_KEY, PAPERLESS_DBPASS, PAPERLESS_ADMIN_PASSWORD | Application secrets |
| samba-credentials | SMB_USER, SMB_PASSWORD | Samba authentication |

#### ConfigMaps

| Name | Keys | Description |
|------|------|-------------|
| paperless-env | Non-sensitive environment variables | App configuration |

### PostgreSQL Resources

Created via `postgresql-database` module:

| Resource | Name | Description |
|----------|------|-------------|
| postgresql_role | paperless | Database user |
| postgresql_database | paperless | Application database |
| postgresql_grant | * | Full privileges on database |

### Cloudflare Resources

| Resource | Name | Description |
|----------|------|-------------|
| cloudflare_record | paperless | CNAME to tunnel |
| Tunnel ingress rule | paperless.chocolandiadc.com | Route to K8s service |
| Access application | Paperless | OAuth protection |
| Access policy | Paperless access | Email whitelist |

### Traefik Resources

| Resource | Type | Description |
|----------|------|-------------|
| IngressRoute | paperless-local | Route for .local domain |
| Certificate | paperless-tls | TLS cert from local-ca |

## Entity Relationship Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        PostgreSQL Database                       │
│                         (db: paperless)                          │
└─────────────────────────────────────────────────────────────────┘
         │
         ├──────────────────────────────────────────────────┐
         │                                                  │
         ▼                                                  ▼
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Correspondent │     │   DocumentType  │     │      Tag        │
├─────────────────┤     ├─────────────────┤     ├─────────────────┤
│ id (PK)         │     │ id (PK)         │     │ id (PK)         │
│ name            │     │ name            │     │ name            │
│ slug            │     │ slug            │     │ slug            │
│ match           │     │ match           │     │ color           │
│ matching_algo   │     │ matching_algo   │     │ match           │
└────────┬────────┘     └────────┬────────┘     └────────┬────────┘
         │                       │                       │
         │                       │                       │
         │              ┌────────┴────────┐              │
         │              │                 │              │
         ▼              ▼                 │              ▼
┌───────────────────────────────┐         │    ┌─────────────────────┐
│          Document             │         │    │ documents_document_ │
├───────────────────────────────┤         │    │       tags          │
│ id (PK)                       │         │    ├─────────────────────┤
│ title                         │         │    │ document_id (FK)    │
│ content (text)                │◄────────┘    │ tag_id (FK)         │
│ created                       │              └─────────────────────┘
│ added                         │                        ▲
│ correspondent_id (FK)─────────┤────────────────────────┘
│ document_type_id (FK)─────────┤
│ original_filename             │
│ checksum                      │
└───────────────────────────────┘
         │
         │
         ▼
┌─────────────────┐
│     Note        │
├─────────────────┤
│ id (PK)         │
│ document_id(FK) │
│ note            │
│ created         │
└─────────────────┘
```

## File Storage Layout

```
/usr/src/paperless/
├── data/                    # PVC: paperless-data
│   ├── index/              # Full-text search index (Whoosh)
│   └── log/                # Application logs
│
├── media/                   # PVC: paperless-media
│   ├── documents/
│   │   ├── originals/      # Original uploaded files
│   │   └── archive/        # PDF/A archived versions
│   └── thumbnails/         # Document thumbnails
│
└── consume/                 # PVC: paperless-consume (shared with Samba)
    └── <incoming files>    # Scanner deposits files here
```

## State Transitions

### Document Processing States

```
[Scanner/Upload]
       │
       ▼
┌──────────────┐
│   PENDING    │ ── File in consume folder
└──────┬───────┘
       │ Consumer picks up file
       ▼
┌──────────────┐
│  PROCESSING  │ ── OCR, classification running
└──────┬───────┘
       │ Success
       ▼
┌──────────────┐
│   INDEXED    │ ── Searchable in database
└──────────────┘
       │
       │ If OCR fails
       ▼
┌──────────────┐
│   FAILED     │ ── Requires manual intervention
└──────────────┘
```

## Validation Rules

### Document
- title: max 128 chars, required
- content: text, can be empty (for images without OCR)
- created: valid timestamp, defaults to file modified date
- correspondent_id: must exist if provided
- document_type_id: must exist if provided

### Correspondent / DocumentType / Tag
- name: max 128 chars, unique, required
- slug: auto-generated from name, unique
- match: max 256 chars, optional
- matching_algorithm: 0-6 (none, any, all, literal, regex, fuzzy, auto)

### Samba Share
- Username: alphanumeric, 3-32 chars
- Password: min 8 chars, stored as hash
