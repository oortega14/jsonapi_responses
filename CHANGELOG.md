## [Unreleased]

## [0.2.0] - 2025-10-06

### Added
- **Custom Actions Support**: Support for custom actions beyond standard CRUD (index, show, create, update, destroy)
- **Explicit Action Mapping**: `map_response_action` and `map_response_actions` for mapping custom actions to existing responses
- **Metaprogramming Support**: Dynamic method generation for response handlers
  - `define_response_for`: Define custom response methods using blocks
  - `define_responses_for`: Define same behavior for multiple actions in batch
  - `define_crud_responses`: Intelligent CRUD responses with dynamic context
  - `generate_rest_responses`: Auto-generate namespaced REST responses (public_, admin_, etc.)
- **Dynamic Context**: Support for lambdas/procs in context generation with `instance_eval`
- **Method Introspection**: `response_definitions` class attribute for debugging generated methods
- **Enhanced Error Messages**: Detailed error responses with suggestions when actions are not supported

### Changed
- **Breaking**: Removed automatic fallback behavior for action mapping (by design - explicit is better than implicit)
- **Improved**: `render_invalid_action` now provides detailed error information with actionable suggestions
- **Enhanced**: Better error handling with specific guidance on how to implement missing methods

### Technical Details
- Added `class_attribute :response_definitions` for storing method definitions
- Enhanced `render_with` method resolution to support custom and mapped actions
- All generated methods are properly marked as private
- Full backward compatibility maintained for existing CRUD operations

### Documentation
- Added comprehensive documentation in CUSTOM_ACTIONS.md
- Added metaprogramming guide in METAPROGRAMMING.md  
- Added practical implementation example in PRACTICAL_EXAMPLE.md
- Updated README with new functionality overview

## [0.1.1] - 2024-10-20

- Initial release

## [0.1.0] - 2024-10-20

- Initial release
