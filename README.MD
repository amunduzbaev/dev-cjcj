# Featherweight Cangjie

A compiler frontend for a subset of the Cangjie programming language that performs comprehensive static analysis and validation.

## Overview

This project implements the frontend stages of a Cangjie compiler, transforming source code through multiple representations to validate syntax, types, and initialization semantics. Valid programs are pretty-printed for compilation; invalid programs generate detailed, actionable error messages.

## Pipeline Stages

### 1. Scanner

Converts source text into tokens with kind, value, and position information for error reporting.

### 2. Parser

Builds an Abstract Syntax Tree (AST) from tokens using a grammar subset that excludes packages, type aliases, extensions, foreign declarations, annotations, and macros.

### 3. ASG Builder

Transforms the AST into an Abstract Syntax Graph (ASG) where variables are represented as edges rather than nodes, enabling precise variable resolution and scope tracking through environment structures.

### 4. Type Checker

Performs two-pass type inference and validation:

- Validates type declarations form a valid DAG (no cycles)
- Infers types for expressions, considering context and overload resolution
- Handles complex cases like function calls with multiple candidates and conditional branches
- Ensures assignments and operations use compatible types

### 5. Initialization Checker

Verifies proper variable and class initialization:

- Variables are initialized before use
- Immutable variables are not mutated
- Class constructors initialize all members
- Static/global variables respect declaration order
- Constructor functions follow proper calling conventions

## Key Features

- **Incremental grammar implementation**: Developed layer-by-layer for maintainability
- **ASG representation**: Solves variable resolution problems inherent in ASTs
- **Sophisticated type inference**: Handles overloading, subtyping, and contextual type requirements
- **Comprehensive initialization tracking**: Scope-aware analysis with special handling for classes and closures

## Last Updates

- Grammar and compiler extension with adding Interfaces
- Enforcing the typing/inheritance rules regarding Interfaces
- Testing the Type Checking algorithm and rules with added Interfaces
- Improving/Fixing the Type Checker for minor bugs

## Next Steps

- Code refactoring and cleanup
- Grammar extension to cover more language features
- Enhanced error handling across all compilation stages

## Run

- Short guide on how to run the program
- First clone this repo and make sure that Cangjie 1.0.0 and stdx library is installed
- Make sure to put the right target in cjpm.toml, see the cjpm.toml for more details
- Run the following command where TEST_FILE_NAME is the file containing input code

cjpm run --run-args="TEST_FILE_NAME"

