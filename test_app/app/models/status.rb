# frozen_string_literal: true

class Status < ApplicationRecord
  include SupportTableData

  self.support_table_key_attribute = :code
  add_support_table_data "statuses.yml"
  named_instance_attribute_helpers :name

  validates :code, presence: true, uniqueness: true
end

# Begin YARD docs for support_table_data
# To update these docs, run `bundle exec rake support_table_data:yard_docs`
class Status
  # @!group Named Instances

  # Find the named instance +active+ from the database.
  #
  # @!method self.active
  # @return [Status]
  # @raise [ActiveRecord::RecordNotFound] if the record does not exist
  # @!visibility public

  # Check if this record is the named instance +active+.
  #
  # @!method active?
  # @return [Boolean]
  # @!visibility public

  # Get the name attribute from the data file
  # for the named instance +active+.
  #
  # @!method self.active_name
  # @return [Object]
  # @!visibility public

  # Find the named instance +canceled+ from the database.
  #
  # @!method self.canceled
  # @return [Status]
  # @raise [ActiveRecord::RecordNotFound] if the record does not exist
  # @!visibility public

  # Check if this record is the named instance +canceled+.
  #
  # @!method canceled?
  # @return [Boolean]
  # @!visibility public

  # Get the name attribute from the data file
  # for the named instance +canceled+.
  #
  # @!method self.canceled_name
  # @return [Object]
  # @!visibility public

  # Find the named instance +completed+ from the database.
  #
  # @!method self.completed
  # @return [Status]
  # @raise [ActiveRecord::RecordNotFound] if the record does not exist
  # @!visibility public

  # Check if this record is the named instance +completed+.
  #
  # @!method completed?
  # @return [Boolean]
  # @!visibility public

  # Get the name attribute from the data file
  # for the named instance +completed+.
  #
  # @!method self.completed_name
  # @return [Object]
  # @!visibility public

  # Find the named instance +failed+ from the database.
  #
  # @!method self.failed
  # @return [Status]
  # @raise [ActiveRecord::RecordNotFound] if the record does not exist
  # @!visibility public

  # Check if this record is the named instance +failed+.
  #
  # @!method failed?
  # @return [Boolean]
  # @!visibility public

  # Get the name attribute from the data file
  # for the named instance +failed+.
  #
  # @!method self.failed_name
  # @return [Object]
  # @!visibility public

  # Find the named instance +pending+ from the database.
  #
  # @!method self.pending
  # @return [Status]
  # @raise [ActiveRecord::RecordNotFound] if the record does not exist
  # @!visibility public

  # Check if this record is the named instance +pending+.
  #
  # @!method pending?
  # @return [Boolean]
  # @!visibility public

  # Get the name attribute from the data file
  # for the named instance +pending+.
  #
  # @!method self.pending_name
  # @return [Object]
  # @!visibility public

  # @!endgroup
end
# End YARD docs for support_table_data
