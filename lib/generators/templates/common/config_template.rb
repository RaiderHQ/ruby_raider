require_relative '../template'

class ConfigTemplate < Template
  def body
    <<~EOF
      browser: :chrome
    EOF
  end
end
