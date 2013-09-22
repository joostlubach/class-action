# ClassAction

This gem allows you to write controller actions as classes rather than methods. This is particularly useful for those actions that are too complex, and may require a lot of support methods.

Within your action class, you may access controller methods, and you can access assignment instance variables.

Additional benefits include:

* Action-specific helper methods
* Support for responders (future support)

## Installation

Add this line to your application's Gemfile:

    gem 'class-action'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install class-action

## Usage

### Setting up your controller

In your controller, make sure you have included `ClassAction`, and declare which class actions you wish to use.

    class PostsController
      include ClassAction

      class_action :show
    end

### Create an action

Then, create your `show` action class (the default is to name this class `PostsController::Show`, but you may customize this).

All *public* methods are executed in order when the action is run. Any support methods you need, you will need to make protected. You may also declare that you need some controller methods.

Some default controller methods (`params`, `request`, `render`, `redirect_to`, `respond_to` and `respond_with`) are available at all times.

    class PostController
      class Show < ClassAction::Action

        # We need this method from the controller.
        controller_method :current_user

        def prepare
          load_post
        end

        def update_timestamp
          @post.last_read_at = DateTime.now
          @post.last_read_by = current_user
        end

        def render
          respond_to do |format|
            format.html { render @post }
            format.json { render json: @post }
          end
        end

        protected

          # Note - this method is not executed by ClassAction. It is meant as
          # support action.
          def load_post
            @post = Post.find(params[:id])
          end

          # Declare a helper method - this helper method is only available for
          # this action.
          def current_section
            params[:section] || @post.sections.first
          end
          helper_method :current_section

      end
    end

Note that any of your execution methods may call `render` or `redirect`. The execution of the action will stop after any method if it uses these methods (or more formally, when the response body in the controller is set). This removes the need for complex control-flow in your action.

    class Show < ClassAction::Action

      def check_security
        redirect_to root_path unless authorized?
      end

      def only_performed_if_authorized
        render :show
      end

      protected

      def authorized?
        # Custom logic for this action, perhaps?
      end

    end

### Responses

You can run an action fine like above, where you use `respond_to` or `respond_with` (or even just `render`/`redirect_to`) from within any execution method.

However, `ClassAction` provides a bit more support for responses. You may define any responders directly in the action:

    class Show < ClassAction::Action

      respond_to :html do
        render :show
      end
      respond_to :json do
        render :json => @post
      end

    end

This employs the use of `ActionController#respond_to`. Additionally, there is support for the Rails 3 style `respond_with`. To illustrate, this:

    class Show < ClassAction::Action

      controller_method :post

      respond_with :post
      respond_to :html, :json

      respond_to :text do
        render :text => @post.to_yaml
      end

    end

is roughly equivalent to:

    class PostsController < ActionController::Base

      respond_to :html, :json, :text, :only => [ :show ]

      def show
        respond_with post do |format|
          format.text do
            render :text => @post.to_yaml
          end
        end
      end

    end

In other words, using `respond_with` in conjunction with `respond_to` allows you to:

1. Specify which method to use to obtain the response object (the first argument to `ActionController#respond_with`). Note that this method must exist on the action, or must be exposed using `controller_method`.
2. Specify the formats that this action responds to. `ClassAction` will make sure that the controller mime types are modified accordingly.
3. Create a custom responder block in one breath.

The only caveat is that you have to specify all your controller-level `respond_to` declarations *before* defining your actions using `class_action`, or you might override the `respond_to` array of your controller.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
