# typed: true
# frozen_string_literal: true

require "constant_resolver"

module Packwerk
  # Holds the context of a Packwerk run across multiple files.
  class RunContext
    extend T::Sig

    attr_reader(
      :configuration,
      :inflector,
      :checker_classes,
    )

    DEFAULT_CHECKERS = [
      ::Packwerk::ReferenceChecking::Checkers::DependencyChecker,
      ::Packwerk::ReferenceChecking::Checkers::PrivacyChecker,
    ]

    class << self
      def from_configuration(configuration)
        inflector = ::Packwerk::Inflector.from_file(configuration.inflections_file)
        new(configuration: configuration, inflector: inflector)
      end
    end

    def initialize(
      configuration:,
      inflector: nil,
      checker_classes: DEFAULT_CHECKERS
    )
      @configuration = configuration
      @inflector = inflector
      @checker_classes = checker_classes
    end

    def root_path
      configuration.root_path
    end

    def load_paths
      configuration.load_paths
    end

    def package_paths
      configuration.package_paths
    end

    def custom_associations
      configuration.custom_associations
    end

    sig { params(file: String).returns(T::Array[Packwerk::Offense]) }
    def process_file(file:)
      references = file_processor.call(file)

      reference_checker = ReferenceChecking::ReferenceChecker.new(checkers)
      references.flat_map { |reference| reference_checker.call(reference) }
    end

    private

    sig { returns(FileProcessor) }
    def file_processor
      @file_processor ||= FileProcessor.new(node_processor_factory: node_processor_factory)
    end

    sig { returns(NodeProcessorFactory) }
    def node_processor_factory
      NodeProcessorFactory.new(
        context_provider: context_provider,
        root_path: root_path,
        constant_name_inspectors: constant_name_inspectors
      )
    end

    sig { returns(ConstantDiscovery) }
    def context_provider
      ::Packwerk::ConstantDiscovery.new(
        constant_resolver: resolver,
        packages: package_set
      )
    end

    sig { returns(ConstantResolver) }
    def resolver
      ConstantResolver.new(
        root_path: root_path,
        load_paths: load_paths,
        inflector: inflector,
      )
    end

    sig { returns(PackageSet) }
    def package_set
      ::Packwerk::PackageSet.load_all_from(configuration, package_pathspec: package_paths)
    end

    sig { returns(T::Array[ReferenceChecking::Checkers::Checker]) }
    def checkers
      checker_classes.map(&:new)
    end

    sig { returns(T::Array[ConstantNameInspector]) }
    def constant_name_inspectors
      [
        ::Packwerk::ConstNodeInspector.new,
        ::Packwerk::AssociationInspector.new(inflector: inflector, custom_associations: custom_associations),
      ]
    end
  end
end
