# frozen_string_literal: true

module SupportTableData
  module Documentation
    autoload :TypeInference, File.expand_path("documentation/type_inference", __dir__)
    autoload :SourceFile, File.expand_path("documentation/source_file", __dir__)
    autoload :YardDoc, File.expand_path("documentation/yard_doc", __dir__)
    autoload :RbsDoc, File.expand_path("documentation/rbs_doc", __dir__)
    autoload :RbsFile, File.expand_path("documentation/rbs_file", __dir__)
  end
end
