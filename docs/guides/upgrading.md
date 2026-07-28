# Upgrading

## Chart version vs app version

`Chart.yaml` carries two version fields:

- `version` - the chart's own version, bumped on any chart change.
- `appVersion` - the default image tag used for Jitsi's own components (web,
  prosody, jvb, jicofo, jigasi, jibri) when their `image.tag` is not set.

Third-party components (coturn, etherpad, excalidraw, ...) and Skynet are pinned
to their own `image.tag` in `values.yaml`, independently of `appVersion`.

## Before upgrading

- Review the `values.yaml` differences between your current version and the
  target version - defaults and available options can change between releases.
- Re-check your own overrides against the new defaults.
- Back up any persistent data (PVC-backed volumes, e.g. jibri recordings, or an
  external database if you use one) before a major version bump, in case the new
  app version migrates its on-disk format.

## Performing the upgrade

```bash
helm repo update
helm upgrade myjitsi jitsi/jitsi-meet -f my-values.yaml
```

Or from the OCI registry:

```bash
helm upgrade myjitsi oci://ghcr.io/jitsi-contrib/jitsi-meet -f my-values.yaml
```

A config change rolls the affected pods automatically: the chart adds a checksum
of each component's config to its pod template, so pods restart when their
ConfigMap or Secret changes during the upgrade.

## Deprecations

- Jigasi-based transcription (the path the Transcriber and Skynet use) is
  deprecated upstream and will be removed in a future Jitsi release. The
  successor is a bridge-based transcription architecture. Existing Transcriber
  and Skynet setups keep working for now; plan to migrate once this chart adds
  support for the new path.
