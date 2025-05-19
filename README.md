# JsonapiResponses

JsonapiResponses is a Ruby gem that simplifies API response handling by allowing multiple response formats from a single endpoint. Instead of creating separate endpoints for different data requirements, this gem enables frontend applications to request varying levels of detail using the same endpoint.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'jsonapi_responses'
```

And then execute:

```bash
$ bundle install
```

Or install it yourself as:

```bash
$ gem install jsonapi_responses
```

## Usage

### Setup

1. Include the respondable module in your `ApplicationController`:

```ruby
class ApplicationController < ActionController::API
  include JsonapiResponses::Respondable
end
```

### Creating Serializers

1. Create a base serializer:

```ruby
class BaseSerializer
  attr_reader :resource, :context

  def initialize(resource, context = {})
    @resource = resource
    @context = context
  end

  def current_user
    @context[:current_user]
  end
end
```

2. Create your model serializers with different view formats:

```ruby
class DigitalProductSerializer < BaseSerializer
  def serializable_hash
    case context[:view]
    when :summary
      summary_hash
    when :minimal
      minimal_hash
    else
      full_hash
    end
  end

  private

  def full_hash
    {
      id: resource.id,
      name: resource.name,
      description: resource.description,
      # ... more attributes
    }
  end

  def summary_hash
    {
      id: resource.id,
      name: resource.name,
      price: resource.price,
      # ... fewer attributes
    }
  end

  def minimal_hash
    {
      id: resource.id,
      name: resource.name,
      # ... minimal attributes
    }
  end
end
```

### Controller Implementation

Use `render_with` in your controllers to handle responses. The view parameter is automatically handled from the request params:

```ruby
class Api::V1::ProductsController < ApplicationController
  def index
    products = Product.includes(:categories, :attachments)
    render_with(products)
  end

  def create
    @product = Product.new(product_params)
    render_with(@product)
  end

  def show
    render_with(@product)
  end

  def update
    @product.update(product_params)
    render_with(@product)
  end

  def destroy
    render_with(@product)
  end

  # Optional: Override the view if needed
  def custom_action
    render_with(@product, context: { view: :custom_view })
  end
end
```

### Making Requests

You can request different view formats by adding the `view` parameter:

```
GET /api/v1/digital_products            # Returns full response
GET /api/v1/digital_products?view=summary  # Returns summary response
GET /api/v1/digital_products?view=minimal  # Returns minimal response
```

### Performance Benefits

By allowing the frontend to request only the needed data, you can:
- Reduce response payload size
- Improve API performance
- Avoid creating multiple endpoints for different data requirements
- Optimize database queries based on the requested view

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/jsonapi_responses. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/jsonapi_responses/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the JsonapiResponses project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/jsonapi_responses/blob/main/CODE_OF_CONDUCT.md).
