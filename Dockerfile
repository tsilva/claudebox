FROM node:lts

RUN npm install -g @anthropic-ai/claude-code

WORKDIR /workspace

ENTRYPOINT ["claude", "--dangerously-skip-permissions"]
