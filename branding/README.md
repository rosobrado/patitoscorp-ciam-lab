# Branding assets

These assets are uploaded by `scripts/deploy.sh` (or `deploy.ps1`) to Microsoft Graph
to brand the CIAM (Entra External ID) sign-in pages.

| File | Use | Format | Max recommended size |
| --- | --- | --- | --- |
| `banner.png` | Top banner on sign-in modal | PNG | 280 × 60 |
| `square.png` | Square logo (light + dark) | PNG | 240 × 240 |
| `background.jpg` | Full-screen background | JPEG | 1920 × 1080, ≤ 300 KB |

Replace these files with your own to re-skin the lab. Keep the dimensions or
sign-in pages may show whitespace or letterboxing.

Docs:
* https://learn.microsoft.com/entra/external-id/customers/how-to-customize-branding-customers
* https://learn.microsoft.com/graph/api/resources/organizationalbrandinglocalization
