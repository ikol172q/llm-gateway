#!/bin/bash
pkill -f litellm 2>/dev/null
sleep 2
launchctl kickstart -k gui/$(id -u)/com.llmgateway.litellm 2>/dev/null || \
  $HOME/.llm-gateway/.venv/bin/litellm \
    --config $HOME/.llm-gateway/litellm_config.yaml \
    --port 4000 &
