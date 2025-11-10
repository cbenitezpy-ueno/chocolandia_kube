# Setup Guide: Cloudflare Zero Trust Tunnel

**Feature**: 004-cloudflare-zerotrust
**Last Updated**: 2025-11-09

This guide walks you through the manual setup steps required before deploying the Cloudflare Tunnel via Terraform.

---

## Prerequisites

- Cloudflare account with chocolandiadc.com domain configured
- Domain DNS managed by Cloudflare
- Google account for OAuth configuration
- kubectl access to K3s cluster
- OpenTofu 1.6+ installed

---

## Step 1: Create Cloudflare API Token

**Purpose**: Terraform needs API access to create tunnels, configure ingress routes, set up Access policies, and manage DNS records.

### Required Permissions

Your API Token must have the following permissions:

| Permission Type | Scope | Access Level |
|----------------|-------|--------------|
| Account | **Zero Trust** | Edit |
| Account | Access: Apps and Policies | Edit |
| Account | Access: Organizations, Identity Providers, and Groups | Edit |
| Zone | DNS | Edit |
| Zone | Zone Settings | Read |

**NOTA IMPORTANTE**: En la interfaz de Cloudflare, "Cloudflare Tunnel" aparece como "**Zero Trust**" en la sección de Account permissions. Son lo mismo.

### Creation Steps

1. **Navigate to API Tokens**:
   - Log in to [Cloudflare Dashboard](https://dash.cloudflare.com/)
   - Click your profile icon (top right) → **My Profile**
   - Navigate to **API Tokens** tab

2. **Create Token**:
   - Click **Create Token**
   - Choose **Create Custom Token** (do NOT use pre-configured templates)

3. **Configure Permissions**:
   - **Token name**: `Terraform - Cloudflare Tunnel Management`
   - **Permissions** (busca exactamente estos nombres):
     - Account → **Zero Trust** → Edit (este es el permiso para Cloudflare Tunnel)
     - Account → Access: Apps and Policies → Edit
     - Account → Access: Organizations, Identity Providers, and Groups → Edit
     - Zone → DNS → Edit
     - Zone → Zone Settings → Read
   - **Account Resources**: Select your Cloudflare account
   - **Zone Resources**: Select `chocolandiadc.com` zone
   - **Client IP Address Filtering**: (Optional) Restrict to your home IP
   - **TTL**: Start date = now, End date = (leave blank for no expiration or set future date)

4. **Generate and Save Token**:
   - Click **Continue to summary**
   - Review permissions
   - Click **Create Token**
   - **CRITICAL**: Copy the token immediately (format: `abc123def456ghi789...`)
   - Store securely (you won't be able to see it again)

5. **Test Token** (optional):
   ```bash
   curl -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
     -H "Authorization: Bearer YOUR_API_TOKEN" \
     -H "Content-Type: application/json"
   ```

   Expected response: `{"result":{"status":"active"},...}`

---

## Step 2: Retrieve Cloudflare Account ID and Zone ID

**Purpose**: Terraform resources require Account ID (for tunnels/Access) and Zone ID (for DNS).

### Get Account ID

1. Navigate to [Cloudflare Dashboard](https://dash.cloudflare.com/)
2. Select **Accounts** from sidebar (or any domain will show account info)
3. Scroll to **Account ID** in the right sidebar
4. Copy the Account ID (format: `a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6`)

**Alternative via API**:
```bash
curl -X GET "https://api.cloudflare.com/client/v4/accounts" \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/json" | jq -r '.result[0].id'
```

### Get Zone ID

1. Navigate to [Cloudflare Dashboard](https://dash.cloudflare.com/)
2. Select your domain: **chocolandiadc.com**
3. Scroll down to **API** section in the right sidebar
4. Copy the **Zone ID** (format: `z9y8x7w6v5u4t3s2r1q0p9o8n7m6l5k4`)

**Alternative via API**:
```bash
curl -X GET "https://api.cloudflare.com/client/v4/zones?name=chocolandiadc.com" \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/json" | jq -r '.result[0].id'
```

---

## Step 3: Configure Google OAuth Application

**Purpose**: Cloudflare Access uses Google OAuth for user authentication.

### Google Cloud Console Setup

1. **Navigate to Google Cloud Console**:
   - Go to [https://console.cloud.google.com/](https://console.cloud.google.com/)
   - Create a new project or select existing: `chocolandia-homelab-access`

2. **Configure OAuth Consent Screen** (PRIMERO esto, antes de crear el Client ID):
   - Navigate to **APIs & Services** → **OAuth consent screen**
   - **User Type**: Select **External** (allows any Gmail account)
   - Click **Create**
   - **Página 1 - App information**:
     - **App name**: `Chocolandia Homelab Services`
     - **User support email**: `cbenitez@gmail.com` (tu email)
     - **App logo**: (opcional, puedes dejar vacío)
     - **Application home page**: (opcional, puedes dejar vacío)
     - **Application privacy policy link**: (opcional, puedes dejar vacío)
     - **Application terms of service link**: (opcional, puedes dejar vacío)
     - **Authorized domains**: (opcional, puedes dejar vacío)
     - **Developer contact email**: `cbenitez@gmail.com`
   - Click **Save and Continue**

   - **Página 2 - Scopes**:
     - **NO NECESITAS AGREGAR SCOPES MANUALMENTE**
     - Los scopes básicos (email, profile, openid) se incluyen automáticamente
     - Simplemente click **Save and Continue** (deja esta página vacía)

   - **Página 3 - Test users**:
     - Click **Add Users**
     - Add `cbenitez@gmail.com` y cualquier otro email que quieras autorizar
     - Click **Save and Continue**

   - **Página 4 - Summary**:
     - Review y click **Back to Dashboard**

   - **Publishing status**:
     - Puedes dejar como **Testing** (permite hasta 100 test users)
     - NO necesitas publicar la app para uso personal/homelab

3. **Get Your Cloudflare Team Name** (necesitas esto ANTES de crear el Client ID):
   - Ve a Cloudflare Dashboard → **Zero Trust** → **Settings** → **Custom Pages**
   - En la parte superior verás tu **Team domain**: `<your-team-name>.cloudflareaccess.com`
   - Anota tu team name (ej: `chocolandia`, `homelab`, etc.)
   - Lo necesitarás para los redirect URIs

4. **Create OAuth 2.0 Client ID**:
   - Navigate to **APIs & Services** → **Credentials**
   - Click **Create Credentials** → **OAuth 2.0 Client ID**
   - Si te pide configurar OAuth consent screen primero, regresa al paso 2
   - **Application type**: Select **Web application**
   - **Name**: `Cloudflare Access - Homelab`
   - **Authorized JavaScript origins**:
     - Click **Add URI**
     - Add: `https://<tu-team-name>.cloudflareaccess.com`
     - Ejemplo: `https://chocolandia.cloudflareaccess.com`
   - **Authorized redirect URIs**:
     - Click **Add URI**
     - Add: `https://<tu-team-name>.cloudflareaccess.com/cdn-cgi/access/callback`
     - Ejemplo: `https://chocolandia.cloudflareaccess.com/cdn-cgi/access/callback`
   - Click **Create**
   - **CRÍTICO**: Copia inmediatamente:
     - **Client ID** (formato: `123456789012-abc123def456.apps.googleusercontent.com`)
     - **Client Secret** (formato: `GOCSPX-ABC123DEF456`)
   - Guárdalos en un lugar seguro (los necesitarás en terraform.tfvars)

---

## Step 4: Store Credentials Securely

**WARNING**: The following files contain secrets and MUST NOT be committed to Git.

### Create terraform.tfvars (Local Only)

Create `/Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/terraform.tfvars`:

```hcl
# Cloudflare Configuration
cloudflare_api_token = "YOUR_API_TOKEN_FROM_STEP1"
cloudflare_account_id = "YOUR_ACCOUNT_ID_FROM_STEP2"
cloudflare_zone_id    = "YOUR_ZONE_ID_FROM_STEP2"
domain_name = "chocolandiadc.com"

# Google OAuth Configuration
google_oauth_client_id     = "YOUR_CLIENT_ID_FROM_STEP3"
google_oauth_client_secret = "YOUR_CLIENT_SECRET_FROM_STEP3"

# Authorized email addresses
authorized_emails = [
  "cbenitez@gmail.com",
  # Add additional authorized emails here
]

# Services to expose
ingress_rules = [
  {
    hostname = "pihole.chocolandiadc.com"
    service  = "http://pihole-web.pihole.svc.cluster.local:80"
  },
  {
    hostname = "grafana.chocolandiadc.com"
    service  = "http://grafana.monitoring.svc.cluster.local:3000"
  }
]
```

### Verify .gitignore Coverage

Ensure `/Users/cbenitez/chocolandia_kube/.gitignore` contains:
```
*.tfvars
!*.tfvars.example
```

This prevents accidental commit of secrets while allowing terraform.tfvars.example to be versioned.

---

## Step 5: Verify Prerequisites

Before proceeding to Terraform deployment, verify:

- [X] Cloudflare API Token created with all required permissions
- [X] Cloudflare Account ID and Zone ID retrieved
- [X] Google OAuth application configured with correct redirect URIs
- [X] Google OAuth Client ID and Client Secret obtained
- [X] terraform.tfvars created locally with all credentials
- [X] .gitignore configured to exclude terraform.tfvars
- [X] kubectl access to K3s cluster verified (`kubectl get nodes`)

---

## Next Steps

Proceed to Terraform deployment:
1. Review `terraform.tfvars.example` template
2. Run `tofu init` in `terraform/environments/chocolandiadc-mvp/`
3. Run `tofu plan` to preview changes
4. Run `tofu apply` to deploy infrastructure

---

## Troubleshooting

### API Token Issues

**Error**: `Authentication error (403) - Invalid API Token`
- **Solution**: Verify token permissions match Step 1 requirements
- **Test**: Run token verification curl command from Step 1

**Error**: `Zone not found`
- **Solution**: Ensure Zone ID is correct and token has access to chocolandiadc.com zone

### Google OAuth Issues

**Error**: `redirect_uri_mismatch`
- **Solution**: Verify authorized redirect URI exactly matches Cloudflare's expected format
- **Format**: `https://<team-name>.cloudflareaccess.com/cdn-cgi/access/callback`

**Error**: `Access blocked: This app's request is invalid`
- **Solution**: Ensure OAuth consent screen is configured and app is published (or user is added to test users)

### General Issues

**Can't find Cloudflare team name?**
- Navigate to: Zero Trust → Settings → Custom Pages
- Team domain is shown at the top (e.g., `chocolandia.cloudflareaccess.com`)

---

## Security Notes

- **API Token**: Treat as a password. Rotate periodically (every 90 days recommended)
- **OAuth Secrets**: Store securely. Do not share or commit to version control
- **terraform.tfvars**: Encrypted at rest if repository uses Git-crypt or similar
- **Access Logs**: Review regularly at Zero Trust → Logs → Access

---

**End of Setup Guide**
