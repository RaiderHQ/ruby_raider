# frozen_string_literal: true

require 'rspec/expectations'

# Ruby only reads the magic comment in the comment block before the first line of code. Ruby would
# accept it indented, but the generated project's RuboCop (Layout/CommentIndentation) would not.
RSpec::Matchers.define :have_frozen_string_literal do
  match do |content|
    leading_comments = content.lines.take_while { |line| line.strip.empty? || line.start_with?('#') }
    leading_comments.any? { |line| line.chomp == '# frozen_string_literal: true' }
  end
  failure_message { 'expected an unindented frozen_string_literal magic comment before the first line of code' }
end
