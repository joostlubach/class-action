# ClassAction

This gem allows you to write controller actions as classes rather than methods. This is particularly useful for those actions that are too complex, and may require a lot of support methods.

Within your action class, you may access controller methods, and you can access assignment instance variables.

Additional benefits include:

* Action-specific helper methods
* Support for responders (future support)

[<img src="https://secure.travis-ci.org/yoazt/class-action.png?branch=master" alt="Build Status" />](http://travis-ci.org/yoazt/class-action)

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

All *public* methods are executed in order when the action is run. Any support methods you need, you will need to make protected. Also, all controller methods are available in the action.

    class PostController
      class Show < ClassAction::Action

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

      respond_with :@post
      respond_to :html, :json

      respond_to :text do
        render :text => @post.to_yaml
      end

    end

is roughly equivalent to:

    class PostsController < ActionController::Base

      respond_to :html, :json, :text, :only => [ :show ]

      def show
        respond_with @post do |format|
          format.text do
            render :text => @post.to_yaml
          end
        end
      end

    end

Note that the value you pass to `respond_with` may be a simple symbol (e.g. `:post`) for a method or a reference to an instance variable (e.g. `:@post`).

In other words, using `respond_with` in conjunction with `respond_to` allows you to:

1. Specify which method to use to obtain the response object (the first argument to `ActionController#respond_with`). Note that this method must exist on the action or controller.
2. Specify the formats that this action responds to. `ClassAction` will make sure that the controller mime types are modified accordingly.
3. Create a custom responder block in one breath.

The only caveat is that you have to specify all your controller-level `respond_to` declarations *before* defining your actions using `class_action`, or you might override the `respond_to` array of your controller.

### State based responses

In some cases you may want a certain response method (`respond_with`) or responder block (`respond_to`) to be only available in a certain case. For example, in some update action, you may want a different response based on whether the object was saved successfully.

Limiting a response method or reponder block this way is possible through the `on:` option in the methods `respond_with` and `respond_to`. The value of this option should correspond to a question-mark method on your action (or controller).

For example:

    class Update < ClassAction::Action

      respond_with :@post
      respond_to :html, on: :failure do
        render :edit, :status => :unprocessable_entity
      end

      protected

        def success?
          @post.errors.blank?
        end
        def failure?
          @post.errors.present?
        end

    end

This will effectively perform the following response logic on the controller:

    if @post.errors.blank?
      respond_with @post
    elsif @post.errors.present?
      respond_with @post do |format|
        format.html { render :edit, :status => :unprocessable_entity }
      end
    end

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
