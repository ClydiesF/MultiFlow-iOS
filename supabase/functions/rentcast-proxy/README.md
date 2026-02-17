# rentcast-proxy Edge Function

Proxies RentCast calls server-side so the RentCast API key is never shipped in the iOS app.

## Endpoints supported

- `markets` -> `/v1/markets` (cost `1`)
- `avm_rent` -> `/v1/avm/rent/long-term` (cost `1`)
- `avm_value` -> `/v1/avm/value` (cost `1`)
- `properties` -> `/v1/properties` (cost `2`)

## Required secrets

Set these in Supabase project secrets:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`
- `RENTCAST_API_KEY`

## Deploy

```bash
supabase functions deploy rentcast-proxy
```

## Call format

GET example:

```text
/functions/v1/rentcast-proxy?endpoint=markets&zipCode=29611
```

POST example:

```json
{
  "endpoint": "properties",
  "params": {
    "address": "53 Harvard Ave, Dorchester, MA 02121"
  }
}
```

The function returns:

- proxied `data`
- `credits` metadata (`cost`, `used`, `remaining`, `quota`)
