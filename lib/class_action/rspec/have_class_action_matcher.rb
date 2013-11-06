module ClassAction
  module RSpec

    class HaveClassActionMatcher

      def initialize(action_name)
        @action_name = action_name.to_s
      end

      def using_class(klass)
        @klass = klass
        self
      end

      def matches?(controller)
        @controller = controller
        @reason = :unsupported and return false unless controller.respond_to?(:_execute_class_action, true)
        @result = :not_an_action and return false unless controller.respond_to?(@action_name)

        # Temporarily replace the controller's implementation of _execute_class_action
        # for the purpose of testing this. Restore it afterwards.
        prev_method = controller.method(:_execute_class_action)

        received_klass = nil
        controller.class.send :define_method, :_execute_class_action do |klass|
          received_klass = klass
        end

        # Test invoking the action now.
        controller.send @action_name

        if received_klass.nil?
          @reason = :not_a_class_action
          false
        elsif @klass && received_klass != @klass
          @found_class = received_klass
          @reason = :incorrect_class
          false
        else
          true
        end
      ensure
        # Restore the original method here.
        controller.class.send :define_method, :_execute_class_action, prev_method if prev_method
      end

      def description
        if @klass
          "have class action :#{@action_name} using class #{@klass}"
        else
          "have class action :#{@action_name}"
        end
      end

      def failure_message_for_should
        case @reason
        when :unsupported
          "expected controller of class #{@controller.class} to have class action :#{@action_name}, but it does not support class actions"
        when :incorrect_class
          "expected action #{@controller.class}##{@action_name} to use class #{@klass}, but it used #{@found_class}"
        when :not_a_class_action
          "expected action #{@controller.class}##{@action_name} to be a class action"
        else
          "expected controller of class #{@controller.class} to have class action :#{@action_name}"
        end
      end

      def failure_message_for_should_not
        if @klass
          "expected #{@controller.class}##{@action_name} not to be a class action using class #{@klass}"
        else
          "expected #{@controller.class}##{@action_name} not to be a class action"
        end
      end

    end

  end
end

RSpec::Matchers.module_eval do
  def have_class_action(action_name)
    ClassAction::RSpec::HaveClassActionMatcher.new(action_name)
  end
end