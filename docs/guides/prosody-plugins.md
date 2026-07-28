# Adding custom Prosody plugins

In case you want to extend your Jitsi Meet installation with additional Prosody
features, you can add custom plugins using additional ConfigMap mounts like
this:

```yaml
prosody:
  extraVolumes:
    - name: prosody-modules
      configMap:
        name: prosody-modules

  extraVolumeMounts:
    - name: prosody-modules
      subPath: mod_measure_client_presence.lua
      mountPath: /prosody-plugins-custom/mod_measure_client_presence.lua
```

No need to add a module from
[jitsi-contrib/prosody-plugins](https://github.com/jitsi-contrib/prosody-plugins)
manually since they are available in the official `jitsi/prosody` container.
