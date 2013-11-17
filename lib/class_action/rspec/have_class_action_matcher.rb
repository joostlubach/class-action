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
        @reason = :unsupported and return false unless controller.respond_to?(:_class_action, true)
        @reason = :not_an_action and return false unless controller.respond_to?(@action_name)
        @reason = :not_a_class_action and return false unless controller.respond_to?(:"_#{@action_name}_action_class", true)

        if @klass
          @found_class = controller.send(:"_#{@action_name}_action_class").class
          @reason = :incorrect_class and return false if @found_class != @klass
        end

        true
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