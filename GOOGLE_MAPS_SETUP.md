# Google Maps setup (local first)

The route planner now supports the official Google Maps JavaScript SDK, Google Hybrid (satellite imagery with Google's labels), Places Autocomplete (New), and the Routes library. A selected search result keeps its Google place ID; it is not searched again through another provider.

**Pending:** a real key from your Google Cloud project. No key has been generated, no billing has been enabled on your behalf, and no production deployment has been changed.

## 1. Create/select your Google Cloud project

Open [Google Cloud Console](https://console.cloud.google.com/) in your own account. Select a project (for example, FleetRoute) and link an active billing account for the standard key. Review Google's prices and configure quotas and budget alerts before public use. Budget alerts are not a spending cap.

Official guide: [Set up the Maps JavaScript API](https://developers.google.com/maps/documentation/javascript/get-api-key).

## 2. Enable these three APIs in that same project

In **APIs & Services → Library**, enable:

- Maps JavaScript API — native road/hybrid map and labels.
- Places API (New) — suggestions and coordinates for the selected place.
- Routes API — driving route, distance, estimated time and directions.

This implementation does not need the legacy Directions API, the legacy Places API, Geocoding API, a service account or a Map ID.

References: [Places setup](https://developers.google.com/maps/documentation/javascript/places-migration-get-started), [Routes setup](https://developers.google.com/maps/documentation/javascript/routes/start).

## 3. Create and restrict a browser key

In **APIs & Services → Credentials → Create credentials → API key**, create a key. Open its settings:

1. **Application restrictions → Websites (HTTP referrers)**. Add:

   ```text
   http://127.0.0.1:5173/*
   http://localhost:5173/*
   ```

2. **API restrictions → Restrict key**. Select the three enabled APIs above.
3. Save. Allow time for configuration changes to propagate.

Use a separate production key restricted to your exact production domain when you decide to deploy. Do not allow every website or all `*.vercel.app` domains. No production change is needed now.

A browser key is visible in browser requests by design; `.env.local` prevents accidental git commits, not browser visibility. HTTP-referrer and API restrictions are essential. Never use a service-account key or unrestricted server credential in a `VITE_` variable.

Reference: [API security best practices](https://developers.google.com/maps/api-security-best-practices).

## 4. Paste into the local file, not chat

Edit `D:\Transport\client\.env.local`. The settings have already been added; replace the empty value only, leaving existing unrelated settings intact:

```dotenv
VITE_MAP_PROVIDER=google
VITE_GOOGLE_MAPS_API_KEY=YOUR_RESTRICTED_BROWSER_KEY
VITE_GOOGLE_MAPS_LANGUAGE=en
VITE_GOOGLE_MAPS_REGION=IN
```

`en` uses English where available. You can choose `gu` for Gujarati or `hi` for Hindi. Native Google labels depend on language, map zoom, coverage and provider updates; not every label is visible at every zoom. The consumer Google Maps UI is not identical to the embeddable SDK.

Restart the local server if it has not restarted automatically after the environment change:

```powershell
cd D:\Transport\client
npm.cmd run maps:check
npm.cmd run dev -- --host 127.0.0.1 --port 5173 --strictPort
```

If port 5173 is already running this app, use the existing server; do not launch a second copy. If needed, stop that server with Ctrl+C in its terminal before restarting. Open **http://127.0.0.1:5173/** in normal Chrome or Edge (prefer this over an editor's embedded browser).

`maps:check` only checks local configuration presence and never prints the key. It cannot verify Cloud permissions, billing or quotas.

## 5. Verify with your real key

- The map should carry Google's own attribution and a **Google Maps** provider badge.
- **Satellite** should show native Google Hybrid imagery/labels; **Map** switches to road view.
- Search `Jolva, Surat, Gujarat` and `Kadodara, Gujarat`, then choose the intended result by its full address. The exact selected Google place is used for the pin and route.
- Test zoom, pan and **Pin locations**; two chosen endpoints should draw a route with distance and estimated duration.
- Clear/change endpoints while a search is pending; old results must not replace the newer selection.
- Device location is requested only after **Use current location** or **Start navigation**. There is no simulated moving vehicle or automatic GPS permission request.

Travel time currently excludes live traffic. GPS following is not a complete turn-by-turn navigation product: no voice guidance, background navigation or automatic rerouting is claimed.

## Troubleshooting

- **Key is missing:** fill in `client/.env.local`, restart Vite and reload.
- **RefererNotAllowedMapError:** check `http` vs `https`, exact host and port; use the normal browser at the allowed localhost URL.
- **ApiNotActivatedMapError / request denied:** enable the APIs in the project that owns this key and check its API restrictions.
- **BillingNotEnabledMapError:** check that project's billing status.
- **Map works but suggestions fail:** check Places API (New), its restrictions and quota.
- **Suggestions work but route fails:** check Routes API, quota, and whether the endpoints have a drivable connection.
- **Quota error:** inspect usage and quotas; do not repeatedly retry or remove restrictions.

When Google is explicitly selected but unavailable, the app shows the setup error. It does not silently replace Google labels or coordinates with Esri/OSM data. The previous provider remains available only via an explicit `VITE_MAP_PROVIDER=open` setting (or default auto selection without a key).

Before deployment, review your public terms/privacy disclosures for the Google services used. Do not hide provider attribution.
