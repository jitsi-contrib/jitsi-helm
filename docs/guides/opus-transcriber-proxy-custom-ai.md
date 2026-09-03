# Using a custom AI service with opus-transcriber-proxy

`opusTranscriberProxy` is the bridge-based transcription path. Jicofo tells JVB
which transcription service a conference should use. JVB then streams each
participant's Opus audio to `opus-transcriber-proxy` over a single WebSocket and
the proxy relays it to a speech-to-text provider. With an API key the proxy
talks to OpenAI, Deepgram, Gemini or xAI directly.

This guide covers the other case: sending the audio to your own service through
the proxy's `openai_custom` provider. That provider takes its endpoint and its
credential per connection instead of from the proxy's environment, so most of
the configuration ends up under `jicofo`, not under `opusTranscriberProxy`.

## What your service must implement

`openai_custom` reuses the proxy's OpenAI backend unchanged, so your service has
to speak the OpenAI **Realtime API over WebSocket**. An OpenAI-compatible REST
API (`/v1/chat/completions`, `/v1/audio/transcriptions`) is not enough. Most
self-hosted inference servers ship only the REST side, so confirm this before
configuring anything else.

The Opus audio stops at the proxy: JVB sends Opus, the proxy decodes it and your
service receives a Realtime session opened by the proxy's OpenAI backend. The
credential is presented the way that API expects rather than as an
`Authorization` header.

The proxy uses your `openaiCustomUrl` verbatim, so the path and query are
whatever your service expects. The samples here use
`wss://<host>/v1/realtime?intent=transcription` because that mirrors OpenAI's
own endpoint, where `intent=transcription` selects a transcription session. Drop
it if your service has no use for it. The proxy checks only that the value is a
valid URL and that the scheme is `wss://`, unless `OPENAI_CUSTOM_REQUIRE_WSS` is
`"false"`.

The proxy follows the OpenAI Realtime API, so the session parameters, audio
format and event names are its business and can change between proxy releases.
Read them from the version you deploy, not from here:
[BACKENDS.md](https://github.com/jitsi/opus-transcriber-proxy/blob/main/BACKENDS.md)
and `src/backends/OpenAIBackend.ts` in the
[opus-transcriber-proxy](https://github.com/jitsi/opus-transcriber-proxy) repo.

## Enabling the proxy

```yaml
opusTranscriberProxy:
  enabled: true

# The chart refuses to render if the deprecated Jigasi path is on as well.
transcriber:
  enabled: false

# Without this module the client keeps dialling the Transcriber that no longer
# exists and captions stay silent. The module ships in the Prosody image but
# is not enabled by default.
prosody:
  extraEnvs:
    XMPP_MUC_MODULES: "force_async_transcription"
```

> **Note:** `XMPP_MUC_MODULES` is a comma-separated list that the image adds to
> the MUC component's built-in modules. If you already set it for something
> else, append `force_async_transcription` to your existing value.

## Pointing the proxy at your service

```yaml
opusTranscriberProxy:
  enabled: true
  extraEnvs:
    ENABLE_OPENAI_CUSTOM_PROVIDER: "true"
    # Sent to your service in session.update. The openai_custom provider also
    # reuses OPENAI_TRANSCRIPTION_PROMPT and OPENAI_TURN_DETECTION from the
    # plain openai provider.
    OPENAI_MODEL: "your-model-name"
    # Only if your endpoint is plain ws://, for example a service inside the
    # cluster. The proxy requires wss:// otherwise.
    #OPENAI_CUSTOM_REQUIRE_WSS: "false"
```

`opusTranscriberProxy.apiKeys` stays empty. `openai_custom` needs no
`OPENAI_API_KEY`: the flag above is all that makes the provider available and
the key for your service is supplied per connection as shown below.

## Telling jicofo to use your service

The endpoint is the `openaiCustomUrl` query parameter and the credential is the
`X-Custom-Openai-Api-Key` request header, both read from the WebSocket that JVB
opens. Jicofo builds that request, so both values belong in its config:

```yaml
jicofo:
  custom:
    configs:
      _custom_jicofo_conf: |
        jicofo {
          transcription {
            url-template = "ws://myjitsi-jitsi-meet-opus-transcriber-proxy.jitsi.svc.cluster.local:8080/transcribe?sessionId={{MEETING_ID}}&sendBack=true&provider=openai_custom&openaiCustomUrl=wss%3A%2F%2Fai.example.com%2Fv1%2Frealtime%3Fintent%3Dtranscription"
            http-headers {
              "X-Custom-Openai-Api-Key" = "your-api-key"
            }
          }
        }
```

Four things about that block:

- **Take the base URL from the chart, do not invent it.** When the proxy is
  enabled the chart already writes a `url-template` pointing at the proxy
  Service. Print it and extend it:

  ```bash
  helm template myjitsi jitsi/jitsi-meet -f my-values.yaml | grep url-template
  ```

  What you add to it is `&provider=openai_custom&openaiCustomUrl=...`.

- **`{{MEETING_ID}}` is jicofo's placeholder, not Helm's.** The chart never
  templates `_custom_jicofo_conf`, so write it literally and leave it alone.

- **Percent-encode the `openaiCustomUrl` value.** It survives unencoded only as
  long as it contains no `&`, so an endpoint URL with a second query parameter
  would be cut short without any warning.

- **The repeated `url-template` key is intentional.** The chart writes its own
  first and appends your block after it. HOCON merges the two objects and the
  last assignment wins, so your URL replaces the generated one and your headers
  are added.

> **Note:** `_custom_jicofo_conf` becomes a ConfigMap, so the API key above is
> stored in clear text. Treat the values file and the ConfigMap accordingly.

## Verifying

Render the chart and check that your `url-template` is the last one in
`custom-jicofo.conf`:

```bash
helm template myjitsi jitsi/jitsi-meet -f my-values.yaml | grep -A8 url-template
```

Then start a meeting, turn on subtitles and watch the proxy:

```bash
kubectl logs -l app.kubernetes.io/component=opus-transcriber-proxy -f
```

A working connection logs the requested provider and the target hostname. A
rejected one closes with WebSocket code 1002 and logs which of these four causes
it hit:

- the `http-headers` block is missing or did not reach jicofo, so no API key
  arrived
- your `url-template` did not override the generated one, so no
  `openaiCustomUrl` arrived
- the endpoint is `ws://` while the proxy still requires `wss://`, so
  `OPENAI_CUSTOM_REQUIRE_WSS` needs to be `"false"`
- `ENABLE_OPENAI_CUSTOM_PROVIDER` is not `"true"`, so the provider is not
  available

If the proxy is never contacted at all, the problem is upstream of it: check
that `force_async_transcription` is in the Prosody module list, then see the
[troubleshooting guide](/docs/guides/troubleshooting.md).
