# Google OAuth Setup for Headlamp OIDC

## Error: redirect_uri_mismatch

If you see this error when trying to sign in with OIDC:
```
Error 400: redirect_uri_mismatch
You can't sign in because Chocolandia Homelab Services sent an invalid request.
```

This means the redirect URI that Headlamp is using is not authorized in your Google OAuth application.

## Solution: Add Redirect URI to Google Cloud Console

### Step 1: Open Google Cloud Console

1. Go to: https://console.cloud.google.com/apis/credentials
2. Sign in with your Google account (cbenitez@gmail.com)

### Step 2: Edit OAuth 2.0 Client

1. Find your OAuth 2.0 Client ID: `134798906093-c3v4k7mgtofkneru6r31sa7rgkupfm2j.apps.googleusercontent.com`
2. Click on the client ID name to edit it
3. Look for the section "Authorized redirect URIs"

### Step 3: Add Headlamp Redirect URI

Add this URI to the "Authorized redirect URIs" list:

```
https://headlamp.chocolandiadc.com/oidc-callback
```

**Important**: The URI must be **exactly** as shown above:
- Must start with `https://`
- Must include the exact domain: `headlamp.chocolandiadc.com`
- Must include the path: `/oidc-callback`
- No trailing slash

### Step 4: Save Changes

1. Click "Save" at the bottom of the page
2. Wait a few seconds for changes to propagate

### Step 5: Test Login Again

1. Open a new incognito/private window
2. Navigate to `https://headlamp.chocolandiadc.com`
3. Authenticate via Cloudflare Access (Google OAuth)
4. Click "Sign in with OIDC" in Headlamp
5. Should now redirect successfully to Google OAuth
6. Authorize Headlamp to access your profile
7. You should be logged in!

## Current Authorized Redirect URIs

Your Google OAuth application should have these URIs:

```
https://chocolandiadc.cloudflareaccess.com/cdn-cgi/access/callback
https://headlamp.chocolandiadc.com/oidc-callback
```

- First URI: Cloudflare Access authentication
- Second URI: Headlamp OIDC authentication

## Troubleshooting

### Still getting redirect_uri_mismatch?

**Check for typos:**
- Verify the URI is exactly: `https://headlamp.chocolandiadc.com/oidc-callback`
- Check for extra spaces or characters
- Ensure no trailing slash (`/` at the end)

**Check Google OAuth client ID:**
- Verify you're editing the correct OAuth client
- Client ID should be: `134798906093-c3v4k7mgtofkneru6r31sa7rgkupfm2j.apps.googleusercontent.com`

**Wait for propagation:**
- Google OAuth changes can take 1-2 minutes to propagate
- Clear browser cache and try again
- Use incognito/private window to avoid cached redirects

### Different error after adding URI?

**"access_denied" error:**
- Your email is not in the authorized list
- Add to `headlamp_authorized_emails` in terraform.tfvars
- Run `tofu apply` to create ClusterRoleBinding

**"Unauthorized" error in Headlamp:**
- Cloudflare Access is working
- OIDC authentication is working
- But RBAC is denying access
- Check ClusterRoleBinding exists: `kubectl get clusterrolebinding | grep oidc`

### OAuth Consent Screen

If you see a warning screen saying "This app isn't verified":

**Option 1: Click "Advanced" → "Go to Chocolandia Homelab Services (unsafe)"**
- This is safe because it's your own OAuth app
- Google shows this warning for all apps not verified by Google
- You control both the app and the data

**Option 2: Add your domain to authorized domains** (Optional, not required for testing):
1. Go to OAuth consent screen in Google Cloud Console
2. Add `chocolandiadc.com` to "Authorized domains"
3. This doesn't remove the warning but makes it clearer it's your domain

## Example Screenshots

### Google Cloud Console - Authorized Redirect URIs

```
Authorized redirect URIs

1. https://chocolandiadc.cloudflareaccess.com/cdn-cgi/access/callback
   [Delete]

2. https://headlamp.chocolandiadc.com/oidc-callback
   [Delete]

[+ ADD URI]
```

### Headlamp Login Screen (After Fix)

After adding the redirect URI, you should see:

1. **Cloudflare Access** → Google OAuth (cbenitez@gmail.com)
2. **Headlamp UI** → "Sign in with OIDC" button
3. **Google OAuth Consent** → "Chocolandia Homelab Services wants to access your Google Account"
4. **Permissions requested**:
   - View your email address
   - View your basic profile info
5. **Click "Continue"**
6. **Redirected to Headlamp** → Logged in successfully!

## Related Documentation

- [Headlamp OIDC Guide](https://headlamp.dev/docs/latest/installation/oidc/)
- [Google OAuth 2.0 Redirect URIs](https://developers.google.com/identity/protocols/oauth2/web-server#redirect-uri_mismatch)
- [OAuth 2.0 Error Codes](https://developers.google.com/identity/protocols/oauth2/web-server#errors)
