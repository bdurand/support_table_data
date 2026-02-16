# frozen_string_literal: true

namespace :support_table_data do
  desc "Syncronize data for all models that include SupportTableData."
  task sync: :environment do
    require_relative "utils"

    SupportTableData::Tasks::Utils.eager_load!

    logger_callback = lambda do |name, started, finished, unique_id, payload|
      klass = payload[:class]
      elapsed_time = finished - started
      message = "Synchronized support table model #{klass.name} in #{(elapsed_time * 1000).round}ms"
      if klass.logger
        klass.logger.info(message)
      else
        puts message
      end
    end

    ActiveSupport::Notifications.subscribed(logger_callback, "support_table_data.sync") do
      SupportTableData.sync_all!
    end
  end

  task yard_docs: "yard_docs:add"

  namespace :yard_docs do
    desc "Adds YARD documentation comments to models to document the named instance methods. Optional arg: file_path"
    task :add, [:file_path] => :environment do |_task, args|
      require_relative "../support_table_data/documentation"
      require_relative "utils"

      SupportTableData::Tasks::Utils.eager_load!
      SupportTableData::Tasks::Utils.support_table_sources(args[:file_path]).each do |source_file|
        next if source_file.yard_docs_up_to_date?

        source_file.path.write(source_file.source_with_yard_docs)
        puts "Added YARD documentation to #{source_file.klass.name}."
      end
    end

    desc "Removes YARD documentation comments added by support_table_data from models. Optional arg: file_path"
    task :remove, [:file_path] => :environment do |_task, args|
      require_relative "../support_table_data/documentation"
      require_relative "utils"

      SupportTableData::Tasks::Utils.eager_load!
      SupportTableData::Tasks::Utils.support_table_sources(args[:file_path]).each do |source_file|
        next unless source_file.has_yard_docs?

        source_file.path.write(source_file.source_without_yard_docs)
        puts "Removed YARD documentation from #{source_file.klass.name}."
      end
    end

    desc "Verify that support table models have up to date YARD docs for named instance methods. Optional arg: file_path"
    task :verify, [:file_path] => :environment do |_task, args|
      require_relative "../support_table_data/documentation"
      require_relative "utils"

      SupportTableData::Tasks::Utils.eager_load!

      all_up_to_date = true
      SupportTableData::Tasks::Utils.support_table_sources(args[:file_path]).each do |source_file|
        unless source_file.yard_docs_up_to_date?
          puts "YARD documentation is not up to date for #{source_file.klass.name}."
          all_up_to_date = false
        end
      end

      if all_up_to_date
        if args[:file_path]
          puts "YARD documentation is up to date for #{args[:file_path]}."
        else
          puts "All support table models have up to date YARD documentation."
        end
      else
        raise "Run bundle exec rake support_table_data:yard_docs to update the documentation."
      end
    end
  end
end
