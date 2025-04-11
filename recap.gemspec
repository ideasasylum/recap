# frozen_string_literal: true

require_relative "lib/recap/version"

Gem::Specification.new do |spec|
  spec.name = "recap"
  spec.version = Recap::VERSION
  spec.authors = ["Jamie Lawrence"]
  spec.email = ["jamie@ideasasylum.com"]

  spec.summary = "A tool to summarize GitHub PRs merged in the last week"
  spec.description = "Recap provides a simple way to get a summary of all Pull Requests merged into a GitHub repository within the last week"
  spec.homepage = "https://github.com/jamie/recap"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/jamie/recap"
  spec.metadata["changelog_uri"] = "https://github.com/jamie/recap/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "bin"
  spec.executables = ["recap"]
  spec.require_paths = ["lib"]

  spec.add_dependency "octokit", "~> 7.0"
  spec.add_dependency "ruby-anthropic", "~> 0.4.2"
  spec.add_dependency "base64"
  spec.add_dependency "faraday-retry"
  spec.add_dependency "rrtf", "~> 1.3"
  spec.add_dependency "slack-ruby-client", "~> 2.3"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "standard", "~> 1.3"
end
