# frozen_string_literal: true

if Rake::Task.task_defined?("db:migrate")
  Rake::Task["db:migrate"].enhance do
    # The main database connection may have artifacts from the migration, so re-establish it
    # to get a clean connection before syncing support table data.
    ActiveRecord::Base.establish_connection

    Rake::Task["support_table_data:sync"].invoke
  end
end
