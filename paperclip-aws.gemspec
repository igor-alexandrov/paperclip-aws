# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run 'rake gemspec'
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "paperclip-aws"
  s.version = "1.6.6"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Igor Alexandrov"]
  s.date = "2012-03-12"
  s.description = "'paperclip-aws' is a full featured storage module that supports all S3 locations (US, European and Tokio) without any additional hacking."
  s.email = "igor.alexandrov@gmail.com"
  s.extra_rdoc_files = [
    "LICENSE.txt",
    "README.md"
  ]
  s.files = [
    ".document",
    "Gemfile",
    "Gemfile.lock",
    "LICENSE.txt",
    "README.md",
    "Rakefile",
    "VERSION",
    "lib/paperclip-aws.rb",
    "paperclip-aws.gemspec",
    "test/aws_storage_test.rb",
    "test/database.yml",
    "test/fixtures/5k.png",
    "test/fixtures/spaced file.png",
    "test/helper.rb"
  ]
  s.homepage = "http://github.com/igor-alexandrov/paperclip-aws"
  s.licenses = ["MIT"]
  s.require_paths = ["lib"]
  s.rubygems_version = "1.8.15"
  s.summary = "Storage module to official 'aws-sdk' gem for Amazon S3"

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<paperclip>, [">= 2.5.0"])
      s.add_runtime_dependency(%q<aws-sdk>, [">= 1.2.0"])
      s.add_development_dependency(%q<bundler>, ["~> 1.0.0"])
      s.add_development_dependency(%q<jeweler>, ["~> 1.6.4"])
    else
      s.add_dependency(%q<paperclip>, [">= 2.5.0"])
      s.add_dependency(%q<aws-sdk>, [">= 1.2.0"])
      s.add_dependency(%q<bundler>, ["~> 1.0.0"])
      s.add_dependency(%q<jeweler>, ["~> 1.6.4"])
    end
  else
    s.add_dependency(%q<paperclip>, [">= 2.5.0"])
    s.add_dependency(%q<aws-sdk>, [">= 1.2.0"])
    s.add_dependency(%q<bundler>, ["~> 1.0.0"])
    s.add_dependency(%q<jeweler>, ["~> 1.6.4"])
  end
end

