#!/bin/bash
launchctl kickstart -k gui/$(id -u)/com.llmgateway.litellm 2>/dev/null || \
  $HOME/.llm-gateway/.venv/bin/litellm \
    --config $HOME/.llm-gateway/litellm_config.yaml \
    --port 4000 &
