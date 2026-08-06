# Troubleshooting

## Media does not connect (participants cannot see or hear each other)

The meeting loads and people can join, but audio/video between remote
participants fails (it may work only for participants on the same network).

This almost always means JVB is advertising an address the participants cannot
reach. JVB has to announce a publicly reachable IP.

- Make sure you actually configured an exposure method (see the
  [Exposing guide](/docs/guides/exposing.md)).
- Set `jvb.publicIPs` to the address clients can reach, or use
  `jvb.useNodeIP: true`.
- If you rely on STUN to discover the IP, confirm the STUN server is reachable
  and reports the correct public IP. In cloud setups where the ingress IP
  differs from the egress IP, STUN can report the wrong address; set
  `jvb.publicIPs` explicitly instead.
- Check the JVB pod logs for the address it advertises.

## Transcription is enabled but no captions appear

"Start subtitles" is offered in the meeting, but no text shows up.

- Check the transcriber pod logs (it joins the meeting as a hidden participant).
- Check the jicofo logs for a transcriber joining the brewery.
- If using Skynet, confirm the transcriber can reach the Skynet websocket URL
  and that Skynet logs a connection when captions start. On first start Skynet
  downloads the model, which can take a little while.
- Confirm `transcriber.enabled` is set (and `skynet.enabled` too, if you use the
  bundled or external Skynet).

## TURNS works, then breaks after a few weeks or months

TURNS is fine at first, then stops working around the certificate lifetime (for
example, ~90 days with Let's Encrypt).

coTURN does not reload a renewed certificate without a pod restart, so it keeps
serving the old (now expired) one. Install Reloader at the cluster level (the
chart already sets the reload annotation), or otherwise restart the coTURN pods
on renewal. See the [TURNS guide](/docs/guides/turns.md).

## TURN works on some ports but not others

TURN relaying works with the default ports, but fails after you move it to a
custom port - even though the port is reachable with `nc` or `turnutils`.

Chrome only allows a TURN server on port **53, 80, 443, or 1024 and above**. On
any other port it refuses to even open a socket, so nothing reaches coTURN and
the server side stays silent. Firefox uses a different rule, so a port that
fails only in Chrome is a good confirmation.

Open `chrome://webrtc-internals` while joining: the fingerprint is an
`icecandidateerror` with `Attempt to start allocation to a disallowed port`. Use
one of the allowed ports.

## Image pull failures (ImagePullBackOff / ErrImagePull)

Get the exact reason with `kubectl describe pod <pod>` and read the Events:

- `unauthorized` / `toomanyrequests`: a private registry or Docker Hub rate
  limits. Add `imagePullSecrets`, or mirror the image and override the relevant
  `*.image.repository`.
- `no space left on device`: the node ran out of disk unpacking images (common
  on minikube or small nodes). Free up space or grow the node disk.
- `manifest unknown` / `no matching manifest`: a wrong tag, or an image that has
  no build for the node's architecture.
