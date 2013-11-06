module ClassAction
  module RSpec

    class RespondToFormatMatcher

      def initialize(format)
        @format = format.to_sym
      end

      def on(condition)
        @condition = condition
        self
      end

      def matches?(action, &block)
        @action = action

        if action.class._responders.key?([@format, @condition])

          if block
            # Response defined, we return true but we need to also execute the block,
            # as it might contain additional checks. First run the action's response
            # block, for this.
            respond_block = action.class._responders[ [@format, @condition] ]
            action.instance_exec &respond_block if respond_block
            action.send :copy_assigns_to_controller
            block.call
          end

          true
        else
          false
        end
      end

      def description
        if @condition
          "respond to format :#{@format} on :#{@condition}"
        else
          "respond to format :#{@format}"
        end
      end

      def failure_message_for_should
        if @condition
          "expected action of class #{@action.class} to respond to format :#{@format} on :#{@condition}"
        else
          "expected action of class #{@action.class} to respond to format :#{@format}"
        end
      end

      def failure_message_for_should_not
        if @condition
          "expected action of class #{@action.class} not to respond to format :#{@format} on :#{@condition}"
        else
          "expected action of class #{@action.class} not to respond to format :#{@format}"
        end
      end

    end

  end
end

RSpec::Matchers.module_eval do
  def respond_to_format(format)
    ClassAction::RSpec::RespondToFormatMatcher.new(format)
  end
end