# Testing OCTO

When OCTO is enabled, the participants of a single meeting are distributed
across multiple JVBs if the number of participants exceeds a threshold.

```
octo:
  enabled: true
```

The default threshold is 80. You can lower this value for a
quick test in a test deployment.

```
jicofo:
  extraEnvs:
    MAX_BRIDGE_PARTICIPANTS: "3"
```

In this case, the participants will be distributed across multiple JVBs if there
are more than 3 participants in the meeting. Join the same meeting using
multiple browser tabs and check the server count which shows the number of JVBs
hosting this meeting. It should be greater than 1.

![OCTO server count](/docs/files/octo-server-count.png)
