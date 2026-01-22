FROM node:20-slim

RUN npm install -g @anthropic-ai/claude-code

WORKDIR /workspace

ENTRYPOINT ["claude", "--dangerously-skip-permissions"]
