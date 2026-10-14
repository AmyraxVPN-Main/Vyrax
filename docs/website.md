# Vyrax website

The public download page is https://amyraxvpn-main.github.io/Vyrax/ .
Its source is in `site/`; it is a static, dependency-free site with bundled
Vazirmatn fonts, Persian/English text, a dark presentation and real screenshots
of the current production app interface.
The layout and Night ridge styling are adapted directly from the downloaded
PromptPad reference supplied by the owner. It uses the reference's photograph
layers, fixed glass header, eased scroll parallax, shooting stars, load reveals,
two-column theme gallery and alternating feature rows. The app preview is
adapted to Vyrax's portrait window without distorting its screenshots.
Its interactive gallery shows screenshots of all eight actual app themes.
All eight images for the active language are preloaded and decoded. The gallery
keeps its previous image until the selected one is ready, gives immediate loading
feedback, offers retry on failure, and ignores stale loads after another selection.
The hero and feature sections show the real connection, server selection,
subscription management, appearance and About screens. Screenshots change
with the selected site language and open at full resolution when clicked.

`site/assets/screenshots/` contains captures of the unmodified production React
UI at its Windows client size (380 × 646), with isolated, in-memory example
data. No owner profiles, subscription secrets, private IPs or native VPN
connections are used. The gallery caption identifies example connection data;
the screenshots are not live connection tests or speed measurements. Refresh
these assets from the current UI when a future release changes its appearance.

GitHub Pages uses `.github/workflows/pages.yml` and deploys changes to `site`
on `main`. The existing Amyrax Panel site is a separate project and is unaffected.

The download selector reads GitHub's latest stable release API and uses the
bundled `site/release.json` as a fallback when that API is unavailable. It only
links an installer when the exact matching asset exists. Otherwise it opens the
latest release page. iOS development archives are deliberately absent from the
public installer selector.
The build menu uses the page's own dark styling with keyboard and pointer support.
Android defaults to the Universal APK; users can select an architecture-specific build.

For each public release, use the established asset names, include the exact
dependency sources and notices, verify checksums and platform versions, and
update the fallback metadata. Never include signing credentials or user data.

The app code and Vyrax-specific site work are MIT, Copyright (c) 2026 Amyrax.
The reference website design and photographs remain third-party material;
see `site/assets/REFERENCE-NOTICE.md` for provenance and source credits.
Vazirmatn and flag-icons keep the licenses in `site/assets`.
