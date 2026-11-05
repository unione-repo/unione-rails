# frozen_string_literal: true

require 'test_helper'
require 'fileutils'
require 'tmpdir'
require 'rails/generators'

# rails generate unione:install in an empty app: the delivery method in production.rb (once), the initializer.
class InstallGeneratorTest < Minitest::Test
  LINE = 'config.action_mailer.delivery_method = :unione'

  def in_app(production)
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, 'config/environments'))
      File.write(File.join(dir, 'config/application.rb'),
                 "module App\n  class Application < Rails::Application\n  end\nend\n")
      File.write(File.join(dir, 'config/environments/production.rb'), production)
      yield dir
    end
  end

  def generate(dir)
    Rails::Generators.invoke('unione:install', ['--quiet'], behavior: :invoke, destination_root: dir)
  end

  def test_delivery_method_and_initializer
    in_app("Rails.application.configure do\n  config.eager_load = true\nend\n") do |dir|
      2.times { generate(dir) }

      production = File.read(File.join(dir, 'config/environments/production.rb'))
      initializer = File.join(dir, 'config/initializers/unione.rb')
      assert_equal 1, production.scan(LINE).size
      refute_includes File.read(File.join(dir, 'config/application.rb')), LINE
      assert File.exist?(initializer)
      RubyVM::InstructionSequence.compile(production)
      RubyVM::InstructionSequence.compile(File.read(initializer))
    end
  end

  def test_another_delivery_method_is_kept
    in_app("Rails.application.configure do\n  config.action_mailer.delivery_method = :smtp\nend\n") do |dir|
      generate(dir)

      production = File.read(File.join(dir, 'config/environments/production.rb'))
      refute_includes production, LINE
      assert_includes production, ':smtp'
      assert File.exist?(File.join(dir, 'config/initializers/unione.rb'))
    end
  end
end
