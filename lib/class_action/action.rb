module ClassAction

  # Base class for controller actions.
  class Action

    ######
    # Initialization

      def initialize(controller)
        @_controller = controller
      end

    ######
    # Attributes

      attr_internal_reader :controller

      def available?
        true
      end
      protected :controller, :available?

    ######
    # Controller method exposure

      class << self

        # Exposes the given controller methods into the action.
        def controller_method(*methods, sync_assigns: true)
          if sync_assigns
            assigns_copy_to   = "copy_assigns_to_controller"
            assigns_copy_from = "copy_assigns_from_controller"
          end

          methods.each do |method|
            class_eval <<-RUBY, __FILE__, __LINE__+1
              def #{method}(*args, &block)
                #{assigns_copy_to}
                controller.send :#{method}, *args, &block
              ensure
                #{assigns_copy_from}
              end
              protected :#{method}
            RUBY
          end
        end

        def action_methods
          methods  = public_instance_methods
          methods -= [ :_execute ]
          methods -= Object.public_instance_methods
          methods
        end

      end

      controller_method :params, :request, :format, sync_assigns: false
      controller_method :render, :redirect_to, :respond_to, :respond_with

    ######
    # Helper methods

      class << self

        attr_accessor :helpers

        def inherited(klass)
          klass.helpers = Module.new
        end

        def helper_method(*methods)
          methods.each do |method|
            helpers.class_eval <<-RUBY, __FILE__, __LINE__+1
              def #{method}(*args, &block)
                controller.class_action.send(:#{method}, *args, &block)
              end
            RUBY
          end
        end

      end

    ######
    # Execution

      def _execute
        raise ActionNotAvailable unless available?

        # Execute the action by running all public methods in order.
        self.class.action_methods.each do |method|
          send method

          # Break execution of the action when some response body is set.
          # E.g. when the action decides to redirect halfway.
          break if controller.response_body
        end

        # Perform a default response if not done so yet.
        _respond unless controller.response_body
      end

      private

      def _respond
        copy_assigns_to_controller

        if self.class.respond_with_method
          response_object = send(self.class.respond_with_method)
          controller.respond_with response_object, &_respond_block
        elsif _respond_block
          controller.respond_to &_respond_block
        end
      end

      def _respond_block
        responders = self.class.responders
        return if responders.none? { |format, block| !!block }

        action = self
        proc do |collector|
          responders.each do |format, block|
            next unless block
            collector.send(format) do
              action.instance_exec &block
            end
          end
        end
      end


    ######
    # Responding

      class << self

        attr_accessor :respond_with_method
        def responders
          @reponders ||= {}
        end

        def respond_with(method)
          self.respond_with_method = method
        end

        def respond_to(*formats, &block)
          formats.each do |format|
            responders[format.to_sym] = block
          end
        end

        def respond_to_any(&block)
          respond_to :any, &block
        end

      end

    ######
    # Assigns

      private

      def copy_assigns_from_controller
        controller.view_assigns.each do |key, value|
          instance_variable_set "@#{key}", value
        end
      end

      def copy_assigns_to_controller
        ivars  = instance_variables
        ivars -= [ :@_controller, :@_responders, :@_default_responder ]
        ivars.each do |ivar|
          controller.instance_variable_set ivar, instance_variable_get(ivar)
        end
      end

  end

end