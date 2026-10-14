# FLClash integration map

Reference: the user-supplied `D:/FLClash/FlClash-main.zip`, FlClash 0.9.0.
Its Flutter/Riverpod UI and Mihomo core are GPL-3.0. Vyrax's new modules are
independent MIT implementations of observed behavior; no FlClash source, logos,
fonts, or executable files are included in Vyrax packages.

## Architecture

Keep the existing encrypted stores, subscription groups, Firefox free-account
provider, release notifications and native Xray/sing-box engines. The shared UI
has three independent modules: a pure connection reducer, generation-aware
connection actions and an asynchronous latency batch. Native platform hosts
remain authoritative for VPN state and protected sockets. Recreating a WebView
must not disconnect a foreground VPN.

The connection reducer represents idle/connecting/retrying/connected/disconnecting,
derives elapsed time from a session timestamp, preserves it on live switching,
validates telemetry and retains at most 60 traffic samples. Late stats after
disconnect are ignored. The actions controller invalidates cancelled requests,
keeps permission-dialog time budgets and reconciles failed disconnects with the
native host. The latency batch deduplicates rows, bounds resource use to two
workers on mobile and three on desktop, updates results progressively and ignores
cancelled/changed-profile results. These limits reflect Vyrax's per-probe core
processes; copying Mihomo's 32/50 concurrent probes would exhaust mobile resources.

## Feature map

| Reference capability | Vyrax integration |
| --- | --- |
| Connection lifecycle and start/stop | New shared reducer/actions, existing native lifecycle retained |
| URL delay tests | Existing real warmed HTTP probes; new responsive, bounded batch |
| Selector, URLTest, load balance | Existing manual/fastest/balance scoped to selected subscription; dashboard controls and server sheet |
| Profiles/subscriptions | Existing local grouping, remote refresh, copy/QR and provider credentials retained |
| Traffic speed/usage/runtime | New live dashboard cards, SVG chart and session timer |
| Material color and responsive navigation | New graphite/rose dark and warm light palettes; other Vyrax themes retained; desktop rail/mobile dock |
| Rule/Global/Direct, custom rule providers | Requires a separate routing model and per-host core adapter; not exposed as working controls in this phase |
| Mihomo Fallback/Relay and complete Clash YAML groups | Requires a real Mihomo adapter and platform packaging; not represented by Vyrax's fastest mode |
| Live connection termination, DNS history, request/log inspector | Requires native telemetry/actions; not replaced with illustrative data |
| WebDAV backup, profile editor, script overrides | Separate implementation stages; scripts require an isolated execution design |
| Android per-app routing, Quick Settings/TV; desktop shortcuts | Platform-specific stages |
| iOS | Shared UI is portable; installable VPN still needs Apple's signing/entitlements |

## Visual and motion measurements

Dashboard cards use a two-column phone layout, three-column middle layout and
four-column wide grid, with a persistent accessible start button. They use actual
telemetry only. The server picker remains dismissible during tests. The reference
contains multiple customizable themes; the supplied dark preview informed the
graphite and rose palette, while Vyrax's logo, account features and remaining
themes remain available.

Desktop hosts open at 1040×720 (Windows clamps to the monitor working area),
with a maximize/restore control. Linux/macOS keep their existing native resize
support. Narrow windows and phones use the bottom dock. The former 560px phone
shell cap is removed so landscape and tablets use their actual width. Grid rows
size to their content instead of clipping labels. Phone search does not summon
the software keyboard until the input is touched. Search covers name, host and
protocol; keyboard focus returns to its invoker when a sheet closes.

Measurements from reference `start_button.dart`, `outbound_mode.dart` and
`common/constant.dart`: start-button width 200 ms with ease-out-back, icon transition
450 ms, selection 320 ms with ease-in-out-cubic, ordinary page/sheet feedback
300 ms. Web transforms/opacity reproduce these timings without the old dashboard's
large SVG filter. Reduced-motion preferences disable nonessential animations.
Version 0.1.28 replaces the icon crossfade with interpolated polygon geometry.
The play symbol folds and turns into pause bars during the 450ms spring. The
selection background translates as one surface instead of fading each row.
Frame-for-frame equivalence with Flutter has not been established.

The trace uses bounded monotone cubic interpolation without negative-rate
overshoot. Closing the server picker retains its DOM for 320ms to animate out;
reduced-motion preferences remove the delay. A connection generation also guards
pending route-selection responses so cancelling/stopping cannot restore a stale
selection. Windows now consumes the `ready` snapshot even when no native state
event accompanies it.

## Validation

Behavior tests cover cancellation, stale events, duplicate connected events,
live switching, background elapsed time, disconnect failure reconciliation,
bounded telemetry, probe concurrency and cancellation. Browser fixtures use
synthetic example-domain profiles and a simulated bridge, never the user's VPN
or account store. Native routing tests remain separate from presentation tests.

Verified for 0.1.27: 49 Node tests (including 15 new dashboard/connection cases),
44 release checks, subscription import/roundtrip checks, 70 native settings,
25 native routing-pool and 28 real HTTP-delay checks. The Android release build
passes 13 unit tests and vital lint; all five signed APKs pass ABI, signing,
bundled-asset and 16KB-alignment verification. The Windows host/helper and NSIS
installer compile. These checks do not establish real-device rendering or VPN
performance on every platform.

Browser inspection covered Persian/English, dark/light, 360×646, 390×844,
844×390 and 1040×720, cancel, live selection, strategy changes, protocol search,
focus return and sheet dismissal during a delayed probe. Saved images under
`.tools/previews` show synthetic test data, not measurements of a user's VPN.
macOS/Linux installers and an Apple-signed iOS package were not built in this
Windows-hosted phase.
