module ClassAction
  module RSpec

    class RespondWithMatcher

      def initialize(expected)
        @expected = expected.to_sym
      end

      def on(condition)
        @condition = condition
        self
      end

      def matches?(action)
        @action = action
        @actual = action.class._responses[@condition].try(:to_sym)
        @actual == @expected
      end

      def description
        if @condition
          "respond with method :#{@expected} on :#{@condition}"
        else
          "respond with method :#{@expected}"
        end
      end

      def failure_message
        suffix = if @actual
          ", but it responds with :#{@actual}"
        else
          ", but it has no response method"
        end

        if @condition
          "expected action of class #{@action.class} to respond with :#{@expected} on :#{@condition}#{suffix}"
        else
          "expected action of class #{@action.class} to respond with :#{@expected}#{suffix}"
        end
      end

      def failure_message_when_negated
        if @condition
          "expected action of class #{@action.class} not to respond with :#{@expected} on :#{@condition}"
        else
          "expected action of class #{@action.class} not to respond with :#{@expected}"
        end
      end

    end

  end
end

RSpec::Matchers.module_eval do
  def respond_with(expected)
    ClassAction::RSpec::RespondWithMatcher.new(expected)
  end
end