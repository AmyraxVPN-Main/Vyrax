# Vyrax website

The public download page is https://amyraxvpn-main.github.io/Vyrax/ .
Its source is in `site/`; it is a static, dependency-free site with bundled
Vazirmatn fonts, Persian/English text, dark/light themes and an illustrative
connection preview. The preview never opens a VPN connection.
The centered night-sky presentation uses original star and mountain SVGs.
Its interactive gallery previews the eight palettes defined by the app, using
synthetic server data.

GitHub Pages uses `.github/workflows/pages.yml` and deploys changes to `site`
on `main`. The existing Amyrax Panel site is a separate project and is unaffected.

The download selector reads GitHub's latest stable release API and uses the
bundled `site/release.json` as a fallback when that API is unavailable. It only
links an installer when the exact matching asset exists. Otherwise it opens the
latest release page. iOS development archives are deliberately absent from the
public installer selector.

For each public release, use the established asset names, include the exact
dependency sources and notices, verify checksums and platform versions, and
update the fallback metadata. Never include signing credentials or user data.

The app code and original site design are MIT, Copyright (c) 2026 Amyrax.
Vazirmatn and flag-icons keep the licenses in `site/assets`.
