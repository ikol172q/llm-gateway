#!/bin/bash
launchctl bootout gui/$(id -u) $HOME/Library/LaunchAgents/com.llmgateway.litellm.plist 2>/dev/null
pkill -f litellm 2>/dev/null
