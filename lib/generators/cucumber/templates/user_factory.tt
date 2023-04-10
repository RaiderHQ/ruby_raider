require_relative 'model_factory'

class UserFactory < ModelFactory
  def self.for(user)
    super('users')[user]
  end
end

ParameterType(
  name: 'user',
  regexp: /[A-Za-z0-9]+ user/,
  transformer: ->(user) { UserFactory.for(user) }
)
