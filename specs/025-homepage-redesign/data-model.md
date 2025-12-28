# Data Model: Homepage Dashboard Redesign

**Feature**: 025-homepage-redesign
**Date**: 2025-12-28

## Overview

This document defines the YAML configuration structure for the redesigned Homepage dashboard. Homepage uses four configuration files stored as Kubernetes ConfigMaps.

## Entity Definitions

### 1. Settings (settings.yaml)

Defines the global theme, layout, and behavior of the dashboard.

```yaml
# Core Settings
title: string              # Dashboard title displayed in header
favicon: string            # URL to favicon image
theme: enum[dark, light]   # Color theme
color: string              # Tailwind color palette name

# Background (optional)
background:
  image: string            # URL to background image
  blur: enum[sm, md, lg]   # Blur intensity
  saturate: number         # 0-100 saturation percentage
  brightness: number       # 0-100 brightness percentage
  opacity: number          # 0-100 opacity percentage

# Card Styling
cardBlur: enum[sm, md, lg] # Frosted glass effect on cards
headerStyle: enum[underlined, boxed, clean, boxedWidgets]

# Layout Configuration
layout:
  "<Category Name>":
    style: enum[row, column]
    columns: number        # 1-6 columns
    icon: string           # MDI icon name (optional)

# Features
showStats: boolean         # Show service statistics
statusStyle: enum[dot, basic]  # Status indicator style
target: enum[_blank, _self]    # Link target

# Quick Launch
quicklaunch:
  searchDescriptions: boolean
  hideInternetSearch: boolean
  hideVisitURL: boolean

# Kubernetes Provider
providers:
  kubernetes:
    mode: enum[cluster, disabled]

# UI Options
disableCollapse: boolean
hideVersion: boolean
useEqualHeights: boolean
```

### 2. Widgets (widgets.yaml)

Defines header-level information widgets displayed at the top of the page.

```yaml
# Resource Widget
- resources:
    backend: enum[kubernetes, resources]
    expanded: boolean
    cpu: boolean
    memory: boolean
    disk: string           # Mount path (e.g., "/data")
    label: string          # Group label

# Kubernetes Widget
- kubernetes:
    cluster:
      show: boolean
      cpu: boolean
      memory: boolean
      showLabel: boolean
      label: string
    nodes:
      show: boolean
      cpu: boolean
      memory: boolean
      showLabel: boolean

# DateTime Widget
- datetime:
    text_size: enum[sm, md, lg, xl, 2xl]
    format:
      timeStyle: enum[short, medium, long]
      dateStyle: enum[short, medium, long]
      hourCycle: enum[h12, h23]

# Search Widget
- search:
    provider: string       # Search provider (google, duckduckgo, etc.)
    focus: boolean         # Auto-focus on page load
    showSearchSuggestions: boolean

# Greeting Widget (optional)
- greeting:
    text_size: enum[sm, md, lg, xl, 2xl]
    text: string           # Custom greeting text
```

### 3. Services (services.yaml)

Defines service cards organized by category.

```yaml
- "<Category Name>":
    - "<Service Name>":
        # Basic Properties
        icon: string           # Icon name (si-*, mdi-*, or URL)
        href: string           # Primary clickable URL
        description: string    # Service description with access info

        # Kubernetes Integration
        namespace: string      # K8s namespace
        app: string            # App label selector

        # Site Monitoring (optional)
        siteMonitor: string    # URL to monitor for uptime

        # Status Display
        statusStyle: enum[dot, basic]

        # Service Widget
        widget:
          type: string         # Widget type (kubernetes, pihole, argocd, etc.)
          url: string          # Widget data URL
          # Type-specific options below

          # For kubernetes type
          cluster: string
          namespace: string
          app: string
          podSelector: string

          # For pihole type
          key: string          # API key (use {{HOMEPAGE_VAR_*}})

          # For argocd type
          username: string
          password: string     # Or use token

          # For traefik type
          # (no additional config needed)

          # For grafana type
          username: string
          password: string

          # For customapi type
          url: string
          mappings:
            - field: string    # JSON path (e.g., data.result[0].value[1])
              label: string
              format: enum[text, number, percent, bytes, duration]
              remap:           # Optional value mapping
                - value: any
                  to: string
```

### 4. Kubernetes (kubernetes.yaml)

Defines Kubernetes cluster integration settings.

```yaml
mode: enum[cluster, disabled]  # Integration mode
showNode: boolean              # Show node information
```

## Relationships

```
┌─────────────────┐     ┌─────────────────┐
│   settings.yaml │     │   widgets.yaml  │
│   (theme/layout)│     │ (header widgets)│
└────────┬────────┘     └────────┬────────┘
         │                       │
         ▼                       ▼
┌────────────────────────────────────────────┐
│              Homepage Dashboard            │
│  ┌──────────────────────────────────────┐  │
│  │         Header Widgets Area          │  │
│  │  [resources] [kubernetes] [datetime] │  │
│  └──────────────────────────────────────┘  │
│  ┌──────────────────────────────────────┐  │
│  │         Services Categories          │  │
│  │  [Critical Infrastructure]           │  │
│  │  [Platform Services]                 │  │
│  │  [Applications]                      │  │
│  │  [Storage & Data]                    │  │
│  │  [Quick Reference]                   │  │
│  └──────────────────────────────────────┘  │
└────────────────────────────────────────────┘
         ▲
         │
┌────────┴────────┐     ┌─────────────────┐
│  services.yaml  │     │ kubernetes.yaml │
│ (service cards) │     │ (K8s discovery) │
└─────────────────┘     └─────────────────┘
```

## Service Card States

```
┌─────────────────────────────────────────┐
│             Service Card                │
│  ┌─────┐                                │
│  │Icon │  Service Name         [Status] │
│  └─────┘                                │
│  Description with access info           │
│  ┌──────────────────────────────────┐   │
│  │         Widget Area              │   │
│  │  (metrics from native widget)    │   │
│  └──────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

**Status States**:
- Green dot: Service running/healthy
- Yellow dot: Service degraded/warning
- Red dot: Service down/error
- Gray dot: Service status unknown

## Validation Rules

### Settings Validation
- `title`: Required, non-empty string
- `theme`: Must be "dark" or "light"
- `color`: Must be valid Tailwind color name
- `layout.columns`: 1-6 range

### Widget Validation
- Resources backend: Must be "kubernetes" for cluster deployment
- Kubernetes widget: At least one of cluster/nodes must have show=true

### Service Validation
- Each service must have `icon` and at least one of `href` or `description`
- Widget type must match available widget types
- Environment variable references must use `{{HOMEPAGE_VAR_*}}` format

## Security Considerations

1. **Credentials in Secrets**: All API keys and passwords must be stored in Kubernetes Secrets, not hardcoded
2. **Environment Variable References**: Use `{{HOMEPAGE_VAR_*}}` pattern for sensitive values
3. **Internal URLs**: Widget URLs should use internal cluster DNS where possible
4. **RBAC**: Service account must have read access to monitored namespaces
