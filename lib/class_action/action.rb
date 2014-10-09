require 'active_support/core_ext/object/try'
require 'active_support/core_ext/hash/reverse_merge'

module ClassAction

  # Base class for controller actions.
  class Action

    ######
    # Initialization

      def initialize(controller)
        @_controller = controller
        @_controller.singleton_class.send :include, self.class.helpers
      end

    ######
    # Attributes

      def controller
        @_controller
      end
      protected :controller

      def available?
        true
      end

    ######
    # Controller method exposure

      class << self

        # Exposes the given controller methods into the action.
        def _controller_method(method)
          class_eval <<-RUBY, __FILE__, __LINE__+1
            def #{method}(*args, &block)
              copy_assigns_to_controller
              controller.send :#{method}, *args, &block
            ensure
              copy_assigns_from_controller
            end
            protected :#{method}
          RUBY
        end

      end

      def respond_to?(method, include_private = false)
        super || (include_private && controller.respond_to?(method, true))
      end

      def method_missing(method, *args, &block)
        if controller.respond_to?(method, true)
          self.class._controller_method method
          send method, *args, &block
        else
          super
        end
      end
      private :method_missing

    ######
    # Execution

      class << self

        def _action_methods
          methods  = public_instance_methods
          methods -= [ :_execute, :available? ]
          methods -= Object.public_instance_methods
          methods
        end

      end

      def _execute
        raise ActionNotAvailable unless available?

        # Execute the action by running all public methods in order.
        self.class._action_methods.each do |method|
          next if self.method(method).arity != 0

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

        response = self.class._responses.find do |on, response|
          !on || send(:"#{on}?")
        end.try(:last)

        if response
          response_object = if response =~ /^@/
            instance_variable_get(response)
          else
            send(response)
          end

          controller.respond_with response_object, &_respond_block
        elsif _respond_block
          controller.respond_to &_respond_block
        end
      end

      def _respond_block
        responders = {}
        self.class._responders.each do |(format, on), block|
          # Select only those responders that have a block, and for which no precondition is set, or
          # one that matches the current action state.
          responders[format] ||= block if block && (!on || send(:"#{on}?"))
        end
        return if responders.empty?

        action = self
        proc do |collector|
          responders.each do |format, block|
            collector.send(format) do
              action.instance_exec &block
              copy_assigns_to_controller
            end
          end
        end
      end

    class << self

      ######
      # Helpers

        attr_accessor :helpers
        def helpers
          @helpers ||= Module.new.tap do |helpers|
            helpers.send :include, superclass.helpers if superclass.respond_to?(:helpers)
          end
        end

        def helper_method(*methods)
          methods.each do |method|
            helpers.class_eval <<-RUBY, __FILE__, __LINE__+1
              def #{method}(*args, &block)
                controller = if respond_to?(:class_action)
                  self
                else
                  self.controller
                end
                controller.class_action.send(:#{method}, *args, &block)
              end
            RUBY
          end
        end

      ######
      # Responders

        attr_reader :_responders, :_responses

        def _responses
          @_responses ||= {}.tap do |responses|
            responses.reverse_update superclass._responses if superclass.respond_to?(:_responses)
          end

          # Keep the hash in such an order that the 'nil' condition is always *last*.
          # { :ok => 1, nil => 2, :invalid => 3 } => { :ok => 1, :invalid => 3, nil => 2 }
          @_responses = Hash[ *@_responses.sort_by { |on, _method| on.nil? ? 1 : 0 }.flatten ]
        end

        def _responders
          @_responders ||= {}.tap do |responders|
            responders.reverse_update superclass._responders if superclass.respond_to?(:_responders)
          end

          # Keep the hash in such an order that the 'nil' conditions are always *last*.
          # { [ (:html, nil) => 1, (:json, nil) => 2, (:html, :ok) => 3 } => { (:html, :ok) => 3, (:html, nil) => 1, (:json, nil) => 2 }
          @_responders = Hash[ *@_responders.sort_by { |(format, on), _method| on.nil? ? 1 : 0 }.inject([]) { |arr, (key, value)| arr << key << value } ]
        end

        # Defines a method that returns the response. Specify an optional precondition in the `on` parameter.
        def respond_with(method, on: nil)
          _responses[on.try(:to_sym)] = method
        end

        # Defines a response block for the given format(s). Specify an optional precondition in the `on` parameter.
        def respond_to(*formats, on: nil, &block)
          formats.each do |format|
            _responders[ [format.to_sym, on.try(:to_sym)] ] = block
          end
        end

        # Defines a response block for any remaining format. Specify an optional precondition in the `on` parameter.
        def respond_to_any(on: nil, &block)
          respond_to :any, on: on, &block
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