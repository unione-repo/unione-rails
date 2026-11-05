# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

# The SDK from a local checkout instead of rubygems.org (the checks of the generator): WRAPPER_SDK_PATH=../sdk
sdk_path = ENV.fetch('WRAPPER_SDK_PATH', '')
gem 'unione', path: sdk_path unless sdk_path.empty?
