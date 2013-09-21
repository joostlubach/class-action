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

In your controller, make sure you have included `ClassAction`, and declare which class actions you wish to use.

    class PostsController
      include ClassAction

      class_action :show
    end

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


## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
