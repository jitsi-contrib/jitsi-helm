# Transcription support

This chart supports near real-time transcription (subtitles), performed by the
_Transcriber_ (Jigasi running in transcriber mode). Enabling it is just:

```yaml
transcriber:
  enabled: true
```

The Transcriber streams the meeting audio to a speech-to-text backend, and that
backend is pluggable. This chart has first-class support for
[Skynet](https://github.com/jitsi/skynet), Jitsi's own Whisper backend, which it
can deploy for you (Option 1) or wire to an existing instance (Option 2). You
can also point the Transcriber at any other Jigasi-supported backend yourself
(Option 3). **Skynet is not required.**

> **Deprecated upstream:** the Jigasi-based transcription described here is
> deprecated in Jitsi and will be removed in a future release. The successor is
> a bridge-based transcription architecture. Existing setups keep working; plan
> to migrate once this chart supports the new path. See the
> [upgrading guide](/docs/guides/upgrading.md#deprecations).

> **Note:** when this chart deploys Skynet it enables only the
> `streaming_whisper` module, which does not require Redis. Skynet's
> summaries/assistant modules are out of scope for this chart.

## Option 1: Bundled Skynet (deployed by this chart)

```yaml
transcriber:
  enabled: true

skynet:
  enabled: true
  # useExternalSkynet defaults to false, so a Skynet Deployment + Service is
  # created and the Transcriber is wired to it automatically.
  whisper:
    # Pulled from HuggingFace at runtime. "small" is multilingual and runs on
    # CPU; medium/large-v3 are more accurate but slower.
    model: small
  # Enable this for large models to avoid re-downloading on every pod restart.
  persistence:
    enabled: false
    #size: 10Gi
```

The bundled Skynet runs on CPU, so it works on any cluster. The published Skynet
image is CPU-only; running on a GPU requires building the GPU variant of Skynet
yourself and is out of scope for this chart.

## Option 2: External Skynet (managed outside this chart)

```yaml
transcriber:
  enabled: true

skynet:
  enabled: true
  useExternalSkynet: true
  # Base websocket URL of your Skynet streaming-whisper endpoint.
  # Do NOT include a trailing connection id; jigasi appends it.
  url: "wss://skynet.example.com/streaming-whisper/ws"
```

## Option 3: A different backend

Skynet is optional. Leave it disabled and point the Transcriber at any other
Jigasi-supported backend yourself:

```yaml
transcriber:
  enabled: true
  whisper:
    # Any Whisper-websocket-compatible service (base URL, no trailing id).
    url: "wss://my-whisper.example.com/ws"
    customService: org.jitsi.jigasi.transcription.WhisperTranscriptionService

skynet:
  enabled: false
```

An explicit `transcriber.whisper.*` value always takes precedence, so it also
overrides the auto-wiring when Skynet is enabled. For backends configured
differently (e.g. Google Cloud Speech), set the relevant Jigasi options via
`transcriber.extraEnvs` / `transcriber.extraFiles`.
