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

    def class_action(*actions, klass: nil)
      actions.each do |action|
        action_class = klass || const_get(action.to_s.camelize)
        raise ArgumentError, "ClassAction does not support anonymous classes" if action_class.name.nil?

        class_eval <<-RUBY, __FILE__, __LINE__+1
          def _#{action}_action_class
            @_class_action ||= #{action_class.name}.new self
          end
          private :_#{action}_action_class

          def #{action}
            _#{action}_action_class._execute
          end
        RUBY

        inject_class_action_mimes action.to_s, action_class
      end
    end

    private

    # Injects the mimes (formats) that the action responds to into the controller
    # mimes_for_respond_to hash.
    def inject_class_action_mimes(action, klass)
      # If no responders or a default responder is given, we don't do anything.
      return if klass._responders.empty? || klass._responders.any? { |(mime, _condition), _block| mime == :any }

      mimes = mimes_for_respond_to.dup

      # Make sure no extra mimes are allowed for the action.
      mimes.each do |mime, restrictions|
        next if klass._responders.any? { |(m, _codition), _block| m == mime }
        exclude_class_action_in_mime_type mime, restrictions, action
      end

      # Include all action mimes.
      klass._responders.each do |(mime, _condition), _block|
        mimes[mime] ||= { :only => [] }
        include_class_action_in_mime_type mime, mimes[mime], action
      end

      self.mimes_for_respond_to = mimes
    end

    def include_class_action_in_mime_type(mime, restrictions, action)
      if restrictions && restrictions[:except] && restrictions[:except].include?(action)
        logger.warn "Warning: action #{action} (ClassAction) responds to `#{mime}` but it does not accept this mime type" if logger
      elsif restrictions && restrictions[:only] && !restrictions[:only].include?(action)
        restrictions[:only] << action
      end
    end

    def exclude_class_action_in_mime_type(mime, restrictions, action)
      restrictions[:except] ||= []
      restrictions[:except] << action if !restrictions[:except].include?(action)
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

  def _class_action
    send(:"_#{action_name}_action_class")
  end

end

if defined?(AbstractController::Rendering::DEFAULT_PROTECTED_INSTANCE_VARIABLES)
  AbstractController::Rendering::DEFAULT_PROTECTED_INSTANCE_VARIABLES << '@_class_action'
end

require 'class_action/version'
require 'class_action/action'