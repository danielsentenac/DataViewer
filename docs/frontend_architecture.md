# Frontend Architecture

## Goal

Build a mobile app that lets a user:

- search Virgo channels by name, wildcard, or subsystem category
- select one or more channels
- choose a local time start with presets such as `30 min`, `1 h`, `12 h`, and `1 day`
- request historical data from that start up to now
- continue seamlessly with online data
- inspect and rearrange multi-channel plots in a simple two-screen workflow

The system is assumed to work primarily with `1 Hz` data streams.

## Recommended stack

- `Flutter`
- `Dart`
- `Riverpod`
- `go_router`
- `Dio`
- `syncfusion_flutter_charts`

## Product decisions

- Keep exactly two screens: `Selection` and `Plots`.
- Keep time selection in local user time.
- Keep GPS as a backend concern. The backend should resolve local time to GPS and return the resolved GPS value for traceability.
- Use HTTP JSON contracts only.
- Use polling for live continuity in the first version. At `1 Hz`, polling is simpler and sufficient.
- Prefer server-side downsampling for large historical ranges.

## Screen model

### 1. Selection screen

Main responsibilities:

- search channels by free text
- support wildcard search
- filter by subsystem category
- show channel metadata such as display name, unit, and subsystem
- maintain the current selection
- select the time range with:
  - presets: `30 min`, `1 h`, `6 h`, `12 h`, `1 day`, `7 days`
  - custom local date/time picker
- launch the plot query

Primary UI blocks:

- search field
- category chips or a category picker
- result list with add/remove selection state
- selected channel tray
- quick time preset row
- custom start time picker
- `Plot` action button

### 2. Plot screen

Main responsibilities:

- show historical data from the requested start up to current time
- append live points after the history window
- display x-axis in local time
- allow pinch zoom and pan
- allow linear/log y-axis per plot group
- allow grouping and splitting selected channels between plot panels
- let the user return to selection without losing the current query draft

Primary UI blocks:

- top summary bar with selected time range and channel count
- horizontally scrollable channel chips
- one or more stacked plot panels
- panel controls: `linear/log`, `autoscale`, `remove`, `split`, `merge`
- live status indicator

## Plot grouping rules

Default layout should stay simple:

- one selected channel -> one panel
- multiple channels with the same unit -> one shared panel
- mixed units -> separate panels by unit

Manual rearrangement is then allowed on the plot screen. The client owns panel layout state; the backend only returns series data.

## Data flow

### Initial query

1. User searches the catalog.
2. User selects channels and a local start time.
3. App sends the query to the Tomcat JSON API.
4. Backend resolves local time to GPS, fetches history, applies downsampling if needed, and returns the first plot payload.
5. App renders plot panels and starts live polling from the last returned sample.

### Live continuity

1. Plot screen stores the last sample timestamp received per channel.
2. Client polls the live endpoint with `afterUtcMs`.
3. Backend returns only points newer than the last sample.
4. Client appends points, deduplicates by timestamp, and keeps the viewport behavior stable.

Transport rule for plot payloads:

- raw series should come as `startUtcMs + stepMs + values[]`
- missing raw samples should be represented as `null`
- downsampled series should come as `startUtcMs + bucketSeconds + minValues[] + maxValues[]`
- live polling should return only the new tail segment for each channel

Polling is the right starting point here because:

- the cadence is only `1 Hz`
- it is easier to debug on mobile networks
- it is simpler to implement on top of the existing servlet infrastructure

## Performance rules

`1 Hz` is manageable for short windows, but not as raw data for many channels over long durations.

Operational rules:

- raw data is acceptable for short windows and small channel counts
- larger ranges must be downsampled server-side before transfer
- downsampling should preserve extrema using `min/max` buckets
- plot payloads should avoid repeating timestamps and field names per sample
- zooming into a narrower range should trigger a fresh history query for that visible interval

Recommended backend behavior:

- if raw samples per series are below roughly `10,000`, return raw points
- otherwise return bucketed `min/max` data sized to about `2 x screen width`

## Time handling

The mobile UI should work in local time only.

The transport contract should use:

- `startLocalIso`
- `timeZone`
- resolved values echoed back by the server:
  - `resolvedStartUtcMs`
  - `resolvedStartGps`

This avoids putting GPS/leap-second logic in the mobile app.

## State model

Use feature-scoped Riverpod controllers.

Core state objects:

- `ChannelSearchState`
- `ChannelSelectionState`
- `TimeRangeState`
- `PlotQueryState`
- `PlotLayoutState`
- `LiveUpdateState`

## Proposed Flutter structure

```text
lib/
  app/
    app.dart
    router.dart
    theme.dart
  core/
    config/
    errors/
    networking/
    time/
  features/
    channel_selection/
      data/
      domain/
      presentation/
    plot_view/
      data/
      domain/
      presentation/
  shared/
    models/
    widgets/
```

## Repository split

- `ChannelCatalogRepository`
  - search channels
  - load categories

- `PlotRepository`
  - execute initial history query
  - request refreshed history for a visible interval
  - poll live updates

## MVP non-goals

- offline mode
- local persistence of full history traces
- background notifications
- desktop/tablet-specific workflows
- direct access from Flutter to legacy Java serialization

## Open integration items

- exact JSON adapter servlet paths on Tomcat
- authentication model, if any
- authoritative category source for subsystem filters
- maximum practical channel count per plot query
