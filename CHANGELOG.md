## [Unreleased]

## [1.1.0] - 2025-11-21

### Added

- **Automatic Pagination Support**: `respond_for_index` now auto-detects Kaminari/WillPaginate pagination and includes meta automatically
- **Pagination Helpers in Responder**: Added `paginated?`, `pagination_meta`, and `render_collection_with_meta` methods
- **Smart Meta Handling**: Automatically merges pagination meta with context meta if both are present

### Features

- Auto-detection of paginated collections (checks for `current_page`, `total_pages`, `total_count` methods)
- Automatic inclusion of pagination metadata: `current_page`, `total_pages`, `total_count`, `per_page`
- Backward compatible - works with manual `meta` in context or auto-detects pagination
- Works with both Kaminari and WillPaginate gems

### Example Usage

```ruby
# Controller - Automatic pagination meta
def index
  @academies = Academy.page(params[:page]).per(15)
  render_with(@academies) # Auto-includes pagination meta!
end

# Manual meta still works
def index
  @academies = Academy.page(params[:page]).per(15)
  render_with(@academies, context: { meta: { custom: 'data' } })
  # Merges pagination + custom meta
end

# Custom responder with pagination helper
class MyResponder < JsonapiResponses::Responder
  def render
    render_collection_with_meta(record, { custom: 'meta' })
  end
end
```

## [1.0.0] - 2025-10-07

### 🎉 Major Release - Breaking Changes

This is a major release with significant architectural improvements and breaking changes.

### Breaking Changes

- **Renamed `BaseSerializer`** → `ApplicationSerializer` (follows Rails convention)
- **Renamed `BaseResponder`** → `ApplicationResponder` (follows Rails convention like ApplicationPolicy)
- Responders now follow **Pundit-style pattern**: one responder class per controller with multiple action methods

### Added

- **Pundit-Style Responders**: One responder class per controller (e.g., `AcademyResponder`, `CourseResponder`)
- **Action-based method calls**: Use `render_with(@records, responder: AcademyResponder, action: :featured)`
- **ApplicationResponder base class**: With common helpers like `render_collection_with_meta`, `base_meta`, `filters_applied`
- Enhanced `render_with` to support `action:` parameter for calling specific responder methods
- Comprehensive documentation for Pundit-style responder pattern

### Migration Guide

#### 1. Rename Base Classes

```ruby
# Before (v0.3.0)
class BaseSerializer
  # ...
end

class FeaturedResponder < JsonapiResponses::Responder
  def render
    # ...
  end
end

# After (v1.0.0)
class ApplicationSerializer
  # ...
end

class AcademyResponder < ApplicationResponder
  def featured  # ← Method instead of render
    # ...
  end

  def popular
    # ...
  end
end
```

#### 2. Update Controller Usage

```ruby
# Before (v0.3.0)
render_with(@academies, responder: FeaturedResponder)

# After (v1.0.0)
render_with(@academies, responder: AcademyResponder, action: :featured)
```

#### 3. Consolidate Responders

Instead of one file per action:

```
# Before
app/responders/academy_featured_responder.rb
app/responders/academy_popular_responder.rb
app/responders/academy_recommended_responder.rb

# After
app/responders/academy_responder.rb  # All methods inside
```

### Improved

- Better alignment with Rails naming conventions (Application\* prefix)
- Reduced file proliferation (3-4 responder files instead of 20+)
- Easier to maintain and understand (Pundit-style pattern)
- Better code organization and discoverability

## [0.3.0] - 2025-10-07

### Added

- **Custom Responders System**: New architecture for handling complex custom actions
  - Added `JsonapiResponses::Responder` base class for creating dedicated responder objects
  - Responders encapsulate response logic, keeping controllers clean and promoting reusability
  - Full access to controller context, serialization helpers, and request params
- **Responder Base Class Features**:
  - `serialize_collection` and `serialize_item` helpers for data serialization
  - `render_json` helper for consistent JSON rendering
  - `collection?` and `single_item?` type checking utilities
  - Access to `params`, `current_user`, `controller`, `record`, `serializer_class`, and `context`
- **Enhanced render_with**:

  - New `responder:` parameter to use custom responder classes
  - New `serializer:` parameter to override default serializer detection
  - Example: `render_with(@records, responder: FeaturedResponder, serializer: CustomSerializer)`

- **Example Responders**:
  - `FeaturedResponder` - For featured/highlighted content with metadata
  - `PopularResponder` - For popular content with ranking information
  - `CategorizedResponder` - For grouped/categorized responses

### Changed

- Updated `lib/jsonapi_responses.rb` to require `responder.rb`
- Enhanced `Respondable` module to support responder classes
- Improved documentation with comprehensive Responder guide

### Documentation

- Added "Custom Responders" section to README with complete examples
- Added comparison table: when to use each approach (mapping vs methods vs responders)
- Added `RESPONDERS_FEATURE.md` with complete implementation guide
- Documented Responder API and best practices

### Benefits

- **Separation of Concerns**: Response logic separated from controllers
- **Reusability**: Same responder can be used across multiple controllers
- **Testability**: Test response logic independently from controllers
- **Maintainability**: Controllers stay clean and focused on business logic

## [0.2.0] - 2025-10-06

### Added

- **Custom Actions Support**: Support for custom actions beyond standard CRUD (index, show, create, update, destroy)
- **Explicit Action Mapping**: `map_response_action` and `map_response_actions` for mapping custom actions to existing responses
- **Metaprogramming Support**: Dynamic method generation for response handlers
  - `define_response_for`: Define custom response methods using blocks
  - `define_responses_for`: Define same behavior for multiple actions in batch
  - `define_crud_responses`: Intelligent CRUD responses with dynamic context
  - `generate_rest_responses`: Auto-generate namespaced REST responses (public*, admin*, etc.)
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
