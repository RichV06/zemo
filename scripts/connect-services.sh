#!/bin/bash
# Inicia sesión (OAuth) de los conectores de solo lectura que usa Zemo. Se hace una sola vez.
# Las URL deben coincidir con Sources/AstroCore/AgentProtocol.swift (Connectors.servers).
set -euo pipefail
codex mcp login notion -c 'mcp_servers.notion.url="https://mcp.notion.com/mcp"'
codex mcp login github -c 'mcp_servers.github.url="https://api.githubcopilot.com/mcp/readonly"'
codex mcp list -c 'mcp_servers.notion.url="https://mcp.notion.com/mcp"' -c 'mcp_servers.github.url="https://api.githubcopilot.com/mcp/readonly"' | grep -E '^(Name|notion|github)'
