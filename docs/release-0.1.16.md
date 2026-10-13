# Vyrax 0.1.16

Adding standalone configs now creates a local subscription for each import.
One config creates a one-server group; links pasted together, base64 lists,
Clash YAML and JSON configs become one group per import. Clipboard and file
imports follow the same path. Reimporting a config creates a separate group
without overwriting previous groups. Duplicate endpoints within one import
are collapsed. Invalid input creates no empty group; partially valid input
imports the valid configs and reports rejected entries.

The add dialog accepts an optional group name. Without a name, a single config
uses its server name and a batch uses a numbered subscription name. New groups
become the selected source through the existing route-switching path. Manual,
fastest and balanced selection stay scoped to that group. A failed live switch
does not commit the new group or alter the previous route.

Local groups appear beside URL subscriptions with their server count and a
saved-on-device label. They can be selected, deleted, copied or shared as QR.
Copy and QR serialize only the group's current connection fields as JSON that
Vyrax can reimport, excluding UI state and other groups. Large groups that do
not fit one QR can still be copied. The clipboard limit now matches the 4 MB
import limit. Local groups do not fetch metadata or offer a network refresh.
URL subscriptions retain their link, metadata and refresh behavior.

Previously imported ungrouped servers migrate to one local subscription,
preserving profile IDs, favorites, latency and the selected server. Existing
orphaned source groups are retained. Migration is idempotent and persists
before startup auto-connect reads its catalog. Missing or stale selections
fall back to an available group. Local records persist without a URL.

## Validation

- Subscription tests passed for single and batch imports, separate groups,
  duplicate isolation, partial/invalid input, legacy migration, idempotence,
  selected-source preservation, reload and group deletion isolation.
- Copy/reimport preserved all connection fields across 20 protocol/transport
  combinations. Shared payloads exclude profile IDs and UI metadata; remote
  subscriptions continue to share their original URLs.
- Existing parser examples retained their expected behavior, including
  rejection of garbage and invalid ports.
- All 25 native routing-pool checks passed with bundled Xray: source isolation,
  manual/fastest/balanced selection, live addition, failure rollback and
  survival of existing TCP flows during subscription switches.
- Computer Use QA used the production Windows window with test-only services,
  an in-memory store and a shadow clipboard. English single-config clipboard
  import, Persian named two-config import, switching to the earlier group,
  local/remote card actions, QR, visible copy feedback and copying/reimporting
  a batch as a new group all worked. No real VPN connection was made by the
  preview; file-picker interaction was not separately exercised.
- Production UI, host and helper builds passed. Installer and executable icon
  resources and requested administrator levels were checked. File hashes are
  in `release/verification-0.1.16.json`.

The installed application, active VPN and saved user profiles were not changed.
The installer was built, not installed. The previous 0.1.15 TUN fix is retained;
the user confirmed it works before requesting this update.
