# Custom CA certificates

When a Jitsi component reaches one of your own internal services, that service
often has a certificate signed by a private CA. The Jitsi images can trust such
a CA next to the system CAs. Mount the CA certificates at
`/usr/local/share/ca-certificates` and the image does the rest at start.

> **Note:** this needs an image newer than `stable-11248`. An older image
> ignores the mount.

## Create the Secret

Put the CA certificates into a Secret (a ConfigMap works too). One Secret can be
mounted into several components.

```bash
kubectl create secret generic my-ca --from-file=my-ca.crt=./my-ca.crt
```

## Example: the Transcriber and an internal AI service

The Transcriber streams the meeting audio to a speech-to-text service, for
example your own Skynet over `wss://` (see the
[Transcriber and Skynet guide](/docs/guides/transcriber-skynet.md)). If that
service uses a private CA, mount the Secret into the Transcriber:

```yaml
transcriber:
  extraVolumes:
    - name: custom-ca
      secret:
        secretName: my-ca
  extraVolumeMounts:
    - name: custom-ca
      mountPath: /usr/local/share/ca-certificates
      readOnly: true
```

## Other components

The same `extraVolumes` and `extraVolumeMounts` work for `web`, `prosody`,
`jicofo`, `jvb`, `jigasi` and `jibri`. Mount the CA only where it is needed.
Typical uses:

- prosody: an internal JWT key server (`JWT_ASAP_KEYSERVER`) or custom modules
  calling internal HTTPS endpoints
- jicofo: the translation service or the tracing endpoint
- jibri: webhooks
- jvb, jigasi, jibri: the autoscaler
- web: a private ACME server (`LETSENCRYPT_ACME_SERVER`)

## Notes

- File names must end in `.crt`, `.cer` or `.pem`. A file holds one or more PEM
  certificates or a single DER certificate.
- A changed Secret is used after the pod restarts.
- At start the log shows
  `Trusting N custom CA certificate(s) from /usr/local/share/ca-certificates`.
  An invalid file stops the start with a `FATAL ERROR: ...` line.
- A `custom.scripts._config` override replaces the image's config script, so it
  must keep calling `setup-custom-ca || exit 1`.
