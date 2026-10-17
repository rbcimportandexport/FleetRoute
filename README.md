# FleetRoute

White-and-blue admin UI with a route planner. No database connection or seeded business data is required by the frontend.

## Frontend

```bash
cd client
npm install
npm run dev -- --host 127.0.0.1 --port 5173 --strictPort
```

Production build:

```bash
npm run build
```

Local preview: http://127.0.0.1:5173/

For actual Google road/satellite labels, location suggestions and driving routes, follow [Google Maps setup](GOOGLE_MAPS_SETUP.md). The Google Cloud key and billing setup must be provided by the account owner. Credentials belong in ignored `client/.env.local`, never in source control.

The backend source remains in `server/` for future use. GitHub and Vercel configuration are preserved; local edits do not require pushing or deploying.
