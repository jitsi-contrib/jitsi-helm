# Recording and streaming support

This chart includes support for _Jibri_, which allows Jitsi Meet users to record
and stream their meetings. To enable Jibri support, add this section to your
`values.yaml`:

```yaml
jibri:
  ## Enabling Jibri will allow users to record
  ## and/or stream their meetings (e.g. to YouTube).
  enabled: true

  ## Enable single-use mode for Jibri.
  singleUseMode: false

  ## Enable multiple Jibri instances.
  replicaCount: 1

  ## Enable recording service.
  ## Set this to true/false to enable/disable local recordings.
  ## Defaults to enabled (allow local recordings).
  recording: true

  ## Enable livestreaming service.
  ## Set this to true/false to enable/disable live streams.
  ## Defaults to disabled (livestreaming is forbidden).
  livestreaming: true

  ## Enable persistent storage for local recordings.
  ## If disabled, jibri pod will use a transient
  ## emptyDir-backed storage instead.
  persistence:
    enabled: true
    size: 32Gi

  shm:
    ## Set to true to enable "/dev/shm" mount.
    ## May be required by built-in Chromium.
    enabled: true
```

The above example will allow your Jitsi users to make local recordings, as well
as live streams of their meetings.
