# Firmware updates

CrossBox checks the latest published stable GitHub Release from
`yhuikzdtguioaert/CrossBox` every six hours. The authenticated Updates page can
request a check immediately. A compatible new version opens a notice after
login and is installed automatically after a ten-minute grace period, with up
to five minutes of scheduler delay. Automatic installation can be switched off
on that page. Installation reboots the router and temporarily interrupts Internet
access. The updater preserves normal sysupgrade settings, CrossBox credentials,
and the automatic-update preference.

Equal versions, older versions, drafts, and prereleases are not installed. The
updater requires the exact AX55 v1 board and target, release asset digests, a
matching `crossbox-update.json`, sufficient temporary storage and available RAM,
verified embedded CrossBox/device/version metadata, and successful
`sysupgrade -T`. It never forces a rejected image or resets configuration.
Downloads use HTTPS with certificate verification and remain in RAM. Update
status is also kept in RAM; one installation-attempt marker is persisted before
flashing to prevent automatic retry loops after a failed reboot. Manual retry is
available. QEMU can check releases and exercise the interface, but its hardware
identity prevents installation of AX55 images.

## Publishing a release

Push source changes, then run **Publish CrossBox firmware** in GitHub Actions
with a new stable `major.minor.patch` version. The workflow stamps the version,
builds the vendored source with pinned feeds, checks image hashes and embedded
metadata, and uploads images plus the update manifest to a draft release. Only
after all uploads finish does it publish the release as latest. Publishing a
stable release makes it eligible for installation on supported routers with
automatic updates enabled. A source push alone does not publish firmware.

The generated manifest binds repository, version, device, board, target, exact
sysupgrade filename, size, and SHA-256. When the REST API is available, the updater also checks the manifest and
firmware against GitHub's asset digests. If GitHub rate-limits the public API,
it fetches the manifest over verified HTTPS from this repository's fixed
latest-release download URL, then downloads the version-pinned image and checks
its size, SHA-256, embedded metadata, and platform compatibility. No GitHub token is needed on the router;
publishing uses the workflow's temporary `GITHUB_TOKEN`. No signing or account
credentials belong in the repository.

This project has not yet completed physical AX55 update/boot testing. A successful
build and isolated upgrade-path tests do not establish recovery, radio behavior,
or throughput on a real router.
