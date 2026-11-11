#!/system/bin/sh
# Keep the module scripts executable regardless of installer defaults.
chmod 0755 "$MODPATH/post-fs-data.sh" "$MODPATH/service.sh" "$MODPATH/customize.sh" 2>/dev/null
