module ClassAction

  # Base class for controller actions.
  class Action

    ######
    # Initialization

      def initialize(controller)
        @controller = controller
      end

    ######
    # Attributes

      attr_reader :controller

      def available?
        true
      end

    ######
    # Methods

      def execute
      end

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
                controller.__send__ :#{method}, *args, &block
              ensure
                #{assigns_copy_from}
              end
            RUBY
          end
        end

      end

      controller_method :params, :request, sync_assigns: false
      controller_method :render, :respond_to, :respond_with, :redirect_to

      private

      def copy_assigns_from_controller
        controller.view_assigns.each do |key, value|
          instance_variable_set "@#{key}", value
        end
      end

      def copy_assigns_to_controller
        ivars  = instance_variables
        ivars -= [ :@controller ]
        ivars.each do |ivar|
          controller.instance_variable_set ivar, instance_variable_get(ivar)
        end
      end

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
                controller.action.send(:#{method}, *args, &block)
              end
            RUBY
          end
        end

      end

  end

end