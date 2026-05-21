#!/usr/bin/env bash
# =============================================================================
# Patitos Corp CIAM Lab — End-to-end deployment
# =============================================================================
# This script:
#   1. Creates the Resource Group
#   2. Deploys the ARM template (App Service + Plan + Key Vault + RBAC)
#   3. Creates an App Registration in your CIAM (Entra External ID) tenant
#   4. Generates a client secret and stores it in Key Vault
#   5. Configures App Service EasyAuth to use the CIAM tenant
#   6. Builds + zip-deploys the .NET 8 app
#   7. (Optional) Uploads branding (banner, square logo, background) via Graph
#
# Required CLIs:  az  |  jq  |  dotnet 8 SDK  |  zip
#
# Docs:
#   * az login                       https://learn.microsoft.com/cli/azure/authenticate-azure-cli
#   * az deployment group create     https://learn.microsoft.com/cli/azure/deployment/group#az-deployment-group-create
#   * az ad app create               https://learn.microsoft.com/cli/azure/ad/app#az-ad-app-create
#   * App Service EasyAuth           https://learn.microsoft.com/azure/app-service/overview-authentication-authorization
#   * Custom OIDC provider           https://learn.microsoft.com/azure/app-service/configure-authentication-provider-openid-connect
#   * Entra External ID (CIAM)       https://learn.microsoft.com/entra/external-id/customers/overview-customers-ciam
#   * Branding API                   https://learn.microsoft.com/graph/api/resources/organizationalbranding
# =============================================================================

set -euo pipefail

# --------------------------- CONFIG (override via env) -----------------------
RG_NAME="${RG_NAME:-rg-patitos-ciam-lab}"
LOCATION="${LOCATION:-westeurope}"
APP_NAME="${APP_NAME:-extid-lab-$(LC_ALL=C tr -dc a-z0-9 </dev/urandom | head -c6)}"
SKU="${SKU:-B1}"

# CIAM (Entra External ID) tenant details
CIAM_TENANT_ID="${CIAM_TENANT_ID:?Set CIAM_TENANT_ID, e.g. 938a8e7d-00ed-46bc-8109-161428d9d67c}"
CIAM_DOMAIN="${CIAM_DOMAIN:?Set CIAM_DOMAIN, e.g. patitoscorp.ciamlogin.com}"
APP_REG_DISPLAY="${APP_REG_DISPLAY:-Patitos Corp Lab Web}"

# Subscription tenant (where infra lives) — usually different from CIAM tenant
INFRA_SUBSCRIPTION="${INFRA_SUBSCRIPTION:-$(az account show --query id -o tsv)}"

UPLOAD_BRANDING="${UPLOAD_BRANDING:-true}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INFRA_DIR="$ROOT/infra"
SRC_DIR="$ROOT/src"
BRAND_DIR="$ROOT/branding"
OUT_DIR="$ROOT/.deployment-output"
mkdir -p "$OUT_DIR"

log() { printf "\n\033[1;36m▶ %s\033[0m\n" "$*"; }
ok()  { printf "  \033[1;32m✓ %s\033[0m\n" "$*"; }
warn(){ printf "  \033[1;33m! %s\033[0m\n" "$*"; }

# ---------------------------- 1. PREFLIGHT -----------------------------------
log "Preflight checks"
for c in az jq dotnet zip; do
  command -v "$c" >/dev/null || { echo "Missing CLI: $c"; exit 1; }
done
ok "All required CLIs found"

az account set --subscription "$INFRA_SUBSCRIPTION" >/dev/null
ok "Subscription = $(az account show --query name -o tsv)"

# --------------------------- 2. RESOURCE GROUP -------------------------------
log "Resource group: $RG_NAME ($LOCATION)"
az group create -n "$RG_NAME" -l "$LOCATION" -o none
ok "Group ready"

# --------------------------- 3. APP REGISTRATION (CIAM tenant) ---------------
# We create the app reg BEFORE the ARM deployment, because the ARM template
# needs ciamClientId. We then patch redirect URIs after the app hostname is
# known.
log "Logging in to CIAM tenant ($CIAM_TENANT_ID)"
# This pops a device-code prompt only if a token isn't cached for that tenant.
az account get-access-token --tenant "$CIAM_TENANT_ID" --resource https://graph.microsoft.com >/dev/null 2>&1 \
  || az login --tenant "$CIAM_TENANT_ID" --allow-no-subscriptions --use-device-code -o none

CIAM_TOKEN="$(az account get-access-token --tenant "$CIAM_TENANT_ID" --resource https://graph.microsoft.com --query accessToken -o tsv)"

log "Creating app registration in CIAM tenant"
APP_REG_JSON="$(curl -sS -X POST https://graph.microsoft.com/v1.0/applications \
  -H "Authorization: Bearer $CIAM_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg name "$APP_REG_DISPLAY" '{
        displayName: $name,
        signInAudience: "AzureADMyOrg",
        web: { redirectUris: [], implicitGrantSettings: { enableIdTokenIssuance: false } }
      }')")"

CIAM_CLIENT_ID="$(echo "$APP_REG_JSON" | jq -r .appId)"
CIAM_OBJECT_ID="$(echo "$APP_REG_JSON" | jq -r .id)"
[ "$CIAM_CLIENT_ID" != "null" ] || { echo "App reg failed: $APP_REG_JSON"; exit 1; }
ok "App registration created: $CIAM_CLIENT_ID"

log "Generating client secret (24 month expiry)"
SECRET_JSON="$(curl -sS -X POST "https://graph.microsoft.com/v1.0/applications/$CIAM_OBJECT_ID/addPassword" \
  -H "Authorization: Bearer $CIAM_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"passwordCredential":{"displayName":"deploy-script","endDateTime":"'"$(date -u -d '+24 months' +%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -u -v+24m +%Y-%m-%dT%H:%M:%SZ)"'"}}')"
CIAM_CLIENT_SECRET="$(echo "$SECRET_JSON" | jq -r .secretText)"
[ "$CIAM_CLIENT_SECRET" != "null" ] || { echo "Secret creation failed: $SECRET_JSON"; exit 1; }
ok "Client secret generated"

# --------------------------- 4. ARM DEPLOYMENT -------------------------------
log "Deploying ARM template"
DEPLOY_JSON="$(az deployment group create \
  --resource-group "$RG_NAME" \
  --template-file "$INFRA_DIR/azuredeploy.json" \
  --parameters \
      appName="$APP_NAME" \
      location="$LOCATION" \
      skuName="$SKU" \
      ciamTenantId="$CIAM_TENANT_ID" \
      ciamClientId="$CIAM_CLIENT_ID" \
      ciamDomain="$CIAM_DOMAIN" \
  --query properties.outputs -o json)"

APP_HOST="$(echo "$DEPLOY_JSON" | jq -r .appHostname.value)"
APP_URL="$(echo  "$DEPLOY_JSON" | jq -r .appUrl.value)"
REDIRECT_URI="$(echo "$DEPLOY_JSON" | jq -r .redirectUri.value)"
KV_NAME="$(echo "$DEPLOY_JSON" | jq -r .keyVaultName.value)"
PRINCIPAL_ID="$(echo "$DEPLOY_JSON" | jq -r .principalId.value)"
ok "App URL    : $APP_URL"
ok "Redirect   : $REDIRECT_URI"
ok "Key Vault  : $KV_NAME"

# --------------------------- 5. STORE SECRET IN KEY VAULT --------------------
log "Storing client secret in Key Vault"
# Grant ourselves Secrets Officer (idempotent)
ME="$(az ad signed-in-user show --query id -o tsv)"
KV_ID="$(az keyvault show -n "$KV_NAME" -g "$RG_NAME" --query id -o tsv)"
az role assignment create --assignee-object-id "$ME" --assignee-principal-type User \
  --role "Key Vault Secrets Officer" --scope "$KV_ID" -o none 2>/dev/null || true
sleep 20  # let RBAC propagate
az keyvault secret set --vault-name "$KV_NAME" --name "ExtIdClientSecret" \
  --value "$CIAM_CLIENT_SECRET" -o none
ok "Secret stored: $KV_NAME/ExtIdClientSecret"

# --------------------------- 6. PATCH REDIRECT URI ---------------------------
log "Adding redirect URI to app registration"
curl -sS -X PATCH "https://graph.microsoft.com/v1.0/applications/$CIAM_OBJECT_ID" \
  -H "Authorization: Bearer $CIAM_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg uri "$REDIRECT_URI" '{web:{redirectUris:[$uri]}}')" >/dev/null
ok "Redirect URI registered"

# --------------------------- 7. BUILD + DEPLOY THE APP -----------------------
log "Building .NET 8 app"
PUB_DIR="$OUT_DIR/publish"
ZIP_FILE="$OUT_DIR/app.zip"
rm -rf "$PUB_DIR" "$ZIP_FILE"
dotnet publish "$SRC_DIR/BNFondosLab.csproj" -c Release -o "$PUB_DIR" --nologo >/dev/null
( cd "$PUB_DIR" && zip -r "$ZIP_FILE" . >/dev/null )
ok "Package: $(du -h "$ZIP_FILE" | cut -f1)"

log "Zip-deploying to $APP_NAME"
az webapp deploy -g "$RG_NAME" -n "$APP_NAME" --src-path "$ZIP_FILE" --type zip -o none
ok "Deployed"

# --------------------------- 8. (OPTIONAL) BRANDING --------------------------
if [ "$UPLOAD_BRANDING" = "true" ] && [ -d "$BRAND_DIR" ]; then
  log "Uploading CIAM branding via Microsoft Graph"
  ORG="$CIAM_TENANT_ID"

  # Ensure default localization exists (id=0)
  curl -sS -X POST "https://graph.microsoft.com/v1.0/organization/$ORG/branding/localizations" \
    -H "Authorization: Bearer $CIAM_TOKEN" -H "Content-Type: application/json" \
    -d '{"id":"0","signInPageText":"Bienvenido a Patitos Corp","usernameHintText":"correo@dominio.com","backgroundColor":"#1A1B3A"}' \
    >/dev/null 2>&1 || true

  upload_branding_asset() {
    local file="$1" path="$2" mime="$3"
    [ -f "$file" ] || { warn "skip (missing): $file"; return; }
    curl -sS -X PUT "https://graph.microsoft.com/v1.0/organization/$ORG/branding/localizations/0/$path" \
      -H "Authorization: Bearer $CIAM_TOKEN" \
      -H "Content-Type: $mime" \
      -H "Accept-Language: 0" \
      --data-binary "@$file" -o /dev/null -w "    %{http_code} $path\n"
  }
  upload_branding_asset "$BRAND_DIR/banner.png"     "bannerLogo"      "image/png"
  upload_branding_asset "$BRAND_DIR/square.png"     "squareLogo"      "image/png"
  upload_branding_asset "$BRAND_DIR/square.png"     "squareLogoDark"  "image/png"
  upload_branding_asset "$BRAND_DIR/background.jpg" "backgroundImage" "image/jpeg"
  ok "Branding uploaded"
fi

# --------------------------- 9. SUMMARY --------------------------------------
cat <<EOF | tee "$OUT_DIR/summary.txt"

============================================================
 DEPLOY OK
------------------------------------------------------------
 App URL          : $APP_URL
 Redirect URI     : $REDIRECT_URI
 Resource group   : $RG_NAME
 App Service      : $APP_NAME ($SKU)
 Key Vault        : $KV_NAME
 CIAM tenant      : $CIAM_TENANT_ID
 CIAM domain      : $CIAM_DOMAIN
 App reg (client) : $CIAM_CLIENT_ID
============================================================
EOF
