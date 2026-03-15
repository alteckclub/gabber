# Architecture Beads

This document lists the architecture beads created to document the Gabber repository structure.

## Created Beads

### gabber-65h - Repository Structure Overview
Purpose: Document the overall architecture and structure of the Gabber repository.

Key sections:
- High-level directory structure
- Core directories (frontend, engine, services, sdks, tutorials)
- Configuration files (Makefile, docker-compose.yml, flake.nix)
- Key architecture patterns

### gabber-vlq - Engine Service
Purpose: Document the Gabber Engine service architecture.

Key sections:
- Core engine components (graph, node, pad, secret, types)
- AI capability libraries (audio, stt, tts, llm, video)
- Node implementations
- Data directory structure

### gabber-3tq - Frontend Application
Purpose: Document the Gabber Frontend application architecture.

Key sections:
- Next.js app structure
- Component organization
- Technology stack
- Configuration files

### gabber-7zk - Node System
Purpose: Document the Gabber node system architecture.

Key sections:
- Node directory structure
- Core node implementations
- Node concepts (pads, types, composition)

### gabber-fc3 - Services Layer
Purpose: Document the supporting microservices architecture.

Key sections:
- STT services (gabber-stt, kyutai-stt)
- TTS services (kitten-tts)
- Local LLM configuration
- Service orchestration

### gabber-yck - SDKs
Purpose: Document the client SDKs architecture.

Key sections:
- JavaScript/TypeScript SDK
- Python SDK
- React SDK
- Upcoming SDKs (Unity, iOS, Android, etc.)

### gabber-s71 - MCP Integration
Purpose: Document the Model Context Protocol (MCP) integration.

Key sections:
- MCP proxy client
- MCP computer use server
- Engine MCP integration

### gabber-k1l - Tutorials and Examples
Purpose: Document the tutorials and examples structure.

Key sections:
- Tutorial organization
- Example applications

### gabber-7xi - Deployment and Configuration
Purpose: Document the deployment and configuration architecture.

Key sections:
- Makefile automation
- Docker Compose orchestration
- Nix package management
- Secret management

## Viewing Beads

```bash
# List all architecture beads
bd list --json

# View specific bead
bd show gabber-65h
bd show gabber-vlq
# etc.
```

## Dependencies

These beads are linked as documentation artifacts and can be referenced by other issues using:
```bash
bd create "New Issue" --deps related-to:gabber-65h
```
