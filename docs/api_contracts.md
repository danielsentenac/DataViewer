# API Contracts

## Contract boundary

The Flutter app should talk to a Tomcat JSON API.

It should not call the legacy Java-serialized `jchv` protocol directly.

The JSON API can internally call:

- the existing channel list servlet
- the existing channel history servlet
- the existing `jchv` servlet for online values

## General rules

- content type: `application/json`
- compression: enable `gzip` for plot endpoints
- timestamps exchanged with the app use UTC milliseconds and ISO local input
- the server echoes resolved GPS values for diagnostics and backend chaining
- all channel names are treated as stable IDs
- all series are assumed to be `1 Hz` unless metadata says otherwise
- time-series payloads should be compact arrays, not per-point JSON objects
- missing raw samples are represented by `null` entries in `values`
- empty downsampling buckets are represented by `null` in both `minValues` and `maxValues`

## 1. Search channels

`GET /api/v1/channels/search`

Query parameters:

- `q`: free text or wildcard pattern
- `category`: optional subsystem filter
- `limit`: optional, default `100`, max `500`
- `offset`: optional, default `0`

Example:

```text
GET /api/v1/channels/search?q=VAC*&category=CRYO&limit=50&offset=0
```

Response:

```json
{
  "items": [
    {
      "name": "V1:VAC-CRYO_P1_PRESSURE",
      "displayName": "Cryo P1 Pressure",
      "unit": "mbar",
      "category": "CRYO",
      "sampleRateHz": 1
    }
  ],
  "total": 1,
  "limit": 50,
  "offset": 0
}
```

## 2. List categories

`GET /api/v1/channels/categories`

Response:

```json
{
  "items": [
    {
      "id": "CRYO",
      "label": "Cryogenics",
      "count": 312
    },
    {
      "id": "VAC",
      "label": "Vacuum",
      "count": 1284
    }
  ]
}
```

## 3. Query plot data

`POST /api/v1/plots/query`

Purpose:

- resolve local start time
- fetch historical data up to now
- downsample if needed
- return the point from which live polling should continue

Request:

```json
{
  "channels": [
    "V1:VAC-CRYO_P1_PRESSURE",
    "V1:VAC-CRYO_P2_PRESSURE"
  ],
  "timeRange": {
    "startLocalIso": "2026-03-12T08:30:00",
    "timeZone": "Europe/Rome"
  },
  "sampling": {
    "targetBuckets": 720,
    "preserveExtrema": true
  }
}
```

Response:

```json
{
  "query": {
    "channelCount": 2,
    "resolvedStartUtcMs": 1773297000000,
    "resolvedStartGps": 1457032218,
    "endUtcMs": 1773300600000
  },
  "series": [
    {
      "channel": "V1:VAC-CRYO_P1_PRESSURE",
      "displayName": "Cryo P1 Pressure",
      "unit": "mbar",
      "samplingMode": "raw",
      "startUtcMs": 1773297000000,
      "stepMs": 1000,
      "values": [1.2e-6, 1.1e-6, null, 1.3e-6]
    }
  ],
  "live": {
    "mode": "poll",
    "recommendedPollMs": 1000,
    "resumeAfterUtcMs": 1773300600000
  }
}
```

Client reconstruction rule:

- timestamp of `values[i]` is `startUtcMs + i * stepMs`
- `null` means that sample is missing or unavailable
- the client should not invent interpolated values unless explicitly asked by the user

## 4. Bucketed historical response

If the requested range is too large, the server should return bucketed extrema instead of raw points.

The contract stays the same except:

- `samplingMode` becomes `minmax_bucket`
- bucket timing is described once per series
- extrema are carried in parallel arrays

Example:

```json
{
  "channel": "V1:VAC-CRYO_P1_PRESSURE",
  "displayName": "Cryo P1 Pressure",
  "unit": "mbar",
  "samplingMode": "minmax_bucket",
  "startUtcMs": 1773297000000,
  "bucketSeconds": 60,
  "minValues": [1.0e-6, 1.1e-6, null],
  "maxValues": [1.4e-6, 1.5e-6, null]
}
```

Client rule:

- render bucketed data for overview ranges
- bucket `i` starts at `startUtcMs + i * bucketSeconds * 1000`
- if both `minValues[i]` and `maxValues[i]` are `null`, that bucket has no usable samples
- when the user zooms into a smaller range, re-issue `POST /api/v1/plots/query` for that visible interval with a larger `targetBuckets`

## 5. Poll live data

`POST /api/v1/plots/live`

Purpose:

- continue the plot after the initial history response
- return only points newer than the last point already held by the client

Request:

```json
{
  "channels": [
    "V1:VAC-CRYO_P1_PRESSURE",
    "V1:VAC-CRYO_P2_PRESSURE"
  ],
  "afterUtcMs": 1773300600000
}
```

Response:

```json
{
  "serverNowUtcMs": 1773300603000,
  "series": [
    {
      "channel": "V1:VAC-CRYO_P1_PRESSURE",
      "startUtcMs": 1773300601000,
      "stepMs": 1000,
      "values": [1.3e-6, 1.2e-6, null]
    }
  ]
}
```

Client rules:

- deduplicate or overwrite by `channel + utcMs`
- treat each live response as a partial tail segment, not a full series replacement
- if a poll returns no new points, keep polling
- if the app misses several seconds, the next poll still catches up because `afterUtcMs` is inclusive of the full gap
- `null` in a live segment means the timestamp exists in the requested interval but no value is available yet

## 6. Error contract

All endpoints should return a consistent JSON error body.

Example:

```json
{
  "error": {
    "code": "CHANNEL_NOT_FOUND",
    "message": "One or more requested channels do not exist.",
    "details": [
      "V1:VAC-CRYO_UNKNOWN"
    ]
  }
}
```

Suggested codes:

- `INVALID_TIME_RANGE`
- `CHANNEL_NOT_FOUND`
- `TOO_MANY_CHANNELS`
- `BACKEND_TIMEOUT`
- `UPSTREAM_UNAVAILABLE`

## 7. Practical server rules for `1 Hz`

Recommended first-pass limits:

- raw mode target: keep roughly below `10,000` samples per series
- default initial `targetBuckets`: `720`
- live polling interval: `1000 ms`
- reject or warn on very large channel selections if the total point count would be unreasonable

Payload guidance:

- avoid object-per-sample payloads
- for raw `1 Hz` data, send one series header plus `values[]`
- for overview ranges, send `minValues[]` and `maxValues[]`
- keep channel metadata outside the sample arrays

Example sizing:

- `1 channel x 1 day` = `86,400` raw points
- `20 channels x 1 day` = `1,728,000` raw points

That is why overview requests should normally be bucketed.
