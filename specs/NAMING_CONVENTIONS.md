# Gabber Spec Naming Conventions

This document establishes consistent naming conventions across all Gabber Allium specifications to improve readability, discoverability, and maintainability.

## Overview

These conventions apply to all `.allium` files in the `specs/` directory.

## Entity Names

### Repository Entities

Repository-specific entities use the `Repository` prefix to distinguish them from core domain entities:

- `RepositoryApp` - An app stored in the repository (wraps core `App` with persistence concerns)
- `RepositorySubGraph` - A subgraph stored in the repository (wraps core `SubGraph` with persistence concerns)

**Rationale**: The `Repository` prefix makes it clear these entities include repository-specific fields (e.g., `created_at`, `updated_at`) and are used for persistence, not pure domain logic.

### Core Entities

Core domain entities use simple, descriptive names without prefixes:

- `App` - The core app domain entity
- `SubGraph` - The core subgraph domain entity
- `Node`, `Pad`, `Graph`, `Connection`, etc.

**Rule**: Use `Repository` prefix only for entities that add persistence/repository-specific concerns to core domain entities.

## Enum Naming

### Enum Type Names

Enum type names use PascalCase and describe the concept:

- `BasePadType` - Types of pads
- `VisemeType` - Types of visemes
- `MessageRole` - Roles in a message
- `Direction` - Direction of data flow

### Enum Literal Values

Enum literals follow a consistent casing convention based on their semantic domain:

#### PascalCase (Default)

Use PascalCase for most enums, especially those representing:
- Types and categories
- Service names
- Configuration options
- General domain concepts

Examples:
```allium
enum BasePadType {
    Trigger
    String
    Integer
    Float
    Boolean
    Object
}

enum MessageRole {
    System
    User
    Assistant
    Tool
}

enum Direction {
    Sink
    Source
}
```

#### UPPERCASE

Use UPPERCASE for:
- Phoneme-based naming (linguistic convention)
- Single-letter values
- Constants that represent fixed, immutable values

Examples:
```allium
enum VisemeType {
    SILENCE          -- No speech / pause
    P                -- Bilabial stop (p)
    B                -- Bilabial stop (b)
    M                -- Bilabial nasal (m)
    O                -- Rounded vowel (o)
    U                -- Rounded vowel (u)
    F                -- Labiodental fricative (f)
    V                -- Labiodental fricative (v)
    T_D_N            -- Alveolar stops/nasal (t, d, n)
    S_Z              -- Alveolar fricatives (s, z)
    TH               -- Dental fricative (th)
    SH               -- Palato-alveolar fricative (sh)
    K_G              -- Velar stops (k, g)
    L                -- Alveolar lateral (l)
    R                -- Alveolar approximant (r)
}
```

**Rationale**: VisemeType uses UPPERCASE because it follows phonetic/linguistic conventions where single-letter phoneme codes are traditionally uppercase.

#### lowercase

Use lowercase for:
- Boolean-like flags
- Mode settings
- Simple on/off or state configurations

Examples:
```allium
enum PadMode {
    property
    stateless
}
```

## Value Types vs Entities

### Pad System

The pad system has two distinct concepts:

1. **`Pad` (entity)** - A runtime pad instance in the engine with state
   - Defined in `core.allium`
   - Represents a pad during graph execution
   - Has fields: `id`, `name`, `type`, `mode`, `direction`

2. **Pad value types** - Compile-time metadata describing pad structure
   - Defined in `nodes.allium`
   - Represent pad definitions for node library
   - Examples: `StatelessSinkPad`, `StatelessSourcePad`, `PropertySinkPad`, `PropertySourcePad`

**Naming Convention**:
- Entity: `Pad` (simple name)
- Value types: `<Mode><Direction>Pad` (e.g., `StatelessSinkPad`, `PropertySourcePad`)

**Rationale**: The value types include both mode (stateless/property) and direction (sink/source) in their names, making them self-describing for node definitions.

## Type Naming Patterns

### Suffix Conventions

- `Type` - Used for enums representing types (e.g., `BasePadType`, `VisemeType`)
- `Kind` - Used for categorization enums (e.g., `RuntimeValueKind`)
- `Mode` - Used for configuration modes (e.g., `PadMode`)
- `Role` - Used for role-based enums (e.g., `MessageRole`)
- `Direction` - Used for directional concepts
- `Service` - Used for service selection enums (e.g., `STTService`, `TTSService`)

### Prefix Conventions

- `Repository` - Repository/persistence-specific entities
- `Domain` - Domain rule result types (e.g., `DomainSaveAppResult`)
- `Proxy` - Proxy nodes for subgraph embedding (e.g., `ProxyPropertySink`)

## Duplicate Type Handling

When the same concept appears in multiple specs:

1. **Define once in `core.allium`** - Core domain types belong in `core.allium`
2. **Reference via `use`** - Other specs import via `use "./core.allium" as core`
3. **Avoid duplication** - If you find duplicate enum definitions, consolidate them

### Consolidated Types (March 2026)

The following types have been consolidated into `core.allium`:
- `Direction`
- `MessageRole`
- `VisemeType`
- `ToolDestination`
- `StateMachineConfiguration`
- `StateMachineState`
- `StateMachineTransition`
- `StateMachineTransitionCondition`

**Status**: ✅ Completed - See [Migration Notes](#migration-notes) for details.

When the same concept appears in multiple specs:

1. **Define once in `core.allium`** - Core domain types belong in `core.allium`
2. **Reference via `use`** - Other specs import via `use "./core.allium" as core`
3. **Avoid duplication** - If you find duplicate enum definitions, consolidate them

Example duplicates to consolidate:
- `Direction` - Defined in both `core.allium` and `nodes.allium`
- `MessageRole` - Defined in both `core.allium` and `nodes.allium`
- `VisemeType` - Defined in both `core.allium` and `nodes.allium`
- `ToolDestination` - Defined in both `core.allium` and `engine.allium`
- `StateMachineConfiguration`, `StateMachineState`, `StateMachineTransition`, `StateMachineTransitionCondition` - Defined in both `core.allium` and `nodes.allium`

**Action Required**: These duplicates should be removed from `nodes.allium` and referenced from `core.allium`.

## Summary Checklist

When adding new types:

- [ ] Entity names: Simple and descriptive (e.g., `App`, `Node`)
- [ ] Repository entities: Use `Repository` prefix (e.g., `RepositoryApp`)
- [ ] Enum type names: PascalCase with descriptive suffix (e.g., `BasePadType`)
- [ ] Enum literals:
  - PascalCase for most enums
  - UPPERCASE for phoneme/linguistic enums (VisemeType)
  - lowercase for boolean/mode enums (PadMode)
- [ ] Value types: Descriptive compound names (e.g., `StatelessSinkPad`)
- [ ] Check for duplicates in `core.allium` before adding new types

## Migration Notes

This document was created to address inconsistencies found in March 2026. The following changes were made:

### Consolidated Duplicate Type Definitions

The following duplicate type definitions were removed to centralize them in `core.allium`:

**From `nodes.allium`:**
- `VisemeType` - Now referenced from `core.allium`
- `MessageRole` - Now referenced from `core.allium`
- `Direction` - Now referenced from `core.allium`
- `StateMachineConfiguration` - Now referenced from `core.allium`
- `StateMachineState` - Now referenced from `core.allium`
- `StateMachineTransition` - Now referenced from `core.allium`
- `StateMachineTransitionCondition` - Now referenced from `core.allium`

**From `engine.allium`:**
- `ToolDestination` - Now referenced from `core.allium`
- `ComparisonOperator` - Note: This is a different enum from `CompareOperator` in `nodes.allium`

### Enum Casing Standardization

The following enum casing conventions are now documented:
- **PascalCase** (default): `BasePadType`, `MessageRole`, `Direction`, `ProxyNodeType`
- **UPPERCASE**: `VisemeType` (phoneme-based naming convention)
- **lowercase**: `PadMode` (boolean-like flags)

Existing code may not fully conform; future changes should align with these conventions.

This document was created to address inconsistencies found in March 2026. Existing code may not fully conform; future changes should align with these conventions.
