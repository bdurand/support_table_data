# frozen_string_literal: true

require "pathname"

module SupportTableData
  module Documentation
    # Manages reading/writing the per-model RBS signature file.
    class RbsFile
      attr_reader :klass, :source_path, :path

      # @param klass [Class] The model class
      # @param source_path [Pathname] The path to the model's source `.rb` file
      def initialize(klass, source_path)
        @klass = klass
        @source_path = Pathname.new(source_path)
        @path = self.class.signatures_path_for(@source_path)
      end

      # Compute where the RBS signatures should live for a given source file.
      # Defaults to `<project_root>/sig/<source_path_minus_extension>.rbs`.
      # The project root is found by walking upward looking for a `Gemfile` or
      # `.git` directory; if neither is found, the immediate parent of the
      # source file is used.
      #
      # @param source_path [Pathname]
      # @return [Pathname]
      def self.signatures_path_for(source_path)
        if SupportTableData.rbs_signatures_path
          base = Pathname.new(SupportTableData.rbs_signatures_path)
          relative = relative_to_project_root(source_path)
          return base.join("#{relative.to_s.sub(/\.rb\z/, "")}.rbs")
        end

        root = project_root_for(source_path)
        relative = source_path.expand_path.relative_path_from(root)
        root.join("sig", "#{relative.to_s.sub(/\.rb\z/, "")}.rbs")
      end

      # Project root is the nearest ancestor directory containing a Gemfile or
      # a .git directory. Falls back to the source file's directory.
      def self.project_root_for(source_path)
        current = Pathname.new(source_path).expand_path.parent
        loop do
          return current if current.join("Gemfile").file?
          return current if current.join(".git").exist?

          parent = current.parent
          return Pathname.new(source_path).expand_path.parent if parent == current

          current = parent
        end
      end

      def self.relative_to_project_root(source_path)
        Pathname.new(source_path).expand_path.relative_path_from(project_root_for(source_path))
      end

      # Render the desired RBS content for this model, or nil if the model has
      # no named instances (in which case no file should be written).
      #
      # @return [String, nil]
      def signatures_content
        RbsDoc.new(klass).signatures
      end

      # Whether the existing on-disk file matches what would be generated.
      #
      # @return [Boolean]
      def up_to_date?
        desired = signatures_content
        if desired.nil?
          !path.file?
        else
          path.file? && path.read == desired
        end
      end

      # Write the generated RBS content to disk, creating parent directories as
      # needed. Returns true if the file was written, false if there was nothing
      # to write.
      #
      # @return [Boolean]
      def write!
        content = signatures_content
        return false if content.nil?

        path.parent.mkpath
        path.write(content)
        true
      end

      # Delete the generated RBS file if it exists. Returns true if a file was
      # removed.
      #
      # @return [Boolean]
      def remove!
        return false unless path.file?

        path.delete
        true
      end
    end
  end
end
