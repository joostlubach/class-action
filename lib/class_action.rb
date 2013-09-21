require 'active_support/inflector'

module ClassAction

  class ActionNotAvailable < RuntimeError
  end

  class << self
    def included(target)
      target.extend ClassMethods
      setup target
    end

    def setup(target)
      target.class_eval <<-RUBY, __FILE__, __LINE__+1
        def class_action
          @_class_action
        end
      RUBY
    end
  end

  module ClassMethods

    def class_action(name, class_name: nil)
      class_name ||= "#{self.name}::#{name.to_s.camelize}"

      class_eval <<-RUBY, __FILE__, __LINE__+1
        def #{name}
          _execute_class_action :#{name}, #{class_name}
        end
      RUBY
    end

  end

  def view_context
    view_context = super

    if class_action
      # Extend the current view context with the action helpers.
      view_context.singleton_class.send :include, class_action.class.helpers
    end

    view_context
  end

  private

  def _execute_class_action(name, klass)
    @_class_action = klass.new(self)
    @_class_action._execute
  end

end

if defined?(AbstractController::Rendering::DEFAULT_PROTECTED_INSTANCE_VARIABLES)
  AbstractController::Rendering::DEFAULT_PROTECTED_INSTANCE_VARIABLES << '@_class_action'
end

require 'class_action/version'
require 'class_action/action'